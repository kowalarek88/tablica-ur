-- Migracja 002: konta liderów (role) zamiast PIN-u
-- Gdzie uruchomić: Supabase -> SQL Editor -> New query -> wklej CAŁY plik -> Run.
-- Uruchom PRZED wgraniem nowej wersji index.html. Można uruchomić ponownie – nic się nie zdubluje.
--
-- Co robi:
--  * tabela user_roles: kto jest liderem (dodaje priorytety, zmienia ich ważność, zarządza liniami),
--  * baza sama pilnuje uprawnień – wspólne konto działu nie doda priorytetu nawet z pominięciem aplikacji,
--  * godzinę wpisu i klucz zmiany nadaje serwer (nie zegar telefonu),
--  * karta i jej pierwszy wpis zapisują się razem (nie może powstać karta bez wpisu),
--  * zmiana statusu zapisuje się razem z wpisem,
--  * każda zmiana priorytetu / danych karty przez lidera trafia do historii jako wpis "edycja".
--
-- Nadawanie roli (po założeniu konta w Authentication -> Users):
--   select nadaj_lidera('adres@firma.pl', 'Imię Nazwisko');
-- Odbieranie roli:
--   select odbierz_role('adres@firma.pl');

-- 0. Uprawnienia API (gdyby nie zostały nadane przy zakładaniu projektu)
grant usage on schema public to authenticated;
grant select, insert, update on public.issues  to authenticated;
grant select, insert         on public.entries to authenticated;

-- 1. Tabela ról
create table if not exists public.user_roles (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  role         text not null default 'lider' check (role in ('lider','admin')),
  display_name text not null,                    -- podpis pod wpisami lidera
  created_at   timestamptz not null default now()
);
alter table public.user_roles enable row level security;
revoke all on public.user_roles from anon, authenticated;
grant select on public.user_roles to authenticated;
drop policy if exists "własna rola" on public.user_roles;
create policy "własna rola" on public.user_roles for select to authenticated using (user_id = auth.uid());

-- 2. Funkcje pomocnicze
create or replace function public.is_leader() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_roles where user_id = auth.uid())
$$;

create or replace function public.my_name() returns text
language sql stable security definer set search_path = public as $$
  select display_name from public.user_roles where user_id = auth.uid()
$$;

-- Klucz zmiany wg czasu polskiego: I 06–14, II 14–22, III 22–06 (III należy do dnia, w którym się zaczęła)
create or replace function public.shift_key(t timestamptz) returns text
language sql stable set search_path = public as $$
  select case
    when h >= 6  and h < 14 then to_char(l, 'YYYY-MM-DD') || '-Z1'
    when h >= 14 and h < 22 then to_char(l, 'YYYY-MM-DD') || '-Z2'
    when h >= 22            then to_char(l, 'YYYY-MM-DD') || '-Z3'
    else to_char(l - interval '1 day', 'YYYY-MM-DD') || '-Z3'
  end
  from (select t at time zone 'Europe/Warsaw' as l,
               extract(hour from t at time zone 'Europe/Warsaw') as h) x
$$;

create or replace function public.prio_label(p text) returns text
language sql immutable as $$
  select case p when 'W' then 'Wysoki' when 'S' then 'Średni' when 'N' then 'Niski' else coalesce(p, '') end
$$;

-- 3. Z którego konta zapisano (audyt)
alter table public.issues  add column if not exists created_by_uid uuid default auth.uid();
alter table public.entries add column if not exists author_uid     uuid default auth.uid();

-- 4. Nowy rodzaj wpisu: edycja (zmiana priorytetu lub danych karty przez lidera)
alter table public.entries drop constraint if exists entries_kind_check;
alter table public.entries add constraint entries_kind_check
  check (kind in ('utworzenie','komentarz','zrobione','do_zrobienia','status','przejecie','edycja'));

-- 5. Triggery
-- 5a. Nowa karta: czas serwera, podpis lidera
create or replace function public.tg_issues_bi() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.created_at     := now();
  new.created_by_uid := auth.uid();
  new.created_by     := coalesce(public.my_name(), nullif(btrim(new.created_by), ''), '?');
  new.status         := coalesce(new.status, 'nowe');
  new.closed_at      := case when new.status = 'rozwiazane' then now() end;
  return new;
end $$;
drop trigger if exists issues_bi on public.issues;
create trigger issues_bi before insert on public.issues
  for each row execute function public.tg_issues_bi();

-- 5b. Nowa karta: od razu wpis "utworzenie" (w tej samej transakcji)
create or replace function public.tg_issues_ai() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.entries (issue_id, kind, author, text)
  values (new.id, 'utworzenie', new.created_by, coalesce(new.description, ''));
  return null;
end $$;
drop trigger if exists issues_ai on public.issues;
create trigger issues_ai after insert on public.issues
  for each row execute function public.tg_issues_ai();

-- 5c. Zmiana karty: status może zmienić każdy, resztę (ważność, linia, opis, LDS) tylko lider.
--     Zmiany z panelu Supabase (Table Editor / SQL Editor) są dozwolone – tam nie ma zalogowanego użytkownika.
create or replace function public.tg_issues_bu() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (new.priority, new.line, new.title, coalesce(new.description, ''), coalesce(new.lds, ''))
     is distinct from
     (old.priority, old.line, old.title, coalesce(old.description, ''), coalesce(old.lds, ''))
     and auth.uid() is not null and not public.is_leader() then
    raise exception 'Tylko lider może zmieniać ważność priorytetu i dane zgłoszenia';
  end if;
  new.id             := old.id;
  new.created_at     := old.created_at;
  new.created_by     := old.created_by;
  new.created_by_uid := old.created_by_uid;
  if new.status = 'rozwiazane' and old.status <> 'rozwiazane' then
    new.closed_at := now();
  elsif new.status <> 'rozwiazane' then
    new.closed_at := null;
  else
    new.closed_at := old.closed_at;
  end if;
  return new;
end $$;
drop trigger if exists issues_bu on public.issues;
create trigger issues_bu before update on public.issues
  for each row execute function public.tg_issues_bu();

-- 5d. Zmiana ważności / danych karty -> wpis "edycja" w historii
create or replace function public.tg_issues_au() returns trigger
language plpgsql security definer set search_path = public as $$
declare ch text[] := '{}';
begin
  if new.priority is distinct from old.priority then
    ch := array_append(ch, 'Priorytet: ' || public.prio_label(old.priority) || ' → ' || public.prio_label(new.priority));
  end if;
  if new.line is distinct from old.line then
    ch := array_append(ch, 'Linia: ' || old.line || ' → ' || new.line);
  end if;
  if new.title is distinct from old.title then
    ch := array_append(ch, 'Problem: ' || new.title);
  end if;
  if coalesce(new.lds, '') <> coalesce(old.lds, '') then
    ch := array_append(ch, 'LDS: ' || coalesce(nullif(new.lds, ''), 'usunięto'));
  end if;
  if coalesce(new.description, '') <> coalesce(old.description, '') then
    ch := array_append(ch, 'Zmieniono opis');
  end if;
  if cardinality(ch) > 0 then
    insert into public.entries (issue_id, kind, author, text)
    values (new.id, 'edycja', coalesce(public.my_name(), 'panel Supabase'), array_to_string(ch, '; '));
  end if;
  return null;
end $$;
drop trigger if exists issues_au on public.issues;
create trigger issues_au after update on public.issues
  for each row execute function public.tg_issues_au();

-- 5e. Nowy wpis: czas i zmiana z serwera, podpis lidera z jego konta
create or replace function public.tg_entries_bi() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.created_at := now();
  new.shift_key  := public.shift_key(new.created_at);
  new.author_uid := auth.uid();
  new.author     := coalesce(public.my_name(), nullif(btrim(new.author), ''), '?');
  new.text       := coalesce(new.text, '');
  return new;
end $$;
drop trigger if exists entries_bi on public.entries;
create trigger entries_bi before insert on public.entries
  for each row execute function public.tg_entries_bi();

-- 5f. Wpis ze zmianą statusu -> status karty zmienia się w tej samej transakcji
create or replace function public.tg_entries_ai() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status is not null then
    update public.issues set status = new.status
    where id = new.issue_id and status is distinct from new.status;
  end if;
  return null;
end $$;
drop trigger if exists entries_ai on public.entries;
create trigger entries_ai after insert on public.entries
  for each row execute function public.tg_entries_ai();

-- 6. Kto może co dodawać
drop policy if exists "dodawanie issues" on public.issues;
drop policy if exists "dodawanie issues (lider)" on public.issues;
create policy "dodawanie issues (lider)" on public.issues
  for insert to authenticated with check (public.is_leader());

-- wpisy "utworzenie" i "edycja" tworzy wyłącznie baza (triggery powyżej)
drop policy if exists "dodawanie entries" on public.entries;
drop policy if exists "dodawanie entries (bez systemowych)" on public.entries;
create policy "dodawanie entries (bez systemowych)" on public.entries
  for insert to authenticated with check (kind not in ('utworzenie','edycja'));

-- polityka "zmiana issues" zostaje bez zmian – co wolno zmienić, pilnuje trigger 5c

-- 7. Nadawanie i odbieranie ról (tylko z SQL Editora, aplikacja nie ma do tego dostępu)
create or replace function public.nadaj_lidera(p_email text, p_name text, p_role text default 'lider')
returns text language plpgsql security definer set search_path = public as $$
declare v uuid;
begin
  select id into v from auth.users where lower(email) = lower(btrim(p_email));
  if v is null then
    raise exception 'Nie ma konta %. Najpierw załóż je: Authentication -> Users -> Add user.', p_email;
  end if;
  insert into public.user_roles (user_id, role, display_name) values (v, p_role, btrim(p_name))
  on conflict (user_id) do update set role = excluded.role, display_name = excluded.display_name;
  return 'OK: ' || btrim(p_name) || ' (' || p_email || ') ma rolę: ' || p_role;
end $$;

create or replace function public.odbierz_role(p_email text)
returns text language plpgsql security definer set search_path = public as $$
declare n int;
begin
  delete from public.user_roles
  where user_id in (select id from auth.users where lower(email) = lower(btrim(p_email)));
  get diagnostics n = row_count;
  return case when n > 0 then 'OK: odebrano rolę ' || p_email else 'Ta osoba nie miała roli: ' || p_email end;
end $$;

revoke all on function public.nadaj_lidera(text, text, text) from public, anon, authenticated;
revoke all on function public.odbierz_role(text)             from public, anon, authenticated;
