-- ============================================================================
-- Portal 4housing — 041 · ROLLBACK del endurecimiento (040)
-- ============================================================================
-- Solo si algo falla después del 040: restaura EXACTAMENTE las políticas
-- que existían antes (mismos nombres, misma condición using(true)), según
-- el diagnóstico 021 del 2026-07-18. Atómico.
-- ============================================================================

begin;

drop policy "actividades_fhcomercial" on public.actividades;
create policy "auth_all_actividades" on public.actividades
  for all to authenticated using (true) with check (true);

drop policy "adicionales_fhcomercial" on public.adicionales;
create policy "adicionales_auth_all" on public.adicionales
  for all to authenticated using (true) with check (true);

drop policy "audit_log_fhcomercial_select" on public.audit_log;
create policy "audit_log_select" on public.audit_log
  for select to authenticated using (true);

drop policy "catalogo_fhcomercial" on public.catalogo;
create policy "auth_all_catalogo" on public.catalogo
  for all to authenticated using (true) with check (true);

drop policy "clientes_fhcomercial" on public.clientes;
create policy "auth_all_clientes" on public.clientes
  for all to authenticated using (true) with check (true);

drop policy "cobranzas_fhcomercial" on public.cobranzas;
create policy "cobranzas_auth_all" on public.cobranzas
  for all to authenticated using (true) with check (true);

drop policy "contador_fhcomercial" on public.contador;
create policy "auth_all_contador" on public.contador
  for all to authenticated using (true) with check (true);

drop policy "contadores_fhcomercial" on public.contadores;
create policy "auth_all_contadores" on public.contadores
  for all to authenticated using (true) with check (true);

drop policy "cotizaciones_fhcomercial" on public.cotizaciones;
create policy "auth_all_cotizaciones" on public.cotizaciones
  for all to authenticated using (true) with check (true);

drop policy "empresas_prospecto_fhcomercial" on public.empresas_prospecto;
create policy "auth_all_emp_prosp" on public.empresas_prospecto
  for all to authenticated using (true) with check (true);

drop policy "facturas_fhcomercial" on public.facturas;
create policy "auth_all_facturas" on public.facturas
  for all to authenticated using (true) with check (true);

drop policy "gestiones_cobranza_fhcomercial" on public.gestiones_cobranza;
create policy "gestiones_cobranza_auth_all" on public.gestiones_cobranza
  for all to authenticated using (true) with check (true);

drop policy "mails_entrantes_fhcomercial" on public.mails_entrantes;
create policy "auth_all_mails" on public.mails_entrantes
  for all to authenticated using (true) with check (true);

drop policy "oportunidades_fhcomercial" on public.oportunidades;
create policy "auth_all_oportunidades" on public.oportunidades
  for all to authenticated using (true) with check (true);

drop policy "pagos_fhcomercial" on public.pagos;
create policy "pagos_auth_all" on public.pagos
  for all to authenticated using (true) with check (true);

drop policy "pedidos_fhcomercial" on public.pedidos;
create policy "auth_all_pedidos" on public.pedidos
  for all to authenticated using (true) with check (true);

drop policy "prospectos_fhcomercial" on public.prospectos;
create policy "auth_all_prospectos" on public.prospectos
  for all to authenticated using (true) with check (true);

commit;
