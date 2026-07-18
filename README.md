# Portal 4housing — Etapa 1 (consolidación)

Portal único con login Microsoft y permisos por sector/cargo. **Base elegida
(2026-07-18): el proyecto Supabase de 4housing comercial** (`wcpkpwxhqdcdljfwzcmy`),
por límite de proyectos del plan free. Es un proyecto EN PRODUCCIÓN: todo lo que
se agrega acá es aditivo y respeta las reglas del CLAUDE.md de 4housing-comercial
(SQL siempre manual, primero SQL después HTML, RLS solo `authenticated`).

Las otras 3 apps (LABO, diseño, planificación) siguen en sus proyectos originales
hasta que cada módulo se migre adentro de este. A medida que cada migración se
valida, su proyecto viejo se pausa — lo que además libera cupo free.

## Contenido

| Archivo | Qué es |
|---|---|
| `index.html` | Shell del portal: login Microsoft + grilla de módulos según permisos |
| `sql/000_portal_acceso.sql` | Fundación de acceso: enum de sectores, `perfiles`, `perfiles_sector`, helpers RLS, backfill de usuarios existentes |
| `sql/010_plantilla_rls_modulo.sql` | Plantilla (comentada) de políticas RLS a aplicar al migrar cada módulo |

## Convención de nombres (decidida 2026-07-18)

Prefijos de tabla por sector — mismos strings que el enum `sector_portal`:

`fhcomercial_` · `labocomercial_` · `diseno_` (sin ñ) · `planificacion_` · `compras_` · `logistica_`

- `core_` queda **reservado** para las tablas maestras compartidas de Etapa 2
  (`core_clientes`, `core_proyectos`). No crear todavía.
- `perfiles` / `perfiles_sector` van **sin prefijo**: son del portal, no de un sector.
- Colisión conocida en planificación (el orden de los renames importa):
  1. `planificacion` → `planificacion_bloques`
  2. `planificacion_personal` → `planificacion_bloques_personal`
  3. `personal` → `planificacion_personal`

Inventario completo de tablas de las 4 apps:
https://claude.ai/code/artifact/d1097aa5-b357-4a25-9689-bc4e1bc1000c

## Puesta en marcha

### 1 · Correr el SQL de acceso (manual, SQL Editor)

Supabase → proyecto `wcpkpwxhqdcdljfwzcmy` → SQL Editor → pegar y correr
`sql/000_portal_acceso.sql` completo. Es aditivo: no toca ninguna tabla ni
política existente del CRM. Incluye el backfill: crea perfiles (inactivos)
para el equipo comercial que ya existe en `auth.users`.

### 2 · Bootstrap de dirección

Como tu usuario ya existe en `auth.users` (usás la app comercial), el backfill
ya te creó el perfil. En el SQL Editor:

```sql
update public.perfiles
   set es_direccion = true, activo = true
 where email = 'pablospinetto@4housing.com.ar';
```

### 3 · Habilitar la URL del portal en Auth

El provider Azure **ya está configurado** en este proyecto (la app comercial
loguea con Microsoft desde siempre) — no hay que tocar Azure ni crear secrets.
Solo falta permitir el redirect del portal:

Authentication → URL Configuration → **Redirect URLs** → agregar
`https://labo-comercial.github.io/portal/` (y `http://localhost:...` si se
quiere probar local). **No cambiar la Site URL existente** — la app comercial
pasa su propio `redirectTo` explícito, pero mejor no mover lo que funciona.

### 4 · Deployar el portal

`index.html` ya viene con `CONFIG` apuntando a este proyecto (la anon key es
pública por diseño; la seguridad la hace RLS). Crear el repo `portal` en la
organización `labo-comercial`, subir esta carpeta y activar GitHub Pages.
Verificar que la URL final coincida con la agregada en el paso 3.

**Bonus de esta arquitectura:** portal y app comercial comparten origen
(`labo-comercial.github.io`) y proyecto Supabase, así que **comparten sesión**:
quien loguea en el portal entra a la app comercial sin volver a loguearse,
y viceversa. Ese es el comportamiento esperado, no un bug.

## Habilitar usuarios (por ahora, desde el SQL Editor)

```sql
-- habilitar a alguien y darle un sector
update public.perfiles set activo = true where email = 'persona@4housing.com.ar';
insert into public.perfiles_sector (perfil_id, sector, cargo)
select id, 'diseno', 'miembro' from public.perfiles
 where email = 'persona@4housing.com.ar';
```

Una pantalla de administración dentro del portal es un paso posterior.

## Qué sigue (en orden — el orden importa)

1. **Portal funcionando** (pasos de arriba). Nada de esto afecta la app comercial:
   ella no lee `perfiles` y sus políticas actuales siguen intactas.
2. **Asignar sector `fhcomercial` a todos los usuarios comerciales actuales**
   (equipo comercial + cobranzas), y `activo = true`.
3. **Endurecer las tablas comerciales existentes** a `tiene_sector('fhcomercial')`
   en vez de "cualquier authenticated". ⚠ Este paso es OBLIGATORIO **antes** de
   dar de alta usuarios de otros sectores: hoy cualquier usuario autenticado del
   proyecto puede leer las tablas del CRM; cuando diseño/planificación/LABO
   compartan el auth, sin este paso verían datos comerciales. Se hace con la
   plantilla `010`, tabla por tabla, probando la app comercial después de cada una.
4. **Migrar diseño** (el más chico): crear tablas `diseno_` + RLS + importar datos
   + apuntar la app. Validar con un usuario solo-diseño. Pausar su proyecto viejo
   (antes: bajar backup).
5. **Planificación**, después **LABO** (mismo esquema). Cada proyecto viejo
   pausado libera cupo free.
6. **Renombrar las tablas comerciales a `fhcomercial_` — AL FINAL y coordinado.**
   Es el rename más delicado del plan porque hay sistemas externos escribiendo
   por nombre de tabla:
   - Power Automate + Edge Function escriben en `mails_entrantes` (pipeline de
     clasificación de mails) y el enriquecimiento externo toca `prospectos`.
   - `fn_audit()` y sus triggers registran nombres de tabla en `audit_log`.
   - RPCs `next_seq_un` / `next_seq` y la Edge Function `notificar-cobranza`.
   - Resolver antes la ambigüedad `contador` vs `contadores` (pendiente conocido
     del CLAUDE.md de 4housing-comercial).
   Se hace en una ventana coordinada: SQL de renames + deploy del HTML actualizado
   juntos, con los flujos externos re-apuntados en el mismo momento.
7. Pantalla de administración de usuarios dentro del portal.
8. Etapa 2: tablas `core_` y vínculos entre sectores. No antes.

## Reglas para no romper nada

- Todo SQL se entrega como archivo y lo corre Pablo a mano — nunca ejecución
  directa contra producción (regla del CLAUDE.md de 4housing-comercial).
- Orden de deploy: primero SQL, después HTML. Nunca al revés.
- Ningún cambio en las carpetas de las 4 apps hasta que su módulo tenga base
  nueva probada con datos importados.
- Los proyectos Supabase viejos no se apagan: backup primero, pausa después de
  validar cada migración. Un proyecto pausado >90 días ya no se restaura con un
  clic — el backup previo no es opcional.
- Cada migración de módulo se prueba con un usuario sin `es_direccion` para
  verificar que RLS aísla de verdad (tanto lo que ve como lo que NO ve).
