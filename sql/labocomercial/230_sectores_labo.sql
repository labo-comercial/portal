-- ============================================================================
-- Migración LABO — 230 · Sector labocomercial para el equipo
-- ============================================================================
-- ⚠ Correr en el proyecto del PORTAL. IDEMPOTENTE (re-correr las veces que
-- haga falta). Los 3 usuarios de la empresa ya existen en el portal (son del
-- equipo comercial), así que esto se puede correr YA, sin esperar logins.
--
-- LABO no tenía roles internos (todos operan todo) → cargo 'miembro' parejo.
--
-- NICOLÁS TOVO (vendedor externo, solo cotiza LABO): pendiente de que Azure
-- lo habilite (invitación B2B guest con su Gmail, o cuenta @4housing).
-- Cuando exista su cuenta y haya logueado una vez al portal, descomentar su
-- línea (con el email con el que haya quedado registrado) y re-correr.
-- Su aislamiento lo garantiza RLS: con solo el sector labocomercial no puede
-- leer ni una fila del CRM ni de diseño, sin importar qué URL abra.
-- ============================================================================

with equipo (email, cargo) as (
  values
    ('hectorbermudez@4housing.com.ar', 'miembro'),
    ('victorialopez@4housing.com.ar',  'miembro'),
    ('pablospinetto@4housing.com.ar',  'miembro')
    -- ,('nicolastovo@gmail.com',       'miembro')  -- ← descomentar cuando su cuenta exista
)
insert into public.perfiles_sector (perfil_id, sector, cargo)
select p.id, 'labocomercial'::public.sector_portal, e.cargo
  from equipo e
  join public.perfiles p on p.email = e.email
on conflict (perfil_id, sector) do update
   set cargo = excluded.cargo;

-- Verificación
with equipo (email) as (
  values
    ('hectorbermudez@4housing.com.ar'),
    ('victorialopez@4housing.com.ar'),
    ('pablospinetto@4housing.com.ar'),
    ('nicolastovo@gmail.com')
)
select e.email,
       case
         when p.id is null then '✗ sin cuenta en el portal todavía'
         when ps.perfil_id is null then '⚠ sin sector labo (¿línea comentada?)'
         else '✓ sector labocomercial (' || ps.cargo || ')'
       end as estado
  from equipo e
  left join public.perfiles p on p.email = e.email
  left join public.perfiles_sector ps
         on ps.perfil_id = p.id and ps.sector = 'labocomercial'
 order by e.email;
