-- ============================================================================
-- Portal 4housing — Etapa 1 · Fundación de control de acceso
-- ============================================================================
-- Se ejecuta UNA vez, A MANO (SQL Editor), en el proyecto de 4housing
-- comercial (wcpkpwxhqdcdljfwzcmy), que pasa a ser la base del portal
-- unificado. Decisión 2026-07-18 (límite de proyectos free).
--
-- ES 100% ADITIVO sobre ese proyecto en producción: crea objetos nuevos
-- (enum, 2 tablas, funciones, un trigger sobre auth.users) y NO modifica
-- ninguna tabla, política ni función existente del CRM comercial.
-- Si algún nombre ya existiera, el script falla con error y no pisa nada.
-- Las otras 3 apps siguen apuntando a sus proyectos originales hasta que
-- cada módulo se migre.
--
-- Modelo:
--   perfiles         → 1 fila por usuario del portal (id = auth.users.id)
--   perfiles_sector  → qué sector ve cada usuario y con qué cargo
--   es_direccion     → acceso a todos los sectores sin fila por sector
--
-- La seguridad real la hacen las políticas RLS de cada tabla de módulo,
-- que llaman a tiene_sector('<sector>') / es_direccion().
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1 · Enum de sectores — los 6 desde el día uno, mismos strings que los
--     prefijos de tabla. Compras y Logística existen ya aunque sus módulos
--     se sumen más adelante.
-- ---------------------------------------------------------------------------
create type public.sector_portal as enum (
  'fhcomercial',
  'labocomercial',
  'diseno',
  'planificacion',
  'compras',
  'logistica'
);

-- ---------------------------------------------------------------------------
-- 2 · Tablas de acceso
-- ---------------------------------------------------------------------------
create table public.perfiles (
  id             uuid primary key references auth.users (id) on delete cascade,
  email          text not null unique,
  nombre         text,
  -- activo=false por defecto: alguien del tenant que loguea por primera vez
  -- queda registrado pero no ve nada hasta que dirección lo habilite.
  activo         boolean not null default false,
  es_direccion   boolean not null default false,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.perfiles_sector (
  perfil_id uuid not null references public.perfiles (id) on delete cascade,
  sector    public.sector_portal not null,
  -- cargo dentro del sector: 'responsable' | 'miembro' | 'lectura'
  -- (texto libre a propósito: cada sector puede definir cargos propios sin
  --  migración; los valores válidos se acuerdan por convención)
  cargo     text not null default 'miembro',
  -- flags puntuales por sector, ej. {"ve_sueldos": true} en planificación
  permisos  jsonb not null default '{}'::jsonb,
  creado_en timestamptz not null default now(),
  primary key (perfil_id, sector)
);

comment on table public.perfiles is
  'Usuarios del portal 4housing. 1 fila por auth.users. activo=false hasta que dirección habilita.';
comment on table public.perfiles_sector is
  'Permisos por sector y cargo. Dirección no necesita filas acá (es_direccion=true en perfiles).';

-- ---------------------------------------------------------------------------
-- 3 · Alta automática de perfil al primer login
--     (el login Microsoft single-tenant ya garantiza que solo entra gente
--      de la organización; esto solo registra el perfil, inactivo)
-- ---------------------------------------------------------------------------
create or replace function public.crear_perfil_al_registrarse()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.perfiles (id, email, nombre)
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(coalesce(new.email, ''), '@', 1)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger trg_crear_perfil
  after insert on auth.users
  for each row execute function public.crear_perfil_al_registrarse();

-- ---------------------------------------------------------------------------
-- 4 · Funciones helper para las políticas RLS de todo el portal
--     SECURITY DEFINER para poder leer perfiles sin recursión de RLS.
--     STABLE para que Postgres las cachee dentro de cada query.
-- ---------------------------------------------------------------------------
create or replace function public.es_direccion()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select coalesce(
    (select p.es_direccion and p.activo
       from public.perfiles p
      where p.id = (select auth.uid())),
    false
  );
$$;

create or replace function public.tiene_sector(s public.sector_portal)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select public.es_direccion()
      or exists (
           select 1
             from public.perfiles p
             join public.perfiles_sector ps on ps.perfil_id = p.id
            where p.id = (select auth.uid())
              and p.activo
              and ps.sector = s
         );
$$;

-- cargo del usuario en un sector ('direccion' si es_direccion; null si no tiene acceso)
create or replace function public.cargo_en_sector(s public.sector_portal)
returns text
language sql stable security definer
set search_path = public
as $$
  select case
    when public.es_direccion() then 'direccion'
    else (
      select ps.cargo
        from public.perfiles p
        join public.perfiles_sector ps on ps.perfil_id = p.id
       where p.id = (select auth.uid())
         and p.activo
         and ps.sector = s
    )
  end;
$$;

revoke all on function public.es_direccion() from public, anon;
revoke all on function public.tiene_sector(public.sector_portal) from public, anon;
revoke all on function public.cargo_en_sector(public.sector_portal) from public, anon;
grant execute on function public.es_direccion() to authenticated;
grant execute on function public.tiene_sector(public.sector_portal) to authenticated;
grant execute on function public.cargo_en_sector(public.sector_portal) to authenticated;

-- ---------------------------------------------------------------------------
-- 5 · RLS sobre las propias tablas de acceso
-- ---------------------------------------------------------------------------
alter table public.perfiles enable row level security;
alter table public.perfiles_sector enable row level security;

-- cada usuario ve su propio perfil; dirección ve todos
create policy perfiles_select on public.perfiles
  for select to authenticated
  using (id = (select auth.uid()) or public.es_direccion());

-- solo dirección modifica perfiles (habilitar usuarios, marcar dirección)
create policy perfiles_update on public.perfiles
  for update to authenticated
  using (public.es_direccion())
  with check (public.es_direccion());

-- el insert lo hace únicamente el trigger (security definer); no hay policy
-- de insert/delete para authenticated a propósito.

-- cada usuario ve sus sectores; dirección ve y administra todos
create policy perfiles_sector_select on public.perfiles_sector
  for select to authenticated
  using (perfil_id = (select auth.uid()) or public.es_direccion());

create policy perfiles_sector_admin on public.perfiles_sector
  for all to authenticated
  using (public.es_direccion())
  with check (public.es_direccion());

-- ---------------------------------------------------------------------------
-- 6 · Backfill — perfiles para los usuarios que YA existen en auth.users
--     (el equipo comercial que ya loguea en la app de 4H). Idempotente.
--     Quedan con activo=false: la app comercial actual no lee perfiles,
--     así que esto no cambia nada de su operación diaria.
-- ---------------------------------------------------------------------------
insert into public.perfiles (id, email, nombre)
select u.id,
       coalesce(u.email, ''),
       coalesce(
         u.raw_user_meta_data ->> 'full_name',
         u.raw_user_meta_data ->> 'name',
         split_part(coalesce(u.email, ''), '@', 1)
       )
  from auth.users u
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 7 · Bootstrap — ejecutar a mano DESPUÉS de correr todo lo anterior.
--     (comentado a propósito: editá el email si hace falta y descomentá)
-- ---------------------------------------------------------------------------
-- update public.perfiles
--    set es_direccion = true, activo = true
--  where email = 'pablospinetto@4housing.com.ar';
