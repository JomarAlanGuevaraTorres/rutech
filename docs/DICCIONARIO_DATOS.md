# Diccionario de datos resumido

La fuente de trabajo es sintética y contiene 200 registros (100 comerciales y 100 de cobranza) distribuidos alrededor de cinco agencias referenciales de Piura.

Campos principales:

- `ID_cliente`, `Nombre_cliente`: identificadores ficticios.
- `Tipo_gestion`: COMERCIAL o COBRANZA.
- `Latitud`, `Longitud`, `Codigo_agencia`: ubicación y agencia de origen.
- `Fecha_gestion`, `Hora_desde`, `Hora_hasta`, `Duracion_visita_min`: restricciones temporales.
- `Monto_referencial_S`, `Nivel_interes`, `Probabilidad_cierre_pct`: señales comerciales.
- `Dias_mora`, `Saldo_pendiente_S`, `Estado_compromiso`, `Intentos_sin_respuesta`: señales de cobranza.
- `Puntaje_prioridad`, `Prioridad`: resultado P1 a P4 de las reglas de negocio.

La aplicación recalcula la prioridad en Python y no acepta el valor del Excel como única fuente de verdad.
