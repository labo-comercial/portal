-- ============================================================================
-- Migración Diseño — 110 · Crear esquema diseno_* en el proyecto del PORTAL
-- ============================================================================
-- ⚠ Correr en el SQL Editor del proyecto del portal (wcpkpwxhqdcdljfwzcmy).
-- 100% ADITIVO: solo crea objetos nuevos con prefijo diseno_. Si algún nombre
-- existiera, falla con error y no pisa nada. Atómico (una transacción).
--
-- Fuente: radiografía 100 del proyecto viejo (2026-07-18). Réplica fiel de
-- tipos, defaults, checks, FKs, índices, vista, triggers y semántica de
-- políticas, con estos cambios deliberados:
--   · Prefijo diseno_ en tablas, índices, constraints y funciones.
--   · La tabla vieja `perfiles` NO se migra: la reemplazan las tablas del
--     portal (perfiles + perfiles_sector con cargo). Mapeo de roles viejos →
--     cargo: admin, coordinador, diseno, lectura (mismos nombres).
--   · Las FKs a auth.users se OMITEN a propósito: los usuarios de diseño
--     tendrán ids nuevos en este proyecto (login Microsoft) y los ids viejos
--     en columnas creado_por/hecho_por/cambiado_por quedan como dato
--     histórico. Los nombres legibles ya viven en *_nombre.
--   · La vista se crea con security_invoker=on para que respete el RLS del
--     usuario que consulta (clave para el aislamiento por sector).
--   · Bug corregido: la política vieja de minutas exigía rol 'disenio'
--     (typo); acá insertan coordinador/diseno como era la intención.
--   · Dirección (es_direccion) puede todo, en línea con el resto del portal.
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1 · Tablas (en orden de dependencias)
-- ---------------------------------------------------------------------------

create table public.diseno_cotizaciones (
  id              uuid primary key default gen_random_uuid(),
  nro_if          text not null,
  cliente         text not null,
  nombre_proyecto text not null,
  ficha           text,
  plazo_entrega   date,
  estado          text not null default 'abierta'
                  constraint diseno_cotizaciones_estado_check
                  check (estado in ('abierta','enviada','negociacion','ganada','perdida')),
  creado_por      uuid,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now()
);

create table public.diseno_proyectos (
  id                 uuid primary key default gen_random_uuid(),
  cotizacion_id      uuid references public.diseno_cotizaciones (id),
  nro_if             text not null,
  cliente            text not null,
  nombre             text not null,
  ficha              text,
  plazo_entrega      date,
  responsable        text,
  estado             text not null default 'sin_iniciar'
                     constraint diseno_proyectos_estado_check
                     check (estado in ('sin_iniciar','en_ejecucion','terminado','pausado')),
  plan_inicio        date,
  plan_fin_f1        date,
  plan_fin_f2        date,
  creado_en          timestamptz not null default now(),
  actualizado_en     timestamptz not null default now(),
  resp_diseno        text,
  resp_documentacion text,
  resp_tecnico       text,
  coord_produccion   text,
  inputs             jsonb default '{}'::jsonb,
  categoria          smallint
                     constraint diseno_proyectos_categoria_chk
                     check (categoria is null or categoria in (1,2,3)),
  rubros_redibujar   jsonb default '[]'::jsonb,
  modo_etapa3        text default 'ia'
                     constraint diseno_proyectos_modo3_chk
                     check (modo_etapa3 in ('ia','bim','dwg'))
);

create table public.diseno_etapas (
  id     integer primary key,
  fase   integer not null,
  orden  integer not null,
  nombre text not null
);

create table public.diseno_proyecto_checklist (
  id          uuid primary key default gen_random_uuid(),
  proyecto_id uuid not null references public.diseno_proyectos (id) on delete cascade,
  etapa_id    integer not null references public.diseno_etapas (id),
  cumplido    boolean not null default false,
  cumplido_en timestamptz,
  unique (proyecto_id, etapa_id)
);

create table public.diseno_tareas (
  id               uuid primary key default gen_random_uuid(),
  proyecto_id      uuid not null references public.diseno_proyectos (id) on delete cascade,
  parent_id        uuid references public.diseno_tareas (id) on delete cascade,
  etapa            integer not null,
  orden            integer not null default 0,
  nivel            text not null default 'tarea',
  tipo             text not null default 'normal',
  nombre           text not null,
  responsable      text,
  nota             text,
  cumplido         boolean not null default false,
  cumplido_en      timestamptz,
  fecha_inicio     date,
  fecha_fin        date,
  eliminada        boolean not null default false,
  rol              text,
  asigna_roles     boolean not null default false,
  auto_ia          boolean not null default false,
  base_inicio      date,
  base_fin         date,
  slug             text,
  dur_dias         smallint,
  analisis_general boolean default false,
  selecciona_modo3 boolean default false,
  revision_planta  boolean default false,
  minuta_flag      boolean default false,
  rev_fecha        date,
  rev_persona      text,
  minuta           jsonb
);

create table public.diseno_minutas (
  id                uuid primary key default gen_random_uuid(),
  tarea_id          uuid not null references public.diseno_tareas (id) on delete cascade,
  proyecto_id       uuid not null references public.diseno_proyectos (id) on delete cascade,
  fecha_hora        timestamptz,
  temas             text,
  requiere_revision boolean not null default false,
  detalle           text,
  creado_por        uuid,
  creado_por_nombre text,
  creado_en         timestamptz not null default now()
);

create table public.diseno_historial_actividad (
  id               uuid primary key default gen_random_uuid(),
  proyecto_id      uuid references public.diseno_proyectos (id) on delete cascade,
  proyecto_nombre  text,
  tipo             text not null,
  descripcion      text not null,
  detalle          jsonb,
  hecho_por        uuid,
  hecho_por_nombre text,
  created_at       timestamptz not null default now()
);

create table public.diseno_historial_proyecto (
  id              uuid primary key default gen_random_uuid(),
  proyecto_id     uuid references public.diseno_proyectos (id) on delete set null,
  proyecto_nombre text,
  accion          text not null
                  constraint diseno_historial_proyecto_accion_check
                  check (accion in ('editar','eliminar','crear')),
  detalle         jsonb,
  hecho_por       uuid,
  hecho_en        timestamptz not null default now()
);

create table public.diseno_historial_responsable (
  id            uuid primary key default gen_random_uuid(),
  tarea_id      uuid not null references public.diseno_tareas (id) on delete cascade,
  proyecto_id   uuid not null references public.diseno_proyectos (id) on delete cascade,
  resp_anterior text,
  resp_nuevo    text,
  motivo        text not null,
  cambiado_por  uuid,
  cambiado_en   timestamptz not null default now()
);

create table public.diseno_historial_fechas (
  id             uuid primary key default gen_random_uuid(),
  tarea_id       uuid not null references public.diseno_tareas (id) on delete cascade,
  proyecto_id    uuid not null references public.diseno_proyectos (id) on delete cascade,
  campo          text not null
                 constraint diseno_historial_fechas_campo_check
                 check (campo in ('inicio','fin')),
  fecha_anterior date,
  fecha_nueva    date,
  motivo         text not null
                 constraint diseno_historial_fechas_motivo_check
                 check (motivo in ('Planificacion','Cliente','Desarrollo')),
  detalle        text,
  cambiado_por   uuid,
  cambiado_en    timestamptz not null default now()
);

create table public.diseno_desvios_nc (
  id             uuid primary key default gen_random_uuid(),
  tipo           text not null
                 constraint diseno_desvios_nc_tipo_check
                 check (tipo in ('desvio','nc')),
  origen_id      text,
  proyecto_id    uuid references public.diseno_proyectos (id) on delete set null,
  titulo         text not null,
  descripcion    text,
  sector         text,
  estado         text not null default 'pendiente'
                 constraint diseno_desvios_nc_estado_check
                 check (estado in ('pendiente','en_tratamiento','cerrado')),
  fecha_registro date,
  responsable    text,
  detalle        jsonb default '{}'::jsonb,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.diseno_auditorias (
  id             uuid primary key default gen_random_uuid(),
  proyecto_id    uuid references public.diseno_proyectos (id) on delete set null,
  nombre_modelo  text,
  inventario     jsonb not null,
  resumen_rubros jsonb,
  hallazgos      jsonb,
  informe_texto  text,
  estado         text not null default 'pendiente'
                 constraint diseno_auditorias_estado_check
                 check (estado in ('pendiente','procesando','completada','error')),
  creado_por     uuid default auth.uid(),
  creado_en      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2 · Índices (réplica de los del proyecto viejo)
-- ---------------------------------------------------------------------------
create index idx_diseno_auditorias_creado  on public.diseno_auditorias (creado_en desc);
create index idx_diseno_auditorias_proyecto on public.diseno_auditorias (proyecto_id);
create index idx_diseno_desvios_estado on public.diseno_desvios_nc (estado);
create index idx_diseno_desvios_tipo   on public.diseno_desvios_nc (tipo);
create index idx_diseno_histact_created  on public.diseno_historial_actividad (created_at desc);
create index idx_diseno_histact_proyecto on public.diseno_historial_actividad (proyecto_id, created_at desc);
create index idx_diseno_histfechas_proy  on public.diseno_historial_fechas (proyecto_id);
create index idx_diseno_histfechas_tarea on public.diseno_historial_fechas (tarea_id);
create index idx_diseno_histproy_proy    on public.diseno_historial_proyecto (proyecto_id);
create index idx_diseno_histresp_tarea   on public.diseno_historial_responsable (tarea_id);
create index idx_diseno_minutas_proyecto on public.diseno_minutas (proyecto_id);
create index idx_diseno_minutas_tarea    on public.diseno_minutas (tarea_id);
create index idx_diseno_tareas_parent    on public.diseno_tareas (parent_id);
create index idx_diseno_tareas_proyecto  on public.diseno_tareas (proyecto_id);
create index idx_diseno_tareas_proyecto_slug on public.diseno_tareas (proyecto_id, slug) where slug is not null;

-- ---------------------------------------------------------------------------
-- 3 · Vista v_diseno_proyectos (security_invoker: respeta el RLS del usuario)
-- ---------------------------------------------------------------------------
create view public.v_diseno_proyectos
with (security_invoker = on) as
with hojas as (
  select t.proyecto_id, t.id, t.etapa, t.orden, t.nombre, t.cumplido, t.parent_id,
         (not exists (select 1 from public.diseno_tareas c
                       where c.parent_id = t.id and c.eliminada = false)) as es_hoja
    from public.diseno_tareas t
   where t.eliminada = false
), av as (
  select proyecto_id,
         count(*) filter (where es_hoja) as total,
         count(*) filter (where es_hoja and cumplido) as hechos
    from hojas
   group by proyecto_id
), actual as (
  select distinct on (proyecto_id) proyecto_id,
         nombre as tarea_actual,
         etapa  as etapa_actual
    from hojas
   where es_hoja and not cumplido
   order by proyecto_id, etapa, orden
)
select p.id, p.cotizacion_id, p.nro_if, p.cliente, p.nombre, p.ficha,
       p.plazo_entrega, p.responsable, p.estado, p.plan_inicio, p.plan_fin_f1,
       p.plan_fin_f2, p.creado_en, p.actualizado_en, p.resp_diseno,
       p.resp_documentacion, p.resp_tecnico, p.coord_produccion, p.inputs,
       coalesce(av.hechos, 0) as checks_hechos,
       coalesce(av.total, 0)  as checks_total,
       case when coalesce(av.total, 0) = 0 then 0::numeric
            else round((coalesce(av.hechos, 0)::numeric / av.total::numeric) * 100)
       end as avance_pct,
       ac.tarea_actual, ac.etapa_actual,
       p.categoria, p.rubros_redibujar, p.modo_etapa3
  from public.diseno_proyectos p
  left join av on av.proyecto_id = p.id
  left join actual ac on ac.proyecto_id = p.id;

-- ---------------------------------------------------------------------------
-- 4 · Funciones de trigger (réplica con tablas renombradas)
-- ---------------------------------------------------------------------------
create or replace function public.diseno_crear_checklist_proyecto()
returns trigger
language plpgsql security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.diseno_proyecto_checklist where proyecto_id = new.id) then
    insert into public.diseno_proyecto_checklist (proyecto_id, etapa_id)
    select new.id, id from public.diseno_etapas;
  end if;
  return new;
end; $$;

create or replace function public.diseno_crear_proyecto_desde_cotizacion()
returns trigger
language plpgsql security definer
set search_path = public
as $$
declare
  nuevo_id uuid;
begin
  if new.estado = 'ganada' and (old.estado is distinct from 'ganada') then
    if not exists (select 1 from public.diseno_proyectos where cotizacion_id = new.id) then
      insert into public.diseno_proyectos (cotizacion_id, nro_if, cliente, nombre, ficha, plazo_entrega)
      values (new.id, new.nro_if, new.cliente, new.nombre_proyecto, new.ficha, new.plazo_entrega)
      returning id into nuevo_id;

      insert into public.diseno_proyecto_checklist (proyecto_id, etapa_id)
      select nuevo_id, id from public.diseno_etapas;
    end if;
  end if;
  return new;
end; $$;

create trigger trg_diseno_cotizacion_ganada
  after update on public.diseno_cotizaciones
  for each row execute function public.diseno_crear_proyecto_desde_cotizacion();

create trigger trg_diseno_checklist_nuevo_proyecto
  after insert on public.diseno_proyectos
  for each row execute function public.diseno_crear_checklist_proyecto();

-- ---------------------------------------------------------------------------
-- 5 · RLS — aislamiento por sector + granularidad por cargo
--     Cargos (perfiles_sector.cargo): admin | coordinador | diseno | lectura
--     cargo_en_sector('diseno') devuelve 'direccion' para es_direccion.
--     Semántica replicada del proyecto viejo (duplicados fusionados).
-- ---------------------------------------------------------------------------
alter table public.diseno_cotizaciones        enable row level security;
alter table public.diseno_proyectos           enable row level security;
alter table public.diseno_etapas              enable row level security;
alter table public.diseno_proyecto_checklist  enable row level security;
alter table public.diseno_tareas              enable row level security;
alter table public.diseno_minutas             enable row level security;
alter table public.diseno_historial_actividad enable row level security;
alter table public.diseno_historial_proyecto  enable row level security;
alter table public.diseno_historial_responsable enable row level security;
alter table public.diseno_historial_fechas    enable row level security;
alter table public.diseno_desvios_nc          enable row level security;
alter table public.diseno_auditorias          enable row level security;

-- cotizaciones: lee el sector; escribe coordinación/dirección (el flujo
-- externo que las carga usa service role y no pasa por acá)
create policy diseno_cotizaciones_select on public.diseno_cotizaciones
  for select to authenticated using (public.tiene_sector('diseno'));
create policy diseno_cotizaciones_write on public.diseno_cotizaciones
  for all to authenticated
  using (public.cargo_en_sector('diseno') in ('admin','coordinador','direccion'))
  with check (public.cargo_en_sector('diseno') in ('admin','coordinador','direccion'));

-- proyectos: lee el sector; crea/edita/borra coordinación o diseño
create policy diseno_proyectos_select on public.diseno_proyectos
  for select to authenticated using (public.tiene_sector('diseno'));
create policy diseno_proyectos_write on public.diseno_proyectos
  for all to authenticated
  using (public.cargo_en_sector('diseno') in ('admin','coordinador','diseno','direccion'))
  with check (public.cargo_en_sector('diseno') in ('admin','coordinador','diseno','direccion'));

-- etapas: catálogo, lee el sector; escribe solo dirección
create policy diseno_etapas_select on public.diseno_etapas
  for select to authenticated using (public.tiene_sector('diseno'));
create policy diseno_etapas_write on public.diseno_etapas
  for all to authenticated
  using (public.es_direccion()) with check (public.es_direccion());

-- checklist: lee el sector; tilda diseño/coordinación
create policy diseno_checklist_select on public.diseno_proyecto_checklist
  for select to authenticated using (public.tiene_sector('diseno'));
create policy diseno_checklist_update on public.diseno_proyecto_checklist
  for update to authenticated
  using (public.cargo_en_sector('diseno') in ('admin','coordinador','diseno','direccion'))
  with check (public.cargo_en_sector('diseno') in ('admin','coordinador','diseno','direccion'));

-- tareas: lee el sector; crea/borra coordinación; edita coordinación o el
-- responsable de la tarea (match por nombre de perfil, como en el viejo)
create policy diseno_tareas_select on public.diseno_tareas
  for select to authenticated using (public.tiene_sector('diseno'));
create policy diseno_tareas_insert on public.diseno_tareas
  for insert to authenticated
  with check (public.cargo_en_sector('diseno') in ('admin','coordinador','direccion'));
create policy diseno_tareas_delete on public.diseno_tareas
  for delete to authenticated
  using (public.cargo_en_sector('diseno') in ('admin','coordinador','direccion'));
create policy diseno_tareas_update_coord on public.diseno_tareas
  for update to authenticated
  using (public.cargo_en_sector('diseno') in ('admin','coordinador','direccion'))
  with check (public.cargo_en_sector('diseno') in ('admin','coordinador','direccion'));
create policy diseno_tareas_update_resp on public.diseno_tareas
  for update to authenticated
  using (public.tiene_sector('diseno') and responsable is not null
         and responsable = (select nombre from public.perfiles where id = (select auth.uid())))
  with check (public.tiene_sector('diseno') and responsable is not null
         and responsable = (select nombre from public.perfiles where id = (select auth.uid())));

-- minutas: lee el sector; inserta coordinación o diseño (typo 'disenio'
-- del proyecto viejo corregido); append-only (sin update/delete)
create policy diseno_minutas_select on public.diseno_minutas
  for select to authenticated using (public.tiene_sector('diseno'));
create policy diseno_minutas_insert on public.diseno_minutas
  for insert to authenticated
  with check (public.cargo_en_sector('diseno') in ('admin','coordinador','diseno','direccion'));

-- historial_actividad: lee el sector; inserta cualquiera del sector
create policy diseno_histact_select on public.diseno_historial_actividad
  for select to authenticated using (public.tiene_sector('diseno'));
create policy diseno_histact_insert on public.diseno_historial_actividad
  for insert to authenticated with check (public.tiene_sector('diseno'));

-- historial_proyecto / responsable / fechas: lee el sector; inserta coordinación
create policy diseno_histproy_select on public.diseno_historial_proyecto
  for select to authenticated using (public.tiene_sector('diseno'));
create policy diseno_histproy_insert on public.diseno_historial_proyecto
  for insert to authenticated
  with check (public.cargo_en_sector('diseno') in ('admin','coordinador','direccion'));

create policy diseno_histresp_select on public.diseno_historial_responsable
  for select to authenticated using (public.tiene_sector('diseno'));
create policy diseno_histresp_insert on public.diseno_historial_responsable
  for insert to authenticated
  with check (public.cargo_en_sector('diseno') in ('admin','coordinador','direccion'));

create policy diseno_histfechas_select on public.diseno_historial_fechas
  for select to authenticated using (public.tiene_sector('diseno'));
create policy diseno_histfechas_insert on public.diseno_historial_fechas
  for insert to authenticated
  with check (public.cargo_en_sector('diseno') in ('admin','coordinador','direccion'));

-- desvios_nc: lee el sector; crea/edita coordinación
create policy diseno_desvios_select on public.diseno_desvios_nc
  for select to authenticated using (public.tiene_sector('diseno'));
create policy diseno_desvios_insert on public.diseno_desvios_nc
  for insert to authenticated
  with check (public.cargo_en_sector('diseno') in ('admin','coordinador','direccion'));
create policy diseno_desvios_update on public.diseno_desvios_nc
  for update to authenticated
  using (public.cargo_en_sector('diseno') in ('admin','coordinador','direccion'))
  with check (public.cargo_en_sector('diseno') in ('admin','coordinador','direccion'));

-- auditorias: lee el sector; crea/edita coordinación o diseño; borra coordinación
create policy diseno_auditorias_select on public.diseno_auditorias
  for select to authenticated using (public.tiene_sector('diseno'));
create policy diseno_auditorias_insert on public.diseno_auditorias
  for insert to authenticated
  with check (public.cargo_en_sector('diseno') in ('admin','coordinador','diseno','direccion'));
create policy diseno_auditorias_update on public.diseno_auditorias
  for update to authenticated
  using (public.cargo_en_sector('diseno') in ('admin','coordinador','diseno','direccion'))
  with check (public.cargo_en_sector('diseno') in ('admin','coordinador','diseno','direccion'));
create policy diseno_auditorias_delete on public.diseno_auditorias
  for delete to authenticated
  using (public.cargo_en_sector('diseno') in ('admin','coordinador','direccion'));

commit;

-- ---------------------------------------------------------------------------
-- Verificación
-- ---------------------------------------------------------------------------
select c.relname as tabla, c.relrowsecurity as rls
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r' and c.relname like 'diseno_%'
 order by 1;
