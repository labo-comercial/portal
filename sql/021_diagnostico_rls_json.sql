-- ============================================================================
-- Portal 4housing — 021 · Diagnóstico RLS en una sola consulta (SOLO LECTURA)
-- ============================================================================
-- Igual que 020 pero devuelve TODO en una única celda JSON, porque el SQL
-- Editor de Supabase solo muestra el resultado de la última consulta.
-- Correr, hacer clic en la celda del resultado, copiar y pegar en el chat.
-- ============================================================================

select jsonb_pretty(jsonb_build_object(

  'rls_tablas', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'tabla', c.relname,
             'rls_activado', c.relrowsecurity
           ) order by c.relname), '[]'::jsonb)
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind = 'r'
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

  'grants', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'tabla', g.table_name,
             'rol', g.grantee,
             'privilegios', g.privs
           ) order by g.table_name, g.grantee), '[]'::jsonb)
      from (select table_name, grantee,
                   string_agg(privilege_type, ',') as privs
              from information_schema.role_table_grants
             where table_schema = 'public'
               and grantee in ('anon', 'authenticated')
             group by table_name, grantee) g
  ),

  'funciones', (
    select coalesce(jsonb_agg(jsonb_build_object(
             'funcion', p.proname,
             'security_definer', p.prosecdef,
             'args', pg_get_function_identity_arguments(p.oid),
             'acl', p.proacl::text
           ) order by p.proname), '[]'::jsonb)
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
  )

)) as diagnostico;
