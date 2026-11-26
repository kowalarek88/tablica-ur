-- Migracja 003: tabela linii (numer, sektor, osoby kontaktowe)
-- Gdzie uruchomić: Supabase -> SQL Editor -> New query -> wklej CAŁY plik -> Run.
-- Uruchom PO migracji 002. Można uruchomić ponownie – nic się nie zdubluje.
--
-- Linii się nie kasuje: nieaktywna linia znika z listy wyboru, ale jej historia zostaje.
-- Dodawać i zmieniać linie mogą tylko liderzy (zakładka "Linie" w aplikacji).

create table if not exists public.lines (
  code           text primary key check (length(btrim(code)) between 1 and 30), -- numer linii, np. A30
  sector         text not null default '',   -- sektor
  sector_manager text not null default '',   -- kierownik sektora
  technologist   text not null default '',   -- technolog odpowiedzialny za linię
  automation     text not null default '',   -- automatyk odpowiedzialny za linię
  nj_contact     text not null default '',   -- osoba odpowiedzialna z działu NJ
  notes          text not null default '',   -- uwagi, np. numery telefonów
  active         boolean not null default true,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create or replace function public.tg_lines_bu() returns trigger
language plpgsql as $$
begin
  new.created_at := old.created_at;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists lines_bu on public.lines;
create trigger lines_bu before update on public.lines
  for each row execute function public.tg_lines_bu();

-- Linie testowe + wszystkie linie, które już występują w zgłoszeniach
insert into public.lines (code) values ('A30'),('F08'),('K40'),('F15a'),('C32'),('N02'),('N16')
on conflict do nothing;
insert into public.lines (code) select distinct line from public.issues where line is not null
on conflict do nothing;

-- Zgłoszenie może dotyczyć tylko linii z tej tabeli
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'issues_line_fkey') then
    alter table public.issues add constraint issues_line_fkey
      foreign key (line) references public.lines(code) on update cascade;
  end if;
end $$;

-- Dostęp: czytają wszyscy zalogowani, zmieniają tylko liderzy, nikt nie kasuje
alter table public.lines enable row level security;
revoke all on public.lines from anon, authenticated;
grant select, insert, update on public.lines to authenticated;

drop policy if exists "odczyt lines" on public.lines;
create policy "odczyt lines" on public.lines for select to authenticated using (true);
drop policy if exists "dodawanie lines (lider)" on public.lines;
create policy "dodawanie lines (lider)" on public.lines
  for insert to authenticated with check (public.is_leader());
drop policy if exists "zmiana lines (lider)" on public.lines;
create policy "zmiana lines (lider)" on public.lines
  for update to authenticated using (public.is_leader()) with check (public.is_leader());

-- Odświeżanie na żywo
do $$ begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'lines') then
    alter publication supabase_realtime add table public.lines;
  end if;
end $$;
