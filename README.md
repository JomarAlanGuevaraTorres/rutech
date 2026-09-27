# RUTECH (priorización y rutas bancarias)

Prototipo académico para organizar visitas comerciales y de cobranza en Piura. El sistema no crea una ruta por cercanía solamente: primero calcula P1, P2, P3 o P4, luego selecciona la agencia y finalmente construye una ruta que respeta ventanas horarias y duración de cada visita.

## Componentes

- `lib/`: aplicación Flutter/Dart para Android y escritorio.
- `backend/`: API Python que lee la base sintética y planifica las visitas.
- `backend/data/`: base de 200 clientes simulados. No contiene datos bancarios reales.
- `docs/`: decisiones técnicas, diccionario de datos y guía de ejecución.

## Ejecución

1. Cree un entorno Python: `python -m venv .venv`.
2. Active el entorno e instale: `pip install -r backend/requirements.txt`.
3. Inicie la API desde la raíz: `uvicorn backend.app:app --reload --host 0.0.0.0`.
4. Ejecute Flutter: `flutter run --dart-define=RUTECH_API_URL=http://10.0.2.2:8000`.

En el emulador Android, `10.0.2.2` representa la computadora. En un celular físico debe usarse la IP local del equipo que ejecuta Python.

## Alcance del prototipo

La aplicación consulta OSRM sobre datos de OpenStreetMap para calcular la matriz de tiempos en automóvil y dibujar la geometría que sigue las calles reales. Si el servicio externo no estuviera disponible, informa que está usando una estimación temporal con Haversine en vez de presentar esa aproximación como una ruta vial. Esta versión permite validar la lógica sin exponer información de clientes. Antes de un uso real se debe desplegar una instancia propia de OSRM, aplicar autenticación y cifrar la información.

## Flujo funcional móvil

1. En **Inicio**, seleccione la agencia de salida y retorno. El tablero muestra la cantidad de clientes P1, P2, P3 y P4 asignados a esa agencia.
2. Ajuste el máximo de visitas y pulse **Generar ruta priorizada**. El servidor ordena primero por prioridad y luego resuelve el VRPTW.
3. En **Clientes**, consulte la base asignada y filtre por nivel de prioridad.
4. En **Mapa**, visualice la agencia y todos sus clientes, diferenciados por color de prioridad.
5. En **Ruta**, revise el recorrido, la secuencia, distancia y ventanas horarias. Pulse **Iniciar** para atender cada parada.
6. Durante la ejecución puede abrir la navegación GPS y registrar la visita como realizada, no ubicada o reprogramada.

El APK generado queda en `build/app/outputs/flutter-apk/app-release.apk`.
