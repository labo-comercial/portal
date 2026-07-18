-- ============================================================================
-- Portal 4housing — 040 · Endurecimiento RLS del CRM comercial
-- ============================================================================
-- PREREQUISITO OBLIGATORIO: haber corrido 030 y verificado que los 5 usuarios
-- tienen sector 'fhcomercial' y activo=true (consulta C de ese archivo).
-- Si se corre esto sin el 030, el equipo comercial PIERDE ACCESO a la app.
--
-- Qué hace: reemplaza, en las 17 tablas del CRM, la política permisiva
-- "cualquier authenticated" por "solo quien tiene el sector fhcomercial"
-- (o es dirección). Basado en el diagnóstico del 2026-07-18 (021): los
-- nombres de política dropeados son EXACTAMENTE los que existen hoy.
--
-- Es atómico: todo dentro de una transacción. Si una línea falla, no queda
-- nada a medias. Rollback completo disponible en 041.
--
-- NO afecta: el pipeline de mails (escribe con service role, que ignora RLS),
-- fn_audit (SECURITY DEFINER), las RPCs next_seq/next_seq_un (siguen siendo
-- ejecutables por authenticated), ni las tablas perfiles/perfiles_sector.
-- ============================================================================

begin;

-- actividades
drop policy "auth_all_actividades" on public.actividades;
create policy actividades_fhcomercial on public.actividades
  for all to authenticated
  using (public.tiene_sector('fhcomercial'))
  with check (public.tiene_sector('fhcomercial'));

-- adicionales
drop policy "adicionales_auth_all" on public.adicionales;
create policy adicionales_fhcomercial on public.adicionales
  for all to authenticated
  using (public.tiene_sector('fhcomercial'))
  with check (public.tiene_sector('fhcomercial'));

-- audit_log (solo lectura para el sector; escribe fn_audit por trigger)
drop policy "audit_log_select" on public.audit_log;
create policy audit_log_fhcomercial_select on public.audit_log
  for select to authenticated
  using (public.tiene_sector('fhcomercial'));

-- catalogo
drop policy "auth_all_catalogo" on public.catalogo;
create policy catalogo_fhcomercial on public.catalogo
  for all to authenticated
  using (public.tiene_sector('fhcomercial'))
  with check (public.tiene_sector('fhcomercial'));

-- clientes
drop policy "auth_all_clientes" on public.clientes;
create policy clientes_fhcomercial on public.clientes
  for all to authenticated
  using (public.tiene_sector('fhcomercial'))
  with check (public.tiene_sector('fhcomercial'));

-- cobranzas
drop policy "cobranzas_auth_all" on public.cobranzas;
create policy cobranzas_fhcomercial on public.cobranzas
  for all to authenticated
  using (public.tiene_sector('fhcomercial'))
  with check (public.tiene_sector('fhcomercial'));

-- contador
drop policy "auth_all_contador" on public.contador;
create policy contador_fhcomercial on public.contador
  for all to authenticated
  using (public.tiene_sector('fhcomercial'))
  with check (public.tiene_sector('fhcomercial'));

-- contadores
drop policy "auth_all_contadores" on public.contadores;
create policy contadores_fhcomercial on public.contadores
  for all to authenticated
  using (public.tiene_sector('fhcomercial'))
  with check (public.tiene_sector('fhcomercial'));

-- cotizaciones
drop policy "auth_all_cotizaciones" on public.cotizaciones;
create policy cotizaciones_fhcomercial on public.cotizaciones
  for all to authenticated
  using (public.tiene_sector('fhcomercial'))
  with check (public.tiene_sector('fhcomercial'));

-- empresas_prospecto
drop policy "auth_all_emp_prosp" on public.empresas_prospecto;
create policy empresas_prospecto_fhcomercial on public.empresas_prospecto
  for all to authenticated
  using (public.tiene_sector('fhcomercial'))
  with check (public.tiene_sector('fhcomercial'));

-- facturas
drop policy "auth_all_facturas" on public.facturas;
create policy facturas_fhcomercial on public.facturas
  for all to authenticated
  using (public.tiene_sector('fhcomercial'))
  with check (public.tiene_sector('fhcomercial'));

-- gestiones_cobranza
drop policy "gestiones_cobranza_auth_all" on public.gestiones_cobranza;
create policy gestiones_cobranza_fhcomercial on public.gestiones_cobranza
  for all to authenticated
  using (public.tiene_sector('fhcomercial'))
  with check (public.tiene_sector('fhcomercial'));

-- mails_entrantes
drop policy "auth_all_mails" on public.mails_entrantes;
create policy mails_entrantes_fhcomercial on public.mails_entrantes
  for all to authenticated
  using (public.tiene_sector('fhcomercial'))
  with check (public.tiene_sector('fhcomercial'));

-- oportunidades
drop policy "auth_all_oportunidades" on public.oportunidades;
create policy oportunidades_fhcomercial on public.oportunidades
  for all to authenticated
  using (public.tiene_sector('fhcomercial'))
  with check (public.tiene_sector('fhcomercial'));

-- pagos
drop policy "pagos_auth_all" on public.pagos;
create policy pagos_fhcomercial on public.pagos
  for all to authenticated
  using (public.tiene_sector('fhcomercial'))
  with check (public.tiene_sector('fhcomercial'));

-- pedidos
drop policy "auth_all_pedidos" on public.pedidos;
create policy pedidos_fhcomercial on public.pedidos
  for all to authenticated
  using (public.tiene_sector('fhcomercial'))
  with check (public.tiene_sector('fhcomercial'));

-- prospectos
drop policy "auth_all_prospectos" on public.prospectos;
create policy prospectos_fhcomercial on public.prospectos
  for all to authenticated
  using (public.tiene_sector('fhcomercial'))
  with check (public.tiene_sector('fhcomercial'));

commit;

-- ---------------------------------------------------------------------------
-- Verificación (correr después del commit): todas las tablas del CRM deben
-- mostrar una única política que usa tiene_sector('fhcomercial')
-- ---------------------------------------------------------------------------
select tablename, policyname, cmd, qual
  from pg_policies
 where schemaname = 'public'
 order by tablename, policyname;

-- ---------------------------------------------------------------------------
-- Prueba funcional inmediata (a mano):
--  1. Recargar la app comercial logueado → todo debe seguir funcionando igual.
--  2. En el SQL Editor NO se puede probar el caso negativo (corre como
--     postgres); el caso "usuario sin sector no ve nada" se prueba recién
--     cuando exista un usuario de otro sector (ej. al migrar diseño).
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- PENDIENTE FLAGGEADO (no incluido a propósito): la función
-- siguiente_seq(p_nombre) es SECURITY DEFINER y ejecutable con la anon key.
-- Antes de revocarle EXECUTE a anon/public hay que confirmar quién la llama
-- (¿Power Automate? ¿algún flujo viejo?). Si nadie la usa desde afuera:
--   revoke execute on function public.siguiente_seq(text) from public, anon;
-- ---------------------------------------------------------------------------
