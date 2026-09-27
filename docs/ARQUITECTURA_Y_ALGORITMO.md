# Arquitectura y algoritmo

## Flujo completo

1. La API carga las hojas `Clientes` y `Agencias` del archivo Excel.
2. Se validan identificador, coordenadas, agencia, horario y duración.
3. Se recalcula el puntaje para evitar depender de una fórmula no evaluada fuera de Excel.
4. Se asigna P1 (70 o más), P2 (50 a 69), P3 (30 a 49) o P4 (menos de 30).
5. Se filtran clientes de la agencia seleccionada y se limita la carga diaria sin desplazar una P1 por una prioridad menor.
6. Cuando trabajan varios asesores, K-means++ agrupa las ubicaciones después de priorizar. Cada grupo corresponde a una zona de trabajo.
7. Dentro de cada grupo se ordena de manera lexicográfica por prioridad, puntaje, cierre de ventana y costo de traslado.
8. El planificador inserta una visita solo si puede llegar, esperar cuando corresponda, atenderla y terminar antes de su ventana y del final de la jornada.
9. La API devuelve orden, llegada, salida, traslado, omitidos y distancia estimada.
10. Flutter presenta la agenda y diferencia visitas comerciales y de cobranza.

## Por qué VRPTW y no TSP

El TSP minimiza distancia para una sola secuencia, pero no representa ventanas horarias, duración de atención, prioridades ni visitas que pueden quedar fuera de la jornada. RUTECH conserva el TSP anterior como referencia visual y usa un planificador VRPTW prioritario para el nuevo escenario.

## Implementación del optimizador

El backend usa OR-Tools con `PATH_CHEAPEST_ARC` para construir la solución inicial y `GUIDED_LOCAL_SEARCH` para mejorarla. Cada cliente tiene una ventana, un tiempo de servicio y una penalización de omisión mucho mayor cuando es P1. Si OR-Tools no está instalado, se activa una heurística reproducible que conserva prioridad y factibilidad temporal. La siguiente etapa sustituirá la estimación Haversine por una matriz vial de OSRM sin cambiar la interfaz de la API.
