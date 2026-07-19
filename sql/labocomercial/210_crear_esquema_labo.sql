-- ============================================================================
-- Migración LABO — 210 · Crear esquema labocomercial_* en el proyecto del PORTAL
-- ============================================================================
-- ⚠ Correr en el SQL Editor del proyecto del portal (wcpkpwxhqdcdljfwzcmy).
-- 100% ADITIVO y atómico. Réplica fiel de la radiografía 200 (2026-07-18),
-- con estos cambios deliberados:
--   · Prefijo labocomercial_ en tablas, RPCs y la vista (convención del portal).
--   · RLS pasa de "cualquier authenticated" a tiene_sector('labocomercial').
--   · La vista de la agencia se recrea SIN security_invoker a propósito:
--     hoy es legible con la anon key (así la consume la agencia) y ese
--     comportamiento se preserva. Expone solo entry_id/etapa/estado/calidad/
--     comentarios de contactos web — no toca leads ni cotizaciones.
--   · ingest_contacto_web queda ejecutable por anon (así la llama el
--     pipeline del sitio web), igual que en el proyecto viejo.
--   · Se omite el índice redundante idx_labo_contactos_web_entry_id (la
--     constraint UNIQUE ya crea uno idéntico).
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1 · Tablas
-- ---------------------------------------------------------------------------
create table public.labocomercial_leads (
  id               text primary key,          -- generado por la app ('lead_'+timestamp)
  lead_num         integer,
  fecha            timestamptz default now(),
  cliente          text not null,
  contacto         text,
  email            text,
  tel              text,
  terreno          text,
  vendedor         text,
  lugar            text,
  etapa            text default 'Cotizado',
  motivo_perdida   text,
  cotizaciones     jsonb default '[]'::jsonb, -- array embebido de cotizaciones
  actividad        jsonb default '[]'::jsonb, -- array embebido de actividad
  total_pipeline   numeric default 0,
  ultima_cot       jsonb,
  fecha_ultima_cot timestamptz,
  created_at       timestamptz default now(),
  updated_at       timestamptz default now()
);

create table public.labocomercial_counters (
  name  text primary key,
  value integer default 0
);

create table public.labocomercial_contactos_web (
  id              uuid primary key default gen_random_uuid(),
  entry_id        text not null unique,
  fecha           date,
  nombre          text,
  telefono        text,
  email           text,
  modelo          text,
  tipo_proyecto   text,
  comentario_form text,
  url             text,
  etapa           text not null default '1er contacto',
  estado          text not null default 'En curso',
  calidad         text,
  comentarios     jsonb not null default '[]'::jsonb,
  lead_id         text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2 · Vista para la agencia (comportamiento actual preservado: definer,
--     legible con la anon key — NO agregar security_invoker acá)
-- ---------------------------------------------------------------------------
create view public.labocomercial_contactos_web_agencia as
select entry_id, etapa, estado, calidad, comentarios
  from public.labocomercial_contactos_web;

-- ---------------------------------------------------------------------------
-- 3 · RPCs
-- ---------------------------------------------------------------------------
create or replace function public.labocomercial_next_counter(counter_name text)
returns integer
language sql
as $$
  update public.labocomercial_counters
     set value = value + 1
   where name = counter_name
  returning value;
$$;

-- solo usuarios logueados (la app); nunca anon
revoke all on function public.labocomercial_next_counter(text) from public, anon;
grant execute on function public.labocomercial_next_counter(text) to authenticated, service_role;

create or replace function public.labocomercial_ingest_contacto_web(
  p_entry_id text, p_fecha date, p_nombre text, p_telefono text, p_email text,
  p_modelo text, p_tipo_proyecto text, p_comentario_form text, p_url text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.labocomercial_contactos_web
    (entry_id, fecha, nombre, telefono, email, modelo, tipo_proyecto, comentario_form, url)
  values
    (p_entry_id, p_fecha, p_nombre, p_telefono, p_email, p_modelo, p_tipo_proyecto, p_comentario_form, p_url)
  on conflict (entry_id) do nothing;
end;
$$;
-- el pipeline del sitio web la llama con la anon key: debe quedar ejecutable
grant execute on function public.labocomercial_ingest_contacto_web(text,date,text,text,text,text,text,text,text)
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 4 · RLS — aislamiento por sector (LABO no tenía roles internos: todos los
--     del sector operan todo, misma semántica que antes)
-- ---------------------------------------------------------------------------
alter table public.labocomercial_leads enable row level security;
alter table public.labocomercial_counters enable row level security;
alter table public.labocomercial_contactos_web enable row level security;

create policy labocomercial_leads_all on public.labocomercial_leads
  for all to authenticated
  using (public.tiene_sector('labocomercial'))
  with check (public.tiene_sector('labocomercial'));

-- counters: select/insert/update, sin delete (igual que el proyecto viejo)
create policy labocomercial_counters_select on public.labocomercial_counters
  for select to authenticated using (public.tiene_sector('labocomercial'));
create policy labocomercial_counters_insert on public.labocomercial_counters
  for insert to authenticated with check (public.tiene_sector('labocomercial'));
create policy labocomercial_counters_update on public.labocomercial_counters
  for update to authenticated
  using (public.tiene_sector('labocomercial'))
  with check (public.tiene_sector('labocomercial'));

create policy labocomercial_contactos_web_all on public.labocomercial_contactos_web
  for all to authenticated
  using (public.tiene_sector('labocomercial'))
  with check (public.tiene_sector('labocomercial'));

commit;

-- ---------------------------------------------------------------------------
-- Verificación
-- ---------------------------------------------------------------------------
select c.relname as objeto, c.relkind as tipo, c.relrowsecurity as rls
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relname like 'labocomercial_%'
 order by 1;
