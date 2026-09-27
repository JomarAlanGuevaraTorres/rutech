# Registro de cambios

## Rama `taller-investigacion-vrptw`

Punto de partida: copia del prototipo RUTECH original, commit `3f8512c`.

Cambios realizados:

- Se incorporó la base sintética verificada de 200 clientes y cinco agencias.
- Se programaron en Python las reglas separadas para gestión comercial y cobranza.
- Se añadió selección estricta P1, P2, P3 y P4 antes de construir rutas.
- Se incorporó K-means++ para repartir zonas cuando hay más de un asesor.
- Se implementó VRPTW con ventanas horarias, duración, jornada, penalizaciones por omisión y retorno a agencia mediante OR-Tools.
- Se añadió una heurística de respaldo para ejecutar el prototipo sin OR-Tools.
- Se creó una API FastAPI y una pantalla Flutter que consume sus resultados.
- Se adaptó la navegación principal a pantallas de celular.
- Se reemplazó la prueba Flutter obsoleta y se añadieron pruebas del planificador.

Validaciones ejecutadas:

- 200 registros cargados sin alterar el archivo fuente.
- Distribución recalculada: P1 54, P2 37, P3 47 y P4 62.
- Pruebas Python aprobadas.
- Prueba Flutter aprobada.
- API `/salud` y `/planificar` aprobada.
- APK Android de depuración construido correctamente.
# Versión móvil integrada (septiembre de 2026)

- Se unificó la aplicación con la base sintética de 200 clientes y las agencias de Piura.
- Se reemplazaron los campos del prototipo anterior por prioridad, puntaje, tipo de gestión y ventanas horarias.
- Se agregó selección de agencia, resumen P1-P4, listado filtrable y mapa de clientes.
- La ruta VRPTW ahora se muestra en el mapa con su orden, horario, distancia y retorno a la agencia.
- Se incorporó el inicio de jornada, navegación GPS y registro del resultado de cada visita.
- Se reemplazaron los segmentos rectos por una matriz de conducción y una polilínea vial de OSRM/OpenStreetMap.

