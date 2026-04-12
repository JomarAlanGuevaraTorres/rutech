import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';
import '../database/db_helper.dart';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class EjecutarRutaScreen extends StatefulWidget {
  final List<Map<String, dynamic>> puntosRuta;
  final List<List<LatLng>> tramosPolyline;
  final List<Color> coloresTramos;

  const EjecutarRutaScreen({
    super.key,
    required this.puntosRuta,
    required this.tramosPolyline,
    required this.coloresTramos,
  });

  @override
  State<EjecutarRutaScreen> createState() => _EjecutarRutaScreenState();
}

class _EjecutarRutaScreenState extends State<EjecutarRutaScreen> {
  final LatLng _oficina = const LatLng(-5.238109, -79.451223);
  final MapController _mapController = MapController();
  LatLng? _miUbicacion;
  StreamSubscription<Position>? _posicionStream;

  int _indiceActual = 0;
  List<Map<String, dynamic>> _visitados = [];
  List<Map<String, dynamic>> _resultados = [];

  bool? _encontrado;
  bool? _interesado;
  final _notasCtrl = TextEditingController();
  final _promesaCtrl = TextEditingController();

  bool _rutaFinalizada = false;
  // ── FIX: bandera para evitar doble guardado ──
  bool _guardando = false;
  String _horaInicio = '';

  @override
  void initState() {
    super.initState();
    _horaInicio = _horaActual();
    _resultados = List.generate(
      widget.puntosRuta.length,
          (_) => {'registrado': false},
    );
    _iniciarGPS();
  }

  @override
  void dispose() {
    _posicionStream?.cancel();
    _notasCtrl.dispose();
    _promesaCtrl.dispose();
    super.dispose();
  }

  String _horaActual() {
    final t = TimeOfDay.now();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> get _puntoActual => widget.puntosRuta[_indiceActual];

  bool get _esMoroso =>
      (_puntoActual['morosidad'] as int? ?? 0) > 0 ||
          _puntoActual['tipo_punto'] == 'moroso' ||
          _puntoActual['tipo'] == 'moroso';

  bool get _esCaserio =>
      _puntoActual['tipo_punto'] == 'caserio' ||
          (_puntoActual['tipo_punto'] == 'temporal' &&
              _puntoActual['tipo'] == 'caserio');

  LatLng _coordsPunto(Map<String, dynamic> p) {
    if (p['tipo_punto'] == 'caserio' || p['tipo_punto'] == 'temporal') {
      if (p['lat_centro'] != null) return LatLng(p['lat_centro'], p['lng_centro']);
    }
    if (p['lat_casa'] != null) return LatLng(p['lat_casa'], p['lng_casa']);
    return LatLng(p['lat_negocio'], p['lng_negocio']);
  }

  double _distancia(LatLng a, LatLng b) {
    const R = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return R * 2 * math.asin(math.sqrt(x));
  }

  double _distanciaTotal() {
    if (widget.puntosRuta.isEmpty) return 0;
    double total = _distancia(_oficina, _coordsPunto(widget.puntosRuta.first));
    for (int i = 0; i < widget.puntosRuta.length - 1; i++) {
      total += _distancia(
          _coordsPunto(widget.puntosRuta[i]), _coordsPunto(widget.puntosRuta[i + 1]));
    }
    total += _distancia(_coordsPunto(widget.puntosRuta.last), _oficina);
    return total / 1000;
  }

  Future<void> _abrirNavegacion() async {
    final coords = _coordsPunto(_puntoActual);
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
          '&destination=${coords.latitude},${coords.longitude}'
          '&travelmode=driving',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _mostrarSnack('No se pudo abrir Google Maps', error: true);
    }
  }

  Future<void> _iniciarGPS() async {
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) return;
    }
    if (permiso == LocationPermission.deniedForever) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() => _miUbicacion = LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      debugPrint('GPS error: $e');
    }
    _posicionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((pos) {
      if (mounted) setState(() => _miUbicacion = LatLng(pos.latitude, pos.longitude));
    });
  }

  // ── FIX: guardar ruta — usa resultado['nombre'] si no hay cliente_id válido ──
  Future<void> _guardarRutaEnBD(List<Map<String, dynamic>> resultadosFinales) async {
    final fecha = DateTime.now().toIso8601String().substring(0, 10);
    final horaFin = _horaActual();
    final visitados = resultadosFinales.where((r) => r['registrado'] == true).length;
    final encontrados = resultadosFinales.where((r) => r['encontrado'] == true).length;
    final interesados = resultadosFinales.where((r) => r['interesado'] == true).length;

    // 1. Crear encabezado de ruta
    final rutaId = await DBHelper.insertRutaEjecutada(
      fecha: fecha,
      horaInicio: _horaInicio,
      horaFin: horaFin,
      totalPuntos: widget.puntosRuta.length,
      visitados: visitados,
      encontrados: encontrados,
      interesados: interesados,
      distanciaKm: _distanciaTotal(),
    );

    // 2. Guardar cada visita — FIX: sin nombre_cache (columna inexistente)
    for (int i = 0; i < widget.puntosRuta.length; i++) {
      final p = widget.puntosRuta[i];
      final r = resultadosFinales[i];
      if (r['registrado'] != true) continue;

      final clienteId = p['id'];
      // IDs temporales (temp_xxx, cas_xxx) no son FK válidos
      final esIdValido = clienteId != null &&
          !clienteId.toString().startsWith('temp') &&
          !clienteId.toString().startsWith('cas');

      // resultado guardado como JSON en el campo 'resultado'
      final String notasCompletas = [
        if ((r['notas'] ?? '').toString().isNotEmpty) r['notas'],
        if ((r['promesa_pago'] ?? '').toString().isNotEmpty)
          'Promesa: ${r['promesa_pago']}',
        // guardamos el nombre en notas si no hay FK válido
        if (!esIdValido) 'Punto: ${p['nombre'] ?? ''}',
      ].join(' | ');

      await DBHelper.insertVisita({
        'cliente_id': esIdValido ? clienteId : null,
        'fecha': fecha,
        'hora': r['hora'] ?? horaFin,
        'encontrado': r['encontrado'] == true ? 1 : (r['encontrado'] == false ? 0 : -1),
        'interesado': r['interesado'] == true ? 1 : (r['interesado'] == false ? 0 : -1),
        'resultado': notasCompletas,
        'lat_visita': null,
        'lng_visita': null,
        'ruta_id': rutaId,
      });
    }
    await DBHelper.sincronizarSeguimientos(rutaId);
  }

  // ── FIX: registrar último punto y mostrar resumen SIN llamar _finalizarRuta ──
  Future<void> _registrarYAvanzar() async {
    if (_guardando) return; // evita doble tap

    if (!_esCaserio) {
      if (_encontrado == null) {
        _mostrarSnack('Indica si encontraste al cliente', error: true);
        return;
      }
      if (_encontrado! && _interesado == null) {
        _mostrarSnack('Indica si el cliente se interesó', error: true);
        return;
      }
    }

    final resultado = {
      'registrado': true,
      'punto': _puntoActual,
      'nombre': _puntoActual['nombre'] ?? '',
      'encontrado': _encontrado,
      'interesado': _interesado,
      'promesa_pago': _promesaCtrl.text.trim(),
      'notas': _notasCtrl.text.trim(),
      'hora': _horaActual(),
    };

    // Actualizar el resultado del índice actual
    final nuevosResultados = List<Map<String, dynamic>>.from(_resultados);
    nuevosResultados[_indiceActual] = resultado;

    setState(() {
      _resultados = nuevosResultados;
      _visitados.add(_puntoActual);
    });

    final esUltimo = _indiceActual >= widget.puntosRuta.length - 1;

    if (esUltimo) {
      // ── FIX: guardar UNA sola vez con los resultados ya actualizados ──
      setState(() => _guardando = true);
      await _guardarRutaEnBD(nuevosResultados);
      setState(() {
        _guardando = false;
        _rutaFinalizada = true;
      });
    } else {
      _avanzarSiguiente();
    }
  }

  void _avanzarSiguiente() {
    setState(() {
      _indiceActual++;
      _encontrado = null;
      _interesado = null;
      _notasCtrl.clear();
      _promesaCtrl.clear();
    });
    final coords = _coordsPunto(widget.puntosRuta[_indiceActual]);
    _mapController.move(coords, 14);
  }

  // ── FIX: finalizar antes del último punto (ruta cortada) ──
  Future<void> _finalizarRuta() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    await _guardarRutaEnBD(_resultados);
    setState(() {
      _guardando = false;
      _rutaFinalizada = true;
    });
  }

  void _mostrarSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.prioAlta : AppColors.verde,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ══════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_rutaFinalizada) return _buildResumenFinal();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _buildTopbar(),
          _buildProgreso(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(children: [_buildMapa(), _buildFormulario()]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopbar() {
    return Container(
      color: AppColors.verde,
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _mostrarDialogoSalir(),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_puntoActual['nombre'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text(
                    'Parada ${_indiceActual + 1} de ${widget.puntosRuta.length}',
                    style:
                    const TextStyle(color: Color(0xFFA8D5B5), fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _abrirNavegacion,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.amarillo,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.navigation, color: AppColors.verdeDark, size: 14),
                  SizedBox(width: 4),
                  Text('Navegar',
                      style: TextStyle(
                          color: AppColors.verdeDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgreso() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            children: widget.puntosRuta.asMap().entries.map((e) {
              final i = e.key;
              Color color;
              if (i < _indiceActual) {
                color = AppColors.prioBaja;
              } else if (i == _indiceActual) {
                color = AppColors.amarillo;
              } else {
                color = AppColors.border;
              }
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 4,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(2)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_visitados.length} visitados',
                  style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.prioBaja,
                      fontWeight: FontWeight.w600)),
              Text(
                  '${widget.puntosRuta.length - _indiceActual - 1} pendientes',
                  style: const TextStyle(fontSize: 10, color: AppColors.text3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapa() {
    final coordsActual = _coordsPunto(_puntoActual);
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options:
            MapOptions(initialCenter: coordsActual, initialZoom: 13),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rutech.app',
              ),
              if (widget.tramosPolyline.isNotEmpty)
                PolylineLayer(
                  polylines: widget.tramosPolyline.asMap().entries.map((e) {
                    final visitado = e.key < _indiceActual;
                    return Polyline(
                      points: e.value,
                      strokeWidth: visitado ? 2 : 4,
                      color: visitado
                          ? Colors.grey.withOpacity(0.4)
                          : widget.coloresTramos[
                      e.key % widget.coloresTramos.length],
                    );
                  }).toList(),
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _oficina,
                    width: 30,
                    height: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.verdeDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.star,
                          color: AppColors.amarillo, size: 14),
                    ),
                  ),
                  ...widget.puntosRuta.asMap().entries.map((e) {
                    final i = e.key;
                    final p = e.value;
                    final esActual = i == _indiceActual;
                    final visitado = i < _indiceActual;
                    return Marker(
                      point: _coordsPunto(p),
                      width: esActual ? 42 : 28,
                      height: esActual ? 42 : 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: visitado
                              ? AppColors.prioBaja
                              : esActual
                              ? AppColors.amarillo
                              : AppColors.border,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: esActual ? 3 : 2),
                          boxShadow: esActual
                              ? [
                            BoxShadow(
                                color:
                                AppColors.amarillo.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2)
                          ]
                              : null,
                        ),
                        child: Center(
                          child: visitado
                              ? const Icon(Icons.check,
                              color: Colors.white, size: 12)
                              : Text('${i + 1}',
                              style: TextStyle(
                                  color: esActual
                                      ? AppColors.verdeDark
                                      : Colors.white,
                                  fontSize: esActual ? 13 : 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    );
                  }),
                  if (_miUbicacion != null)
                    Marker(
                      point: _miUbicacion!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF378ADD),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                                color:
                                const Color(0xFF378ADD).withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 3)
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: GestureDetector(
              onTap: () {
                if (_miUbicacion != null) {
                  _mapController.move(_miUbicacion!, 15);
                }
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.15), blurRadius: 4)
                  ],
                ),
                child: const Icon(Icons.my_location,
                    color: Color(0xFF378ADD), size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulario() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info del punto
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _esCaserio
                            ? AppColors.verdeLt
                            : _esMoroso
                            ? const Color(0xFFFFEBEE)
                            : AppColors.verdeLt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _esCaserio
                            ? 'Caserío'
                            : _esMoroso
                            ? 'Moroso'
                            : _puntoActual['tipo'] ?? 'Cliente',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _esMoroso
                                ? AppColors.prioAlta
                                : AppColors.verde),
                      ),
                    ),
                    if (_esMoroso) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('${_puntoActual['morosidad']} días mora',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.prioAlta)),
                      ),
                    ],
                  ],
                ),
                if ((_puntoActual['caserio'] ?? '').toString().isNotEmpty ||
                    (_puntoActual['direccion'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                      _puntoActual['caserio'] ??
                          _puntoActual['direccion'] ??
                          '',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.text2)),
                ],
                if (_puntoActual['tasa'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                          'Tasa: ${(_puntoActual['tasa'] as num).toStringAsFixed(1)}%',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.verde)),
                      if (_puntoActual['saldo'] != null) ...[
                        const Text(' · ',
                            style: TextStyle(color: AppColors.text3)),
                        Text(
                            'S/. ${(_puntoActual['saldo'] as num).toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.text2)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_esCaserio) _buildFormCaserio() else _buildFormCliente(),
          const SizedBox(height: 12),
          _buildBotonesAccion(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFormCaserio() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OBSERVACIONES DE LA VISITA',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text3,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          TextField(
            controller: _notasCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Anota lo que observaste en el caserío...',
              hintStyle:
              const TextStyle(fontSize: 12, color: AppColors.text3),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.verde)),
              isDense: true,
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCliente() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RESULTADO DE LA VISITA',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text3,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          const Text('¿Encontraste al cliente?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            children: [
              _botonRespuesta(
                texto: '✓ Sí, encontrado',
                seleccionado: _encontrado == true,
                color: AppColors.prioBaja,
                onTap: () => setState(() => _encontrado = true),
              ),
              const SizedBox(width: 8),
              _botonRespuesta(
                texto: '✗ No encontrado',
                seleccionado: _encontrado == false,
                color: AppColors.prioAlta,
                onTap: () => setState(() {
                  _encontrado = false;
                  _interesado = null;
                }),
              ),
            ],
          ),
          if (_encontrado == true) ...[
            const SizedBox(height: 14),
            const Text('¿Se interesó?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                _botonRespuesta(
                  texto: '✓ Sí',
                  seleccionado: _interesado == true,
                  color: AppColors.prioBaja,
                  onTap: () => setState(() => _interesado = true),
                ),
                const SizedBox(width: 8),
                _botonRespuesta(
                  texto: '✗ No',
                  seleccionado: _interesado == false,
                  color: AppColors.prioAlta,
                  onTap: () => setState(() => _interesado = false),
                ),
              ],
            ),
          ],
          if (_esMoroso && _encontrado == true) ...[
            const SizedBox(height: 14),
            const Text('Promesa de pago (fecha)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate:
                  DateTime.now().add(const Duration(days: 90)),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppColors.verde,
                        onPrimary: Colors.white,
                        onSurface: AppColors.text,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (fecha != null) {
                  setState(() {
                    _promesaCtrl.text =
                    '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: _promesaCtrl.text.isNotEmpty
                          ? AppColors.verde
                          : AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: _promesaCtrl.text.isNotEmpty
                            ? AppColors.verde
                            : AppColors.text3,
                        size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _promesaCtrl.text.isNotEmpty
                          ? _promesaCtrl.text
                          : 'Seleccionar fecha',
                      style: TextStyle(
                          fontSize: 13,
                          color: _promesaCtrl.text.isNotEmpty
                              ? AppColors.verde
                              : AppColors.text3),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text('Notas adicionales',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: _notasCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Observaciones, acuerdos, próximos pasos...',
              hintStyle:
              const TextStyle(fontSize: 12, color: AppColors.text3),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.verde)),
              isDense: true,
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonRespuesta({
    required String texto,
    required bool seleccionado,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: seleccionado ? color : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: seleccionado ? color : AppColors.border, width: 1.5),
          ),
          child: Center(
            child: Text(texto,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                    seleccionado ? Colors.white : AppColors.text2)),
          ),
        ),
      ),
    );
  }

  Widget _buildBotonesAccion() {
    final esUltimo = _indiceActual >= widget.puntosRuta.length - 1;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amarillo,
              foregroundColor: AppColors.verdeDark,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            // FIX: deshabilitar durante guardado
            onPressed: _guardando ? null : _registrarYAvanzar,
            icon: _guardando
                ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: AppColors.verdeDark, strokeWidth: 2))
                : Icon(esUltimo ? Icons.flag : Icons.arrow_forward, size: 18),
            label: Text(
              _guardando
                  ? 'Guardando...'
                  : esUltimo
                  ? 'Registrar y Finalizar Ruta'
                  : 'Registrar y ir al siguiente',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
        if (!esUltimo) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.prioAlta,
                side: const BorderSide(color: AppColors.prioAlta),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _guardando ? null : _finalizarRuta,
              icon: const Icon(Icons.stop_circle_outlined, size: 16),
              label: const Text('Finalizar ruta aquí',
                  style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ],
    );
  }

  // ── Resumen final ──
  Widget _buildResumenFinal() {
    final visitados =
        _resultados.where((r) => r['registrado'] == true).length;
    final encontrados =
        _resultados.where((r) => r['encontrado'] == true).length;
    final interesados =
        _resultados.where((r) => r['interesado'] == true).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Container(
            color: AppColors.verde,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            child: Column(
              children: [
                const Icon(Icons.check_circle,
                    color: AppColors.amarillo, size: 48),
                const SizedBox(height: 8),
                const Text('¡Ruta completada!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Hoy ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: const TextStyle(
                      color: Color(0xFFA8D5B5), fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text('✓ Ruta guardada en reportes',
                    style:
                    TextStyle(color: Color(0xFFA8D5B5), fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      _statResumen(
                          '$visitados', 'Gestionados', AppColors.verde),
                      _statResumen(
                          '$encontrados', 'Encontrados', AppColors.prioBaja),
                      _statResumen('$interesados', 'Interesados',
                          const Color(0xFF378ADD)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('DETALLE DE VISITAS',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text3,
                            letterSpacing: 1)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                      Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Column(
                      children: widget.puntosRuta.asMap().entries.map((e) {
                        final i = e.key;
                        final p = e.value;
                        final r = _resultados[i];
                        final registrado = r['registrado'] == true;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: AppColors.border, width: 0.5)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: registrado
                                    ? AppColors.prioBaja
                                    : AppColors.border,
                                child: registrado
                                    ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
                                    : Text('${i + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(p['nombre'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500)),
                                    if (registrado)
                                      Text(_resumenVisita(r),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.text2)),
                                  ],
                                ),
                              ),
                              if (registrado)
                                Text(r['hora'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.text3)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.amarillo,
                        foregroundColor: AppColors.verdeDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.home, size: 18),
                      label: const Text('Volver al inicio',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
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

  String _resumenVisita(Map<String, dynamic> r) {
    if (r['encontrado'] == false) return 'No encontrado';
    if (r['interesado'] == true) return 'Encontrado · Interesado ✓';
    if (r['interesado'] == false) return 'Encontrado · No interesado';
    if ((r['notas'] ?? '').toString().isNotEmpty) return r['notas'];
    return 'Visitado';
  }

  Widget _statResumen(String valor, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          children: [
            Text(valor,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.text3)),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoSalir() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('¿Salir de la ruta?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: const Text('Perderás el progreso de la ruta actual.',
            style: TextStyle(fontSize: 13, color: AppColors.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.text2)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.prioAlta,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }
}