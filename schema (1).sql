-- Tablica priorytetów UR – struktura bazy dla Supabase
-- Wklej całość w Supabase: SQL Editor -> New query -> Run

create table if not exists public.issues (
  id          uuid primary key default gen_random_uuid(),
  line        text not null,                       -- linia, np. A30
  title       text not null,                       -- krótki opis problemu
  description text default '',
  priority    text not null check (priority in ('W','S','N')),   -- Wysoki / Średni / Niski
  status      text not null default 'nowe'
              check (status in ('nowe','w_trakcie','czeka_czesc','czeka_postoj','rozwiazane')),
  lds         text default '',                     -- nr zgłoszenia w LDS
  created_by  text,
  created_at  timestamptz not null default now(),
  closed_at   timestamptz
);

create table if not exists public.entries (
  id          uuid primary key default gen_random_uuid(),
  issue_id    uuid not null references public.issues(id) on delete cascade,
  kind        text not null
              check (kind in ('utworzenie','komentarz','zrobione','do_zrobienia','status','przejecie')),
  author      text,
  text        text default '',
  status      text,                                -- nowy status, jeśli wpis go zmienił
  shift_key   text,                                -- np. 2026-11-26-Z2
  created_at  timestamptz not null default now()
);

create index if not exists entries_issue_idx on public.entries(issue_id);

-- Dostęp tylko dla zalogowanych (wspólne konto działu). Bez kasowania – historia zostaje.
alter table public.issues  enable row level security;
alter table public.entries enable row level security;

create policy "odczyt issues"  on public.issues  for select to authenticated using (true);
create policy "dodawanie issues" on public.issues for insert to authenticated with check (true);
create policy "zmiana issues"  on public.issues  for update to authenticated using (true);

create policy "odczyt entries" on public.entries for select to authenticated using (true);
create policy "dodawanie entries" on public.entries for insert to authenticated with check (true);

-- Uprawnienia API dla zalogowanych (potrzebne, gdy przy tworzeniu projektu
-- NIE zaznaczono "Grant API access to new tables automatically")
grant usage on schema public to authenticated;
grant select, insert, update on public.issues  to authenticated;
grant select, insert         on public.entries to authenticated;

-- Odświeżanie na żywo (telewizor widzi wpisy z telefonów od razu)
alter publication supabase_realtime add table public.issues, public.entries;
