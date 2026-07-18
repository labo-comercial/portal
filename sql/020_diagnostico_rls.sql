-- ============================================================================
-- Portal 4housing — 020 · Diagnóstico RLS del proyecto (SOLO LECTURA)
-- ============================================================================
-- Correr en el SQL Editor de wcpkpwxhqdcdljfwzcmy y pegar los resultados de
-- las 5 consultas de vuelta en el chat. No modifica absolutamente nada:
-- son consultas a catálogos del sistema.
--
-- Objetivo: conocer el estado real de RLS/políticas/permisos de las tablas
-- del CRM antes de escribir la migración de endurecimiento (040). Sin esto
-- sería adivinar, y adivinar sobre producción no.
-- ============================================================================

-- 1 · Qué tablas existen en public y cuáles tienen RLS activado
select c.relname  as tabla,
       c.relrowsecurity  as rls_activado,
       c.relforcerowsecurity as rls_forzado
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public'
   and c.relkind = 'r'
 order by c.relname;

-- 2 · Todas las políticas RLS existentes (rol, comando, condición)
select tablename  as tabla,
       policyname as politica,
       roles,
       cmd,
       qual       as condicion_using,
       with_check as condicion_check
  from pg_policies
 where schemaname = 'public'
 order by tablename, policyname;

-- 3 · Permisos de tabla (grants) para anon y authenticated
select grantee, table_name as tabla, string_agg(privilege_type, ', ') as privilegios
  from information_schema.role_table_grants
 where table_schema = 'public'
   and grantee in ('anon', 'authenticated')
 group by grantee, table_name
 order by table_name, grantee;

-- 4 · Funciones en public (para ver next_seq / next_seq_un / fn_audit y
--     si son SECURITY DEFINER) y sus permisos de ejecución
select p.proname  as funcion,
       p.prosecdef as security_definer,
       pg_get_function_identity_arguments(p.oid) as argumentos,
       p.proacl   as permisos
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
 order by p.proname;

-- 5 · Usuarios actuales del proyecto (perfiles creados por el backfill)
select email, nombre, activo, es_direccion, creado_en
  from public.perfiles
 order by email;
