# Funciones de la web en iOS

Referencia: `control-gastos` main `3694cf6`. Los cambios son locales, sin despliegue.

| Función | Acceso en iOS |
| --- | --- |
| Etiquetas de gastos, búsqueda con `#` y filtro manual/correo | Gastos (buscador de la barra superior, chips de etiquetas y Filtros); Nuevo gasto / Editar |
| Etiquetas en movimientos de presupuesto | Plan → mes → desplegar categoría → agregar/editar gasto |
| Compra en el exterior y desglose ISD/IVA/porcentaje propio | Formularios de gastos, recurrentes, suscripciones y aceptación de correo |
| Conservación de etiquetas e impuestos sin conexión | Cola local de gastos, incluida edición y recuperación del caché anterior |
| Recurrentes semanales, mensuales y anuales; días 29–31 | «+» → Recurrente; Gastos → Recurrentes → desplegar → Editar |
| Fecha de fin y estado activo | Editor de recurrentes, incluidas suscripciones existentes |
| Pausar/reanudar y omitir próximo cobro | Gastos → Recurrentes → desplegar (interruptor Activo y «Saltar»); saltar pide confirmación |
| Historial de precios y costo anual | Recurrentes |
| Revisión de importación de Yahoo | Bandeja de la barra superior → movimientos del correo; aviso en Resumen |
| Nuevos, duplicados, devoluciones, alias, tu parte e impuestos | Revisar movimiento de correo; las mutaciones esperan confirmación del servidor |
| Proyecciones, mes anterior, categorías, modelos y validación histórica | Análisis → Proyección |
| Compromisos y disponible diario | Resumen → Ver detalle del mes → Disponible del mes |
| Avisos al cruzar 80% o superar el presupuesto de categoría | Tras guardar/editar gastos o aceptar movimientos de correo; aviso dentro de la app |
| Registro con confirmación de correo | Login → Crear cuenta |
| Conexiones ChatGPT y revocación de sesiones | Cuenta (avatar de la barra superior) → Conexiones MCP y sesiones |

## Backend y activación

Los flujos de gastos, correo, recurrentes y proyección usan los endpoints existentes
con autenticación Bearer. Se lee `/api/dashboard/recurring-plan` para conservar
`proxima_fecha`, incluidas omisiones, en lugar de adivinar la agenda del servidor.

La administración nativa de conexiones necesita desplegar estos cambios locales
adicionales en `/Users/nicolasmoina/Desktop/control-gastos`:

- `src/app/api/mobile/connections/route.ts`
- `src/lib/mobile-connections.ts`
- `tests/mobile-connections.test.cjs`

El endpoint valida la identidad Bearer con el middleware existente. Las consultas
y revocaciones de grants filtran por propietario y clientes ChatGPT permitidos;
las revocaciones de sesiones respetan `AUTH_SESSION_REGISTRY_ENABLED`. No admite
una sesión de navegador como sustituto de la credencial móvil.

Se mantienen los requisitos del backend web: migraciones de etiquetas, recurrentes,
historial/omisiones, correo y detalle de impuestos; configuración privada de MCP y
registro de sesiones para sus operaciones respectivas. No se aplicó SQL ni se
modificó configuración de producción. Correo solo está disponible para las cuentas
habilitadas por el servidor. Un error de configuración se muestra en la pantalla.

Las proyecciones y compromisos se calculan en el servidor. Los gastos locales aún
pendientes de sincronizar no están incluidos y la app lo indica. El cálculo de
presupuesto es una estimación de disponibilidad, no un saldo bancario.

## Verificación

El esquema compartido incluye el target de pruebas unitarias y usa `Zenlor.app`
como host (el nombre anterior impedía ejecutar pruebas).

```sh
xcodebuild -project gastosapp.xcodeproj -scheme gastosapp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  CODE_SIGNING_ALLOWED=NO -only-testing:gastosappTests test
```

Las pruebas cubren impuestos y redondeo, normalización/límites de etiquetas,
caché antiguo, borrado explícito de impuestos, edición/restauración de borradores
sin conexión, agenda anual, fin de regla, día 31 y umbrales. El fixture de proyección
se generó con `buildExpenseForecast` de la web, con fecha fija y datos sintéticos.

En el repositorio web:

```sh
node --test tests/mobile-connections.test.cjs
npm run typecheck
```

No se realizaron operaciones con credenciales o datos de una cuenta real. Queda
por validar el recorrido de extremo a extremo contra el backend desplegado,
especialmente correo y revocaciones, y revisar las pantallas en un dispositivo.

## Diseño de Correo

La bandeja usa el sistema de diseño de Gastos: contador de pendientes, filtros
con chips, búsqueda integrada y filas completas para abrir una revisión. Los
contadores se conservan durante las recargas. La búsqueda se aplica al escribir
con una pausa breve, y vuelve a la primera página al cambiar la consulta.

En duplicados, se elige entre vincular un gasto registrado y guardar otro gasto.
Las devoluciones permiten seleccionar el gasto original antes de confirmar el
descuento. El botón principal permanece al pie del editor; campos, impuestos y
alias comparten los componentes y colores de la app. Se puede descartar desde
el editor o manteniendo pulsada una fila, siempre con confirmación.

Se revisaron capturas sintéticas en modo claro, oscuro y con texto de accesibilidad.

### Alias de transferencias

En una transferencia enviada, el editor muestra Crear alias / Editar alias antes
de Tu gasto, con un campo y botón Guardar alias visibles. El alias se guarda con
PUT y se aplica a los pendientes del mismo destinatario; no consume el movimiento
ni crea un gasto. Guardar como solo modifica la razón de ese gasto. Si no se ha
editado la razón, adopta el alias guardado. Vaciar el campo permite Quitar alias y
recupera la descripción original. Las compras con tarjeta y devoluciones no
admiten alias de destinatario en el backend actual.

## Diseño de Proyecciones

El cierre estimado encabeza la pantalla con la misma superficie de marca de
Inicio y Presupuestos. Se separan gastos registrados, recurrentes pendientes y
gasto variable esperado. El rango describe desviaciones históricas, sin tratarlo
como intervalo de confianza. El gráfico permite seleccionar un día y distingue
las series también con trazos diferentes.

La referencia diaria compara con el mes anterior, no con el presupuesto. Si el
mínimo comprometido ya alcanza ese cierre, se explica en texto en vez de mostrar
un importe diario negativo. Categorías y próximos pagos tienen expansión para
listas largas. Los modelos, errores y validación quedan en Cómo se calcula.
Al actualizar se conserva la última proyección; la fecha de los datos permanece
visible y un fallo permite reintentar. Los importes se siguen calculando en el
servidor.

Se revisaron capturas con datos sintéticos en modo claro, oscuro, texto de
accesibilidad y sin historial suficiente. La suite de 21 pruebas pasó.

## Inicio simplificado

Inicio muestra el disponible diario, gastado/presupuesto, Registrar gasto, un
próximo pago si existe y tres movimientos recientes. Más conserva Crear
recurrente y Crear presupuesto. Ver detalle del mes abre gráficos, compromisos,
próximos cobros, categorías, meta de ahorro y consejos; desde ahí se mantienen la
proyección y el detalle de gastos por categoría. Se retiraron los iconos de
campana y menú que no tenían acción y la proyección lineal duplicada del hero.
Los avisos de presupuesto excedido y de reserva de ahorro se mantienen en el
resumen. Se revisaron componentes con datos sintéticos en claro, oscuro y texto
de accesibilidad; la suite de 21 pruebas pasó.
