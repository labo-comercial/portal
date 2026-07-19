-- ============================================================================
-- Migración Planificación — 310 · Esquema planificacion_* en el PORTAL
-- ============================================================================
-- ⚠ Correr en el SQL Editor del proyecto del portal (wcpkpwxhqdcdljfwzcmy).
-- 100% ADITIVO y atómico. Réplica fiel de la radiografía 300 (correr por
-- Pablo), con estos cambios deliberados:
--   · Renames de la colisión interna (¡acá se resuelve la convención!):
--       planificacion          → planificacion_bloques
--       planificacion_personal → planificacion_bloques_personal
--       personal               → planificacion_personal
--     El resto: prefijo planificacion_ directo.
--   · presupuesto_compras / traslados_compras → planificacion_* (hoy son
--     features de esta app; si nace el módulo Compras se evalúa mudarlas).
--   · La tabla vieja `perfiles` NO se migra (la reemplaza el portal). El rol
--     pasa a cargo (admin/coordinador) y ve_sueldos a permisos jsonb.
--   · IDs bigint de actividad_log / linea_base_historial / proyectos_snapshot
--     recreados como IDENTITY (el 320 re-sincroniza las secuencias tras el
--     import).
--   · RLS: de "cualquier authenticated" a tiene_sector('planificacion').
--     Semánticas especiales replicadas: actividad_log la lee solo admin (y
--     dirección); linea_base sin delete; historial y snapshot append-only.
--   · ve_sueldos sigue siendo un flag de frontend (paridad con el viejo);
--     endurecerlo por RLS queda como mejora futura documentada.
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1 · Tablas núcleo
-- ---------------------------------------------------------------------------
create table public.planificacion_personal (       -- ex "personal" (la gente del taller)
  id           uuid primary key default gen_random_uuid(),
  legajo       text,
  nombre       text not null,
  especialidad text,
  convenio     text,
  tipo         text default 'Directo',
  costo_hora   numeric default 0,
  activo       boolean default true,
  creado_en    timestamptz default now(),
  sede         text not null default 'la_huella'
);

create table public.planificacion_proyectos (
  id                     uuid primary key default gen_random_uuid(),
  codigo                 text,
  nombre                 text not null,
  descripcion            text,
  cant_modulos           integer default 0,
  tam_modulos            text,
  fecha_entrega          date,
  fecha_montaje          date,
  presupuesto_mo         numeric default 0,
  planos                 text,
  estado                 text default 'Vigente',
  creado_en              timestamptz default now(),
  modulos                text,
  fecha_inicio           date,
  presupuesto_mo_huella  numeric not null default 0,
  presupuesto_mo_montaje numeric not null default 0,
  m2_totales             numeric,
  es_cotizacion          boolean not null default false,
  archivado              boolean not null default false,
  archivado_at           timestamptz
);

create table public.planificacion_trailers (
  id            uuid primary key default gen_random_uuid(),
  sede          text not null default 'neuquen',
  codigo        text,
  alias         text,
  estado        text not null default 'disponible',
  ubicacion     text,
  cliente       text,
  notas         text,
  creado_en     timestamptz not null default now(),
  if_codigo     text,
  tipo          text,
  medida        text,
  modelo        text,
  observaciones text
);

create table public.planificacion_feriados (
  id         uuid primary key default gen_random_uuid(),
  fecha      date not null,
  nombre     text,
  se_trabaja boolean default false,
  creado_en  timestamptz default now()
);

create table public.planificacion_no_disponibilidad (
  id         uuid primary key default gen_random_uuid(),
  persona_id uuid references public.planificacion_personal (id) on delete cascade,
  tipo       text not null,
  desde      date not null,
  hasta      date not null
);

create table public.planificacion_valor_hora_hist (
  id         uuid primary key default gen_random_uuid(),
  persona_id uuid not null references public.planificacion_personal (id) on delete cascade,
  mes        text not null,
  valor      numeric not null default 0,
  creado_en  timestamptz not null default now(),
  unique (persona_id, mes)
);

create table public.planificacion_especialidad_hist (
  id           uuid primary key default gen_random_uuid(),
  persona_id   uuid not null references public.planificacion_personal (id) on delete cascade,
  mes          text not null,
  especialidad text,
  creado_en    timestamptz not null default now(),
  unique (persona_id, mes)
);

-- ---------------------------------------------------------------------------
-- 2 · Planificación (Gantt) — la colisión resuelta
-- ---------------------------------------------------------------------------
create table public.planificacion_bloques (        -- ex "planificacion"
  id               uuid primary key default gen_random_uuid(),
  proyecto_id      uuid references public.planificacion_proyectos (id) on delete cascade,
  estacion         text not null,
  subtarea         text,
  fecha_desde      date,
  fecha_hasta      date,
  fecha_real_desde date,
  fecha_real_hasta date,
  modo             text default 'nombre',
  cantidad         integer default 0,
  perfil           text,
  creado_en        timestamptz default now(),
  modulos          text
);

create table public.planificacion_bloques_personal ( -- ex "planificacion_personal"
  id               uuid primary key default gen_random_uuid(),
  planificacion_id uuid references public.planificacion_bloques (id) on delete cascade,
  persona_id       uuid references public.planificacion_personal (id) on delete cascade,
  horas            numeric default 8
);

create table public.planificacion_supervision (
  id            uuid primary key default gen_random_uuid(),
  supervisor_id uuid references public.planificacion_personal (id) on delete cascade,
  proyectos     text,
  fecha_desde   date,
  fecha_hasta   date,
  horas         numeric default 8,
  creado_en     timestamptz default now()
);

-- ---------------------------------------------------------------------------
-- 3 · Mantenimiento (Neuquén)
-- ---------------------------------------------------------------------------
create table public.planificacion_mant_tareas (
  id          uuid primary key default gen_random_uuid(),
  sede        text not null default 'neuquen',
  trailer_id  uuid references public.planificacion_trailers (id) on delete cascade,
  descripcion text,
  estado      text not null default 'pendiente',
  fecha_desde date,
  fecha_hasta date,
  notas       text,
  creado_en   timestamptz not null default now(),
  tarea       text,
  subtarea    text,
  horas       numeric
);

create table public.planificacion_mant_tareas_personal (
  id         uuid primary key default gen_random_uuid(),
  tarea_id   uuid references public.planificacion_mant_tareas (id) on delete cascade,
  persona_id uuid references public.planificacion_personal (id) on delete cascade,
  creado_en  timestamptz not null default now()
);

create table public.planificacion_mant_parte (
  id        uuid primary key default gen_random_uuid(),
  sede      text not null default 'neuquen',
  tarea_id  uuid references public.planificacion_mant_tareas (id) on delete cascade,
  fecha     date not null,
  avance    text,
  creado_en timestamptz not null default now(),
  unique (tarea_id, fecha)
);

create table public.planificacion_mant_tareas_tipicas (
  id        uuid primary key default gen_random_uuid(),
  sede      text not null default 'neuquen',
  nombre    text not null,
  creado_en timestamptz not null default now(),
  tarea     text,
  subtarea  text
);

-- ---------------------------------------------------------------------------
-- 4 · Stock (Neuquén)
-- ---------------------------------------------------------------------------
create table public.planificacion_stock_items (
  id          uuid primary key default gen_random_uuid(),
  sede        text not null default 'neuquen',
  familia     text,
  codigo      text,
  descripcion text,
  unidad      text,
  cantidad    numeric not null default 0,
  minimo      numeric not null default 0,
  costo       numeric,
  creado_en   timestamptz not null default now()
);

create table public.planificacion_stock_mov (
  id          uuid primary key default gen_random_uuid(),
  sede        text not null default 'neuquen',
  tipo        text not null,
  fecha       date not null,
  responsable text,
  notas       text,
  creado_en   timestamptz not null default now()
);

create table public.planificacion_stock_mov_item (
  id        uuid primary key default gen_random_uuid(),
  mov_id    uuid references public.planificacion_stock_mov (id) on delete cascade,
  item_id   uuid references public.planificacion_stock_items (id) on delete restrict,
  cantidad  numeric not null default 0,
  creado_en timestamptz not null default now()
);

create table public.planificacion_stock_mov_trailer (
  id          uuid primary key default gen_random_uuid(),
  mov_item_id uuid references public.planificacion_stock_mov_item (id) on delete cascade,
  trailer_id  uuid references public.planificacion_trailers (id) on delete cascade,
  cantidad    numeric not null default 0,
  creado_en   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 5 · Ejecución real, líneas base, snapshots, log
-- ---------------------------------------------------------------------------
create table public.planificacion_detalle_diario (
  id              uuid primary key default gen_random_uuid(),
  fecha           date not null,
  persona_plan    uuid references public.planificacion_personal (id) on delete set null,
  persona_real    uuid references public.planificacion_personal (id) on delete set null,
  proyecto_id     uuid references public.planificacion_proyectos (id) on delete cascade,
  estacion_plan   text,
  subtarea_plan   text,
  estacion_real   text,
  subtarea_real   text,
  horas_normales  numeric default 8,
  horas_extra     numeric default 0,
  ausente         boolean default false,
  creado_en       timestamptz default now(),
  modulos_plan    text,
  modulos_real    text,
  motivo_desvio   text,
  horas_plan      numeric,
  es_extra        boolean not null default false,
  valor_hora_plan numeric,
  sede            text not null default 'la_huella',
  trailer_id      uuid references public.planificacion_trailers (id)
);
create index idx_planificacion_detalle_sede    on public.planificacion_detalle_diario (sede);
create index idx_planificacion_detalle_trailer on public.planificacion_detalle_diario (trailer_id);

create table public.planificacion_linea_base (
  proyecto_id uuid primary key references public.planificacion_proyectos (id) on delete cascade,
  fijada_at   timestamptz not null default now(),
  fijada_por  text,
  contenido   jsonb not null
);

create table public.planificacion_linea_base_historial (
  id             bigint generated by default as identity primary key,
  proyecto_id    uuid references public.planificacion_proyectos (id) on delete set null,
  fijada_at      timestamptz,
  fijada_por     text,
  reemplazada_at timestamptz not null default now(),
  reemplazada_por text,
  contenido      jsonb not null
);
create index idx_planificacion_lb_hist_proy on public.planificacion_linea_base_historial (proyecto_id);

create table public.planificacion_proyectos_snapshot (
  id              bigint generated by default as identity primary key,
  proyecto_id     uuid references public.planificacion_proyectos (id) on delete set null,
  proyecto_nombre text,
  snapshot_at     timestamptz not null default now(),
  creado_por      text,
  contenido       jsonb not null
);
create index idx_planificacion_snapshot_proyecto on public.planificacion_proyectos_snapshot (proyecto_id);

create table public.planificacion_actividad_log (
  id            bigint generated by default as identity primary key,
  creado_en     timestamptz not null default now(),
  sede          text not null,
  usuario_id    uuid,
  usuario_email text,
  accion        text not null,
  entidad       text not null,
  detalle       text
);
create index idx_planificacion_actividad_log_fecha on public.planificacion_actividad_log (creado_en desc);

-- ---------------------------------------------------------------------------
-- 6 · Puente a Compras (hoy features de planificación)
-- ---------------------------------------------------------------------------
create table public.planificacion_presupuesto_compras (
  id              uuid primary key default gen_random_uuid(),
  monto           numeric not null,
  notas           text,
  actualizado_en  timestamptz not null default now(),
  actualizado_por text
);

create table public.planificacion_traslados_compras (
  id                     uuid primary key default gen_random_uuid(),
  proyecto_id            uuid not null references public.planificacion_proyectos (id),
  bloque_id              uuid references public.planificacion_bloques (id) on delete set null,
  persona_directo_id     uuid not null references public.planificacion_personal (id),
  persona_contratista_id uuid not null references public.planificacion_personal (id),
  jornales               numeric not null,
  horas_por_jornal       numeric not null default 8,
  valor_hora             numeric not null,
  monto                  numeric not null,
  fecha_desde            date,
  fecha_hasta            date,
  estado                 text not null default 'pendiente_aviso'
                         constraint planificacion_traslados_estado_check
                         check (estado in ('pendiente_aviso','avisado','contratado','revertido')),
  creado_en              timestamptz not null default now(),
  creado_por             text,
  revertido_en           timestamptz,
  revertido_por          text,
  notas                  text
);
create index idx_planificacion_traslados_bloque   on public.planificacion_traslados_compras (bloque_id);
create index idx_planificacion_traslados_estado   on public.planificacion_traslados_compras (estado);
create index idx_planificacion_traslados_proyecto on public.planificacion_traslados_compras (proyecto_id);

-- ---------------------------------------------------------------------------
-- 7 · RLS — aislamiento por sector, con las semánticas especiales replicadas
-- ---------------------------------------------------------------------------
do $rls$
declare t text;
begin
  foreach t in array array[
    'planificacion_personal','planificacion_proyectos','planificacion_trailers',
    'planificacion_feriados','planificacion_no_disponibilidad',
    'planificacion_valor_hora_hist','planificacion_especialidad_hist',
    'planificacion_bloques','planificacion_bloques_personal','planificacion_supervision',
    'planificacion_mant_tareas','planificacion_mant_tareas_personal',
    'planificacion_mant_parte','planificacion_mant_tareas_tipicas',
    'planificacion_stock_items','planificacion_stock_mov',
    'planificacion_stock_mov_item','planificacion_stock_mov_trailer',
    'planificacion_detalle_diario','planificacion_linea_base',
    'planificacion_linea_base_historial','planificacion_proyectos_snapshot',
    'planificacion_actividad_log','planificacion_presupuesto_compras',
    'planificacion_traslados_compras']
  loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $rls$;

-- Acceso pleno del sector para las tablas operativas (mismo alcance que antes)
do $pol$
declare t text;
begin
  foreach t in array array[
    'planificacion_personal','planificacion_proyectos','planificacion_trailers',
    'planificacion_feriados','planificacion_no_disponibilidad',
    'planificacion_valor_hora_hist','planificacion_especialidad_hist',
    'planificacion_bloques','planificacion_bloques_personal','planificacion_supervision',
    'planificacion_mant_tareas','planificacion_mant_tareas_personal',
    'planificacion_mant_parte','planificacion_mant_tareas_tipicas',
    'planificacion_stock_items','planificacion_stock_mov',
    'planificacion_stock_mov_item','planificacion_stock_mov_trailer',
    'planificacion_detalle_diario','planificacion_presupuesto_compras',
    'planificacion_traslados_compras']
  loop
    execute format(
      'create policy %I on public.%I for all to authenticated
        using (public.tiene_sector(''planificacion''))
        with check (public.tiene_sector(''planificacion''))',
      t || '_sector', t);
  end loop;
end $pol$;

-- linea_base: select/insert/update, SIN delete (como el viejo)
create policy planificacion_linea_base_select on public.planificacion_linea_base
  for select to authenticated using (public.tiene_sector('planificacion'));
create policy planificacion_linea_base_insert on public.planificacion_linea_base
  for insert to authenticated with check (public.tiene_sector('planificacion'));
create policy planificacion_linea_base_update on public.planificacion_linea_base
  for update to authenticated
  using (public.tiene_sector('planificacion'))
  with check (public.tiene_sector('planificacion'));

-- linea_base_historial y proyectos_snapshot: append-only (select + insert)
create policy planificacion_lb_hist_select on public.planificacion_linea_base_historial
  for select to authenticated using (public.tiene_sector('planificacion'));
create policy planificacion_lb_hist_insert on public.planificacion_linea_base_historial
  for insert to authenticated with check (public.tiene_sector('planificacion'));

create policy planificacion_snapshot_select on public.planificacion_proyectos_snapshot
  for select to authenticated using (public.tiene_sector('planificacion'));
create policy planificacion_snapshot_insert on public.planificacion_proyectos_snapshot
  for insert to authenticated with check (public.tiene_sector('planificacion'));

-- actividad_log: inserta cualquiera del sector; LEE solo admin (y dirección)
create policy planificacion_actividad_insert on public.planificacion_actividad_log
  for insert to authenticated with check (public.tiene_sector('planificacion'));
create policy planificacion_actividad_select on public.planificacion_actividad_log
  for select to authenticated
  using (public.cargo_en_sector('planificacion') in ('admin', 'direccion'));

commit;

-- ---------------------------------------------------------------------------
-- Verificación: 25 tablas planificacion_* con RLS activado
-- ---------------------------------------------------------------------------
select count(*) as tablas_planificacion,
       count(*) filter (where relrowsecurity) as con_rls
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r' and c.relname like 'planificacion_%';
