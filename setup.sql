-- Unser Raum: Datenbank-Setup für Supabase
-- Einmal komplett im SQL Editor des Supabase-Projekts ausführen.
-- Die Daten liegen in einem eigenen Schema "unser_raum", das die öffentliche
-- Schnittstelle nicht sieht. Lesen und Schreiben geht nur über die drei
-- Funktionen ur_load, ur_put und ur_delete, und nur mit einem gültigen
-- persönlichen Link.

create extension if not exists pgcrypto with schema extensions;

create schema if not exists unser_raum;
revoke all on schema unser_raum from public, anon, authenticated;

create table if not exists unser_raum.members (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  token_hash text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists unser_raum.items (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('entries','promises','trust','topics','sessions','questions')),
  author uuid references unser_raum.members(id) on delete set null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists items_kind_created_idx on unser_raum.items (kind, created_at desc);

-- Zusätzliche Sicherung: RLS an, keine Policies. Direkt kommt niemand an die Tabellen.
alter table unser_raum.members enable row level security;
alter table unser_raum.items enable row level security;

-- Prüft den Link und gibt die Person zurück
create or replace function unser_raum.require_member(p_token text)
returns uuid
language plpgsql stable security definer
set search_path = ''
as $$
declare v_id uuid;
begin
  if p_token is null or length(p_token) < 32 then
    raise exception 'Zugang ungültig';
  end if;
  select m.id into v_id
    from unser_raum.members m
   where m.token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex');
  if v_id is null then
    raise exception 'Zugang ungültig';
  end if;
  return v_id;
end
$$;

-- Erstellt einen neuen persönlichen Link (oder ersetzt den alten, wenn es den Namen schon gibt).
-- Nur im SQL Editor aufrufbar, nicht über die Website.
create or replace function unser_raum.new_link(p_name text)
returns text
language plpgsql security definer
set search_path = ''
as $$
declare
  v_token text := encode(extensions.gen_random_bytes(24), 'hex');
  v_hash text := encode(extensions.digest(v_token, 'sha256'), 'hex');
begin
  update unser_raum.members set token_hash = v_hash where name = p_name;
  if not found then
    insert into unser_raum.members (name, token_hash) values (p_name, v_hash);
  end if;
  return v_token;
end
$$;
revoke all on function unser_raum.new_link(text) from public, anon, authenticated;
revoke all on function unser_raum.require_member(text) from public, anon, authenticated;

-- Alles laden
create or replace function public.ur_load(p_token text)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare v_me uuid;
begin
  v_me := unser_raum.require_member(p_token);
  return jsonb_build_object(
    'me', v_me,
    'members', coalesce((
      select jsonb_agg(jsonb_build_object('id', m.id, 'name', m.name) order by m.created_at)
        from unser_raum.members m), '[]'::jsonb),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', i.id, 'kind', i.kind, 'author', i.author, 'data', i.data) order by i.created_at desc)
        from unser_raum.items i), '[]'::jsonb)
  );
end
$$;

-- Neu anlegen (p_id = null) oder ändern (p_merge = true fügt Felder zusammen)
create or replace function public.ur_put(p_token text, p_kind text, p_id uuid, p_data jsonb, p_merge boolean default true)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare v_me uuid; v_id uuid;
begin
  v_me := unser_raum.require_member(p_token);
  if p_data is null or jsonb_typeof(p_data) <> 'object' then
    raise exception 'Ungültige Daten';
  end if;
  if pg_column_size(p_data) > 200000 then
    raise exception 'Eintrag zu groß';
  end if;
  if p_id is null then
    insert into unser_raum.items (kind, author, data)
    values (p_kind, v_me, p_data)
    returning id into v_id;
  else
    update unser_raum.items
       set data = case when p_merge then data || p_data else p_data end,
           updated_at = now()
     where id = p_id
    returning id into v_id;
    if v_id is null then
      raise exception 'Nicht gefunden';
    end if;
  end if;
  return jsonb_build_object('id', v_id);
end
$$;

-- Löschen
create or replace function public.ur_delete(p_token text, p_id uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  perform unser_raum.require_member(p_token);
  delete from unser_raum.items where id = p_id;
end
$$;

revoke all on function public.ur_load(text) from public;
revoke all on function public.ur_put(text, text, uuid, jsonb, boolean) from public;
revoke all on function public.ur_delete(text, uuid) from public;
grant execute on function public.ur_load(text) to anon, authenticated;
grant execute on function public.ur_put(text, text, uuid, jsonb, boolean) to anon, authenticated;
grant execute on function public.ur_delete(text, uuid) to anon, authenticated;

notify pgrst, 'reload schema';
