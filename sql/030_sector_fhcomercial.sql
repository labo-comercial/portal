-- ============================================================================
-- Portal 4housing — 030 · Sector fhcomercial para el equipo actual
-- ============================================================================
-- Correr DESPUÉS de revisar la consulta 5 del diagnóstico (020): todos los
-- usuarios que existen hoy en este proyecto son gente del CRM comercial
-- (equipo comercial + cobranzas), porque el proyecto solo servía esa app.
--
-- Si en esa lista apareció alguien que ya no trabaja o una cuenta de prueba,
-- NO corras la parte B tal cual: avisá y la ajustamos con un WHERE.
-- ============================================================================

-- A · Asignar sector fhcomercial (cargo 'miembro') a todos los perfiles
--     existentes. Idempotente: si ya tienen el sector, no hace nada.
--     Los cargos finos (responsable / lectura / cobranzas) se ajustan después.
insert into public.perfiles_sector (perfil_id, sector, cargo)
select id, 'fhcomercial', 'miembro'
  from public.perfiles
on conflict (perfil_id, sector) do nothing;

-- B · Activar esos perfiles para que puedan entrar al portal.
--     (Hoy "activo" solo afecta al portal y a las funciones tiene_sector();
--      la app comercial actual no lo mira — su acceso cambia recién con el
--      endurecimiento 040.)
update public.perfiles set activo = true;

-- C · Verificación: cómo quedó cada usuario
select p.email, p.nombre, p.activo, p.es_direccion, ps.sector, ps.cargo
  from public.perfiles p
  left join public.perfiles_sector ps on ps.perfil_id = p.id
 order by p.email, ps.sector;
