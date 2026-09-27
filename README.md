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

La distancia se estima con Haversine y una velocidad urbana configurable. Esta versión permite validar la lógica sin exponer información de clientes. Antes de un uso real se debe reemplazar la matriz estimada por tiempos viales de OSRM, aplicar autenticación y cifrar la información.
