import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/colors.dart';
import '../database/db_helper.dart';

class MapaSeleccionScreen extends StatefulWidget {
  final List<Map<String, dynamic>> puntosExistentes;
  final List<Map<String, dynamic>> caserios;

  const MapaSeleccionScreen({
    super.key,
    required this.puntosExistentes,
    required this.caserios,
  });

  @override
  State<MapaSeleccionScreen> createState() => _MapaSeleccionScreenState();
}

class _MapaSeleccionScreenState extends State<MapaSeleccionScreen> {
  final LatLng _oficina = const LatLng(-5.238109, -79.451223);
  final MapController _mapController = MapController();

  LatLng? _puntoSeleccionado;
  bool _modoSeleccion = true;

  Color _colorPrioridad(String? p) {
    switch (p) {
      case 'alta':  return AppColors.prioAlta;
      case 'media': return AppColors.prioMedia;
      default:      return AppColors.prioBaja;
    }
  }

  LatLng _coordsPunto(Map<String, dynamic> p) {
    if (p['tipo_punto'] == 'caserio') {
      return LatLng(p['lat_centro'], p['lng_centro']);
    }
    if (p['lat_casa'] != null) return LatLng(p['lat_casa'], p['lng_casa']);
    return LatLng(p['lat_negocio'], p['lng_negocio']);
  }

  void _onMapTap(TapPosition tapPos, LatLng punto) {
    setState(() => _puntoSeleccionado = punto);
    _mostrarOpcionesModal(punto);
  }

  void _mostrarOpcionesModal(LatLng punto) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _ModalOpciones(
        punto: punto,
        caserios: widget.caserios,
        onAgregarTemporal: (nombre, tipo) {
          Navigator.pop(context);
          Navigator.pop(context, {
            'accion': 'temporal',
            'nombre': nombre,
            'tipo': tipo,
            'lat': punto.latitude,
            'lng': punto.longitude,
          });
        },
        onGuardarCaserio: (nombre) async {
          await DBHelper.insertCaserio({
            'nombre': nombre,
            'lat_centro': punto.latitude,
            'lng_centro': punto.longitude,
            'notas': 'Agregado desde mapa',
          });
          if (context.mounted) {
            Navigator.pop(context);
            Navigator.pop(context, {
              'accion': 'caserio',
              'nombre': nombre,
              'lat': punto.latitude,
              'lng': punto.longitude,
            });
          }
        },
        onGuardarCliente: (nombre, dni, tipoUbicacion) async {
          final id = await DBHelper.insertClienteDesdeMap(
            nombre: nombre,
            lat: punto.latitude,
            lng: punto.longitude,
            tipoUbicacion: tipoUbicacion,
            dni: dni,
          );
          if (context.mounted) {
            Navigator.pop(context);
            Navigator.pop(context, {
              'accion': 'cliente',
              'id': id,
              'nombre': nombre,
              'lat': punto.latitude,
              'lng': punto.longitude,
              'tipoUbicacion': tipoUbicacion,
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa interactivo
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _oficina,
              initialZoom: 12,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rutech.app',
              ),

              // Caseríos sutiles
              MarkerLayer(
                markers: widget.caserios.map((c) {
                  return Marker(
                    point: LatLng(c['lat_centro'], c['lng_centro']),
                    width: 10,
                    height: 10,
                    child: GestureDetector(
                      onTap: () => _mostrarOpcionesModal(
                          LatLng(c['lat_centro'], c['lng_centro'])),
                      child: Tooltip(
                        message: c['nombre'] ?? '',
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.verde.withOpacity(0.6),
                                width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Puntos ya en la ruta
              MarkerLayer(
                markers: widget.puntosExistentes.map((p) {
                  final i = widget.puntosExistentes.indexOf(p);
                  return Marker(
                    point: _coordsPunto(p),
                    width: 32,
                    height: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        color: p['tipo_punto'] == 'caserio'
                            ? AppColors.verde
                            : _colorPrioridad(p['prioridad']),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Pin seleccionado
              if (_puntoSeleccionado != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _puntoSeleccionado!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_pin,
                        color: AppColors.prioAlta,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Topbar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 48, 12, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: AppColors.verdeDark, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.touch_app,
                              color: AppColors.verde, size: 16),
                          SizedBox(width: 8),
                          Text('Toca el mapa para marcar un punto',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.text2,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Coordenadas del punto seleccionado
          if (_puntoSeleccionado != null)
            Positioned(
              bottom: 20,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8)
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_pin,
                        color: AppColors.prioAlta, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_puntoSeleccionado!.latitude.toStringAsFixed(6)}, '
                            '${_puntoSeleccionado!.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.verde,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'monospace'),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _mostrarOpcionesModal(_puntoSeleccionado!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.amarillo,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Usar punto',
                            style: TextStyle(
                                color: AppColors.verdeDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Modal de opciones ──────────────────────────────────

class _ModalOpciones extends StatefulWidget {
  final LatLng punto;
  final List<Map<String, dynamic>> caserios;
  final Function(String nombre, String tipo) onAgregarTemporal;
  final Function(String nombre) onGuardarCaserio;
  final Function(String nombre, String dni, String tipoUbicacion)
  onGuardarCliente;

  const _ModalOpciones({
    required this.punto,
    required this.caserios,
    required this.onAgregarTemporal,
    required this.onGuardarCaserio,
    required this.onGuardarCliente,
  });

  @override
  State<_ModalOpciones> createState() => _ModalOpcionesState();
}

class _ModalOpcionesState extends State<_ModalOpciones> {
  // 0 = opciones, 1 = temporal, 2 = caserío, 3 = cliente
  int _vista = 0;

  final _nombreCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  String _tipoUbicacion = 'casa';
  String _tipoTemporal = 'cliente'; // cliente / caserio / moroso

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dniCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),

            // Coordenadas
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_pin,
                      color: AppColors.verde, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.punto.latitude.toStringAsFixed(6)}, '
                        '${widget.punto.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.verde,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_vista == 0) _buildOpciones(),
            if (_vista == 1) _buildFormTemporal(),
            if (_vista == 2) _buildFormCaserio(),
            if (_vista == 3) _buildFormCliente(),
          ],
        ),
      ),
    );
  }

  // ── Pantalla de opciones ──
  Widget _buildOpciones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('¿Qué quieres hacer con este punto?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),

        _opcionBoton(
          icono: Icons.route,
          color: AppColors.amarillo,
          colorIcono: AppColors.verdeDark,
          titulo: 'Agregar a la ruta de hoy',
          subtitulo: 'Punto temporal, solo para esta ruta',
          onTap: () => setState(() => _vista = 1),
        ),
        const SizedBox(height: 10),
        _opcionBoton(
          icono: Icons.location_city,
          color: AppColors.verdeLt,
          colorIcono: AppColors.verde,
          titulo: 'Guardar como caserío',
          subtitulo: 'Queda guardado para siempre en el mapa',
          onTap: () => setState(() => _vista = 2),
        ),
        const SizedBox(height: 10),
        _opcionBoton(
          icono: Icons.person_add,
          color: const Color(0xFFE3F2FD),
          colorIcono: const Color(0xFF1565C0),
          titulo: 'Guardar como cliente',
          subtitulo: 'Registra un cliente o prospecto en esta ubicación',
          onTap: () => setState(() => _vista = 3),
        ),
      ],
    );
  }

  Widget _opcionBoton({
    required IconData icono,
    required Color color,
    required Color colorIcono,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icono, color: colorIcono, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorIcono)),
                  Text(subtitulo,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.text2)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorIcono, size: 20),
          ],
        ),
      ),
    );
  }


//  _buildFormTemporal completo:
  Widget _buildFormTemporal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _encabezadoForm('Agregar a ruta de hoy', Icons.route),
        const SizedBox(height: 12),

        // Nombre del punto
        _campo('Nombre del punto', _nombreCtrl,
            hint: 'Ej. Casa de Juan, Finca Los Pinos...'),
        const SizedBox(height: 12),

        // Tipo de punto
        const Text('¿Qué tipo de punto es?',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.text2)),
        const SizedBox(height: 8),
        Row(
          children: [
            _chipTipo('cliente', 'Cliente', Icons.person),
            const SizedBox(width: 8),
            _chipTipo('caserio', 'Caserío', Icons.location_city),
            const SizedBox(width: 8),
            _chipTipo('moroso', 'Moroso', Icons.warning_amber_rounded),
          ],
        ),
        const SizedBox(height: 6),

        // Descripción del tipo seleccionado
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _tipoTemporal == 'cliente'
                    ? Icons.info_outline
                    : _tipoTemporal == 'caserio'
                    ? Icons.info_outline
                    : Icons.info_outline,
                color: AppColors.text3,
                size: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _tipoTemporal == 'cliente'
                      ? 'Se registrará si fue encontrado y si se interesó'
                      : _tipoTemporal == 'caserio'
                      ? 'Solo se registrará un comentario de la visita'
                      : 'Se registrará si fue encontrado y su promesa de pago',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.text2),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        _botonesForm(
          onConfirmar: () {
            if (_nombreCtrl.text.trim().isEmpty) return;
            widget.onAgregarTemporal(
              _nombreCtrl.text.trim(),
              _tipoTemporal,
            );
          },
          labelConfirmar: 'Agregar a la ruta',
          colorConfirmar: AppColors.amarillo,
          colorTexto: AppColors.verdeDark,
        ),
      ],
    );
  }

  Widget _chipTipo(String valor, String etiqueta, IconData icono) {
    final sel = _tipoTemporal == valor;
    final color = valor == 'cliente'
        ? const Color(0xFF378ADD)
        : valor == 'caserio'
        ? AppColors.verde
        : AppColors.prioAlta;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tipoTemporal = valor),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? color : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: sel ? color : AppColors.border, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icono,
                  color: sel ? Colors.white : color, size: 18),
              const SizedBox(height: 2),
              Text(etiqueta,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : color)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Formulario caserío ──
  Widget _buildFormCaserio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _encabezadoForm('Guardar como caserío', Icons.location_city),
        const SizedBox(height: 12),
        _campo('Nombre del caserío', _nombreCtrl,
            hint: 'Ej. El Progreso, Loma Verde...'),
        const SizedBox(height: 14),
        _botonesForm(
          onConfirmar: () {
            if (_nombreCtrl.text.trim().isEmpty) return;
            widget.onGuardarCaserio(_nombreCtrl.text.trim());
          },
          labelConfirmar: 'Guardar caserío',
          colorConfirmar: AppColors.verde,
          colorTexto: Colors.white,
        ),
      ],
    );
  }

  // ── Formulario cliente ──
  Widget _buildFormCliente() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _encabezadoForm('Guardar como cliente', Icons.person_add),
        const SizedBox(height: 12),
        _campo('Nombre completo', _nombreCtrl,
            hint: 'Nombre del cliente o prospecto'),
        const SizedBox(height: 8),
        _campo('DNI (opcional)', _dniCtrl,
            hint: '12345678', teclado: TextInputType.number),
        const SizedBox(height: 10),
        const Text('Tipo de ubicación',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.text2)),
        const SizedBox(height: 6),
        Row(
          children: [
            _radioTipo('casa', 'Casa'),
            const SizedBox(width: 8),
            _radioTipo('negocio', 'Negocio'),
            const SizedBox(width: 8),
            _radioTipo('casa y negocio', 'Ambos'),
          ],
        ),
        const SizedBox(height: 14),
        _botonesForm(
          onConfirmar: () {
            if (_nombreCtrl.text.trim().isEmpty) return;
            widget.onGuardarCliente(
              _nombreCtrl.text.trim(),
              _dniCtrl.text.trim(),
              _tipoUbicacion,
            );
          },
          labelConfirmar: 'Guardar cliente',
          colorConfirmar: const Color(0xFF1565C0),
          colorTexto: Colors.white,
        ),
      ],
    );
  }

  Widget _encabezadoForm(String titulo, IconData icono) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _vista = 0;
            _nombreCtrl.clear();
            _dniCtrl.clear();
          }),
          child: const Icon(Icons.arrow_back,
              color: AppColors.text2, size: 18),
        ),
        const SizedBox(width: 10),
        Icon(icono, color: AppColors.verde, size: 18),
        const SizedBox(width: 8),
        Text(titulo,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _campo(String label, TextEditingController ctrl,
      {String hint = '',
        TextInputType teclado = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.text2)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: teclado,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
            const TextStyle(fontSize: 12, color: AppColors.text3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.verde),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _radioTipo(String valor, String etiqueta) {
    final sel = _tipoUbicacion == valor;
    return GestureDetector(
      onTap: () => setState(() => _tipoUbicacion = valor),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.verde : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: sel ? AppColors.verde : AppColors.border,
              width: 1.5),
        ),
        child: Text(etiqueta,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: sel ? Colors.white : AppColors.text2)),
      ),
    );
  }

  Widget _botonesForm({
    required VoidCallback onConfirmar,
    required String labelConfirmar,
    required Color colorConfirmar,
    required Color colorTexto,
  }) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorConfirmar,
              foregroundColor: colorTexto,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onConfirmar,
            child: Text(labelConfirmar,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text2,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ),
      ],
    );
  }
}