-- ============================================================================
-- Migración Diseño — 100 · Radiografía del proyecto VIEJO (SOLO LECTURA)
-- ============================================================================
-- ⚠ Correr en el SQL Editor del proyecto de DISEÑO (nfgjxvatfihjrtktivhq),
--   NO en el del portal. Devuelve una celda JSON: copiarla y pegarla en el
--   chat. No modifica nada.
--
-- Con esto se escriben las CREATE TABLE diseno_* exactas (tipos, defaults,
-- FKs, vista, triggers) y se dimensiona la copia de datos.
-- ============================================================================

select jsonb_pretty(jsonb_build_object(

  'columnas', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'tabla', table_name,
             'columna', column_name,
             'orden', ordinal_position,
             'tipo', data_type,
             'tipo_udt', udt_name,
             'nullable', is_nullable,
             'default', column_default
           ) order by table_name, ordinal_position), '[]'::jsonb)
      from information_schema.columns
     where table_schema = 'public'
  ),

  'constraints', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'tabla', conrelid::regclass::text,
             'nombre', conname,
             'definicion', pg_get_constraintdef(oid)
           ) order by conrelid::regclass::text, conname), '[]'::jsonb)
      from pg_constraint
     where connamespace = 'public'::regnamespace
       and contype in ('p', 'f', 'u', 'c')
  ),

  'indices', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'tabla', tablename,
             'nombre', indexname,
             'definicion', indexdef
           ) order by tablename, indexname), '[]'::jsonb)
      from pg_indexes
     where schemaname = 'public'
  ),

  'vistas', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'vista', viewname,
             'definicion', definition
           ) order by viewname), '[]'::jsonb)
      from pg_views
     where schemaname = 'public'
  ),

  'triggers', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'tabla', t.tgrelid::regclass::text,
             'nombre', t.tgname,
             'definicion', pg_get_triggerdef(t.oid)
           ) order by t.tgrelid::regclass::text, t.tgname), '[]'::jsonb)
      from pg_trigger t
      join pg_class c on c.oid = t.tgrelid
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and not t.tgisinternal
  ),

  'funciones', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'funcion', p.proname,
             'security_definer', p.prosecdef,
             'args', pg_get_function_identity_arguments(p.oid),
             'definicion', pg_get_functiondef(p.oid)
           ) order by p.proname), '[]'::jsonb)
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
  ),

  'politicas', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'tabla', tablename,
             'politica', policyname,
             'roles', roles::text,
             'cmd', cmd,
             'using', qual,
             'check', with_check
           ) order by tablename, policyname), '[]'::jsonb)
      from pg_policies
     where schemaname = 'public'
  ),

  'tamanos', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'tabla', c.relname,
             'filas_aprox', c.reltuples::bigint,
             'bytes_total', pg_total_relation_size(c.oid)
           ) order by c.relname), '[]'::jsonb)
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'r'
  ),

  'usuarios_auth', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'email', email,
             'creado', created_at,
             'ultimo_login', last_sign_in_at
           ) order by email), '[]'::jsonb)
      from auth.users
  )

)) as radiografia_diseno;
