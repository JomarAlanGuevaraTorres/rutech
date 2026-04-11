import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../theme/colors.dart';
import '../database/db_helper.dart';
import 'mapa_completo_screen.dart';
import 'mapa_seleccion_screen.dart';
import 'ejecutar_ruta_screen.dart';

class RutaScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? puntosIniciales;
  const RutaScreen({super.key, this.puntosIniciales});

  @override
  State<RutaScreen> createState() => _RutaScreenState();
}

class _RutaScreenState extends State<RutaScreen> {
  final _buscarController = TextEditingController();
  final LatLng _oficina = const LatLng(-5.238109, -79.451223);

  List<Map<String, dynamic>> _resultadosClientes = [];
  List<Map<String, dynamic>> _resultadosCaserios = [];
  List<Map<String, dynamic>> _puntosRuta = [];
  List<Map<String, dynamic>> _caserios = [];

  // Ruta: lista de tramos, cada tramo con su lista de puntos y color
  List<List<LatLng>> _tramosPolyline = [];

  final List<Color> _coloresTramos = [
    const Color(0xFFE24B4A),
    const Color(0xFFEF9F27),
    const Color(0xFF378ADD),
    const Color(0xFF1D9E75),
    const Color(0xFF9B59B6),
    const Color(0xFFE67E22),
    const Color(0xFF2ECC71),
    const Color(0xFFE91E8C),
    const Color(0xFF00BCD4),
    const Color(0xFFFF5722),
    const Color(0xFF8BC34A),
    const Color(0xFFFF9800),
  ];

  bool _buscando = false;
  bool _calculando = false;
  bool _rutaCalculada = false;
  bool _mostrarCaserios = false;

  @override
  void initState() {
    super.initState();
    _cargarCaserios();
    if (widget.puntosIniciales != null &&
        widget.puntosIniciales!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        setState(() => _puntosRuta = List.from(widget.puntosIniciales!));
        await _calcularRuta();
      });
    }
  }

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  Future<void> _cargarCaserios() async {
    final data = await DBHelper.getCaserios();
    setState(() => _caserios = data);
  }

  Future<void> _buscar(String texto) async {
    if (texto.trim().isEmpty) {
      setState(() {
        _resultadosClientes = [];
        _resultadosCaserios = [];
      });
      return;
    }
    setState(() => _buscando = true);
    final clientes = await DBHelper.buscarClientesPorNombre(texto);
    final caserios = await DBHelper.buscarCaseriosPorNombre(texto);
    setState(() {
      _resultadosClientes = clientes;
      _resultadosCaserios = caserios;
      _buscando = false;
    });
  }

  Future<void> _abrirMapaSeleccion() async {
    final resultado = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapaSeleccionScreen(
          puntosExistentes: _puntosRuta,
          caserios: _caserios,
        ),
      ),
    );

    if (resultado == null) return;

    final accion = resultado['accion'];

    if (accion == 'temporal') {
      // Agregar punto temporal a la ruta
      setState(() {
        _puntosRuta.add({
          'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
          'nombre': resultado['nombre'],
          'tipo': resultado['tipo'] ?? 'cliente',      // ← tipo real
          'tipo_punto': resultado['tipo'] ?? 'cliente', // ← para el formulario
          'caserio': '',
          'prioridad': resultado['tipo'] == 'moroso' ? 'alta' : 'media',
          'morosidad': resultado['tipo'] == 'moroso' ? 1 : 0,
          'lat_casa': resultado['lat'],
          'lng_casa': resultado['lng'],
          'lat_negocio': null,
          'lng_negocio': null,
        });
        _rutaCalculada = false;
      });
      _mostrarSnack('Punto agregado a la ruta');

    } else if (accion == 'caserio') {
      // Recargar caseríos y agregar a la ruta
      await _cargarCaserios();
      setState(() {
        _puntosRuta.add({
          'id': 'cas_${DateTime.now().millisecondsSinceEpoch}',
          'nombre': resultado['nombre'],
          'lat_centro': resultado['lat'],
          'lng_centro': resultado['lng'],
          'tipo_punto': 'caserio',
        });
        _rutaCalculada = false;
      });
      _mostrarSnack('Caserío guardado y agregado a la ruta');

    } else if (accion == 'cliente') {
      // Agregar cliente recién creado a la ruta
      setState(() {
        _puntosRuta.add({
          'id': resultado['id'],
          'nombre': resultado['nombre'],
          'tipo': 'Prospecto',
          'caserio': '',
          'prioridad': 'media',
          'lat_casa': resultado['lat'],
          'lng_casa': resultado['lng'],
          'lat_negocio': null,
          'lng_negocio': null,
          'tipo_punto': 'cliente',
        });
        _rutaCalculada = false;
      });
      _mostrarSnack('Cliente guardado y agregado a la ruta');
    }
  }

  void _agregarCliente(Map<String, dynamic> cliente) {
    if (cliente['lat_casa'] == null && cliente['lat_negocio'] == null) {
      _mostrarSnack('Este cliente no tiene ubicación GPS', error: true);
      return;
    }
    if (_puntosRuta.any((p) => p['id'] == cliente['id'])) {
      _mostrarSnack('Este cliente ya está en la ruta', error: true);
      return;
    }
    setState(() {
      _puntosRuta.add({...cliente, 'tipo_punto': 'cliente'});
      _resultadosClientes = [];
      _resultadosCaserios = [];
      _buscarController.clear();
      _rutaCalculada = false;
    });
  }

  void _agregarCaserio(Map<String, dynamic> caserio) {
    if (_puntosRuta.any((p) =>
    p['tipo_punto'] == 'caserio' && p['id'] == caserio['id'])) {
      _mostrarSnack('Este caserío ya está en la ruta', error: true);
      return;
    }
    setState(() {
      _puntosRuta.add({...caserio, 'tipo_punto': 'caserio'});
      _mostrarCaserios = false;
      _rutaCalculada = false;
    });
  }

  void _eliminarPunto(int index) {
    setState(() {
      _puntosRuta.removeAt(index);
      _rutaCalculada = false;
    });
  }

  void _limpiarRuta() {
    setState(() {
      _puntosRuta = [];
      _tramosPolyline = [];
      _rutaCalculada = false;
      _buscarController.clear();
      _resultadosClientes = [];
      _resultadosCaserios = [];
    });
  }

  LatLng _coordsPunto(Map<String, dynamic> p) {
    // En _coordsPunto
    if (p['tipo_punto'] == 'temporal') {
      return LatLng(p['lat_casa'], p['lng_casa']);
    }
    if (p['tipo_punto'] == 'caserio') {
      return LatLng(p['lat_centro'], p['lng_centro']);
    }
    if (p['lat_casa'] != null) return LatLng(p['lat_casa'], p['lng_casa']);
    return LatLng(p['lat_negocio'], p['lng_negocio']);
  }

  // ── Haversine ──
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

  double _distanciaRuta(List<Map<String, dynamic>> ruta) {
    if (ruta.isEmpty) return 0;
    double total = _distancia(_oficina, _coordsPunto(ruta.first));
    for (int i = 0; i < ruta.length - 1; i++) {
      total += _distancia(_coordsPunto(ruta[i]), _coordsPunto(ruta[i + 1]));
    }
    total += _distancia(_coordsPunto(ruta.last), _oficina);
    return total;
  }

  // ── Vecino más cercano ──
  List<Map<String, dynamic>> _vecinoCercano(
      List<Map<String, dynamic>> clientes) {
    final noVisitados = List<Map<String, dynamic>>.from(clientes);
    final ruta = <Map<String, dynamic>>[];
    LatLng actual = _oficina;
    while (noVisitados.isNotEmpty) {
      double menorDist = double.infinity;
      int indice = 0;
      for (int i = 0; i < noVisitados.length; i++) {
        final d = _distancia(actual, _coordsPunto(noVisitados[i]));
        if (d < menorDist) {
          menorDist = d;
          indice = i;
        }
      }
      ruta.add(noVisitados[indice]);
      actual = _coordsPunto(noVisitados[indice]);
      noVisitados.removeAt(indice);
    }
    return ruta;
  }

  // ── 2-opt ──
  List<Map<String, dynamic>> _dosOpt(List<Map<String, dynamic>> ruta) {
    final mejor = List<Map<String, dynamic>>.from(ruta);
    bool mejoro = true;
    while (mejoro) {
      mejoro = false;
      for (int i = 0; i < mejor.length - 1; i++) {
        for (int j = i + 2; j < mejor.length; j++) {
          final a = i == 0 ? _oficina : _coordsPunto(mejor[i - 1]);
          final b = _coordsPunto(mejor[i]);
          final c = _coordsPunto(mejor[j]);
          final d = j == mejor.length - 1
              ? _oficina
              : _coordsPunto(mejor[j + 1]);
          if (_distancia(a, c) + _distancia(b, d) <
              _distancia(a, b) + _distancia(c, d) - 1.0) {
            final segmento = mejor.sublist(i, j + 1).reversed.toList();
            mejor.replaceRange(i, j + 1, segmento);
            mejoro = true;
          }
        }
      }
    }
    return mejor;
  }

  // ── Algoritmo Genético ──
  List<Map<String, dynamic>> _algoritmoGenetico(
      List<Map<String, dynamic>> clientes) {
    const poblacion = 80;
    const generaciones = 200;
    const mutacion = 0.02;
    const elitismo = 8;
    final n = clientes.length;
    final rand = math.Random();

    List<int> crearIndividuo() {
      final ind = List<int>.generate(n, (i) => i);
      ind.shuffle(rand);
      return ind;
    }

    double calcFitness(List<int> ind) {
      final ruta = ind.map((i) => clientes[i]).toList();
      return _distanciaRuta(ruta);
    }

    List<int> cruceOX(List<int> p1, List<int> p2) {
      final a = rand.nextInt(n);
      final b = rand.nextInt(n);
      final inicio = math.min(a, b);
      final fin = math.max(a, b);
      final hijo = List<int>.filled(n, -1);
      for (int i = inicio; i <= fin; i++) hijo[i] = p1[i];
      int pos = (fin + 1) % n;
      for (final gen in p2) {
        if (!hijo.contains(gen)) {
          hijo[pos] = gen;
          pos = (pos + 1) % n;
        }
      }
      return hijo;
    }

    List<int> mutar(List<int> ind) {
      final nuevo = List<int>.from(ind);
      for (int i = 0; i < n; i++) {
        if (rand.nextDouble() < mutacion) {
          final j = rand.nextInt(n);
          final tmp = nuevo[i];
          nuevo[i] = nuevo[j];
          nuevo[j] = tmp;
        }
      }
      return nuevo;
    }

    List<int> torneo(List<List<int>> pob, List<double> fits) {
      List<int>? mejor;
      double mejorFit = double.infinity;
      for (int i = 0; i < 3; i++) {
        final idx = rand.nextInt(pob.length);
        if (fits[idx] < mejorFit) {
          mejorFit = fits[idx];
          mejor = pob[idx];
        }
      }
      return mejor!;
    }

    var pob = List.generate(poblacion, (_) => crearIndividuo());
    List<int>? mejorGlobal;
    double mejorDistGlobal = double.infinity;

    for (int gen = 0; gen < generaciones; gen++) {
      final fits = pob.map(calcFitness).toList();
      final idxOrdenados = List.generate(poblacion, (i) => i)
        ..sort((a, b) => fits[a].compareTo(fits[b]));
      if (fits[idxOrdenados[0]] < mejorDistGlobal) {
        mejorDistGlobal = fits[idxOrdenados[0]];
        mejorGlobal = List.from(pob[idxOrdenados[0]]);
      }
      final elite =
      idxOrdenados.take(elitismo).map((i) => pob[i]).toList();
      final nuevaPob = <List<int>>[...elite];
      while (nuevaPob.length < poblacion) {
        final p1 = torneo(pob, fits);
        final p2 = torneo(pob, fits);
        nuevaPob.add(mutar(cruceOX(p1, p2)));
      }
      pob = nuevaPob;
    }
    return mejorGlobal!.map((i) => clientes[i]).toList();
  }

  // ── Catmull-Rom suavizado ──
  double _catmullRom(double p0, double p1, double p2, double p3, double t) {
    return 0.5 *
        ((2 * p1) +
            (-p0 + p2) * t +
            (2 * p0 - 5 * p1 + 4 * p2 - p3) * (t * t) +
            (-p0 + 3 * p1 - 3 * p2 + p3) * (t * t * t));
  }

  List<LatLng> _suavizarRuta(List<LatLng> puntos) {
    if (puntos.length < 2) return puntos;
    final resultado = <LatLng>[];
    const pasos = 12;
    for (int i = 0; i < puntos.length - 1; i++) {
      final p0 = i > 0 ? puntos[i - 1] : puntos[i];
      final p1 = puntos[i];
      final p2 = puntos[i + 1];
      final p3 = i + 2 < puntos.length ? puntos[i + 2] : puntos[i + 1];
      for (int t = 0; t < pasos; t++) {
        final tN = t / pasos;
        resultado.add(LatLng(
          _catmullRom(
              p0.latitude, p1.latitude, p2.latitude, p3.latitude, tN),
          _catmullRom(
              p0.longitude, p1.longitude, p2.longitude, p3.longitude, tN),
        ));
      }
    }
    resultado.add(puntos.last);
    return resultado;
  }

  // ── GraphHopper tramo ──
  Future<List<LatLng>> _obtenerTramoOSRM(LatLng origen, LatLng destino) async {
    const apiKey = 'c2a476bc-5b04-46dd-a4ad-393486b93a9d';
    try {
      final url = Uri.parse(
        'https://graphhopper.com/api/1/route'
            '?point=${origen.latitude},${origen.longitude}'
            '&point=${destino.latitude},${destino.longitude}'
            '&vehicle=car&locale=es&points_encoded=false&key=$apiKey',
      );
      final response =
      await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords =
        data['paths'][0]['points']['coordinates'] as List;
        return coords
            .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
            .toList();
      } else {
        debugPrint('GraphHopper error: ${response.body}');
      }
    } catch (e) {
      debugPrint('GraphHopper error: $e');
    }
    return [origen, destino];
  }

  // ── Calcular ruta: GA + 2-opt + GraphHopper por tramos ──
  Future<void> _calcularRuta() async {
    if (_puntosRuta.isEmpty) {
      _mostrarSnack('Agrega al menos un punto', error: true);
      return;
    }
    setState(() {
      _calculando = true;
      _tramosPolyline = [];
    });

    // GA + 2-opt
    final resultado = await Future(() {
      final rutaGA = _algoritmoGenetico(_puntosRuta);
      return _dosOpt(rutaGA);
    });

    // GraphHopper tramo por tramo
    final secuencia = [_oficina, ...resultado.map(_coordsPunto), _oficina];
    final List<List<LatLng>> tramosCalculados = [];

    for (int i = 0; i < secuencia.length - 1; i++) {
      List<LatLng> tramo = [];
      int intentos = 0;
      while (intentos < 3) {
        tramo = await _obtenerTramoOSRM(secuencia[i], secuencia[i + 1]);
        if (tramo.length > 2) break;
        intentos++;
        if (intentos < 3) {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
      if (tramo.length <= 2) {
        tramo = _suavizarRuta([secuencia[i], secuencia[i + 1]]);
      }
      tramosCalculados.add(tramo);
      if (i < secuencia.length - 2) {
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    }

    setState(() {
      _puntosRuta = resultado;
      _tramosPolyline = tramosCalculados;
      _calculando = false;
      _rutaCalculada = true;
    });
  }

  // ── Markers para el mapa ──
  List<Marker> _buildMarkers() {
    return [
      Marker(
        point: _oficina,
        width: 36,
        height: 36,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.verdeDark,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child:
          const Icon(Icons.star, color: AppColors.amarillo, size: 16),
        ),
      ),
      ..._puntosRuta.asMap().entries.map((e) {
        final i = e.key;
        final p = e.value;
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
      }),
    ];
  }

  // ── Polylines para el mapa ──
  List<Polyline> _buildPolylines() {
    return _tramosPolyline.asMap().entries.map((e) {
      final color = _coloresTramos[e.key % _coloresTramos.length];
      return Polyline(points: e.value, strokeWidth: 4, color: color);
    }).toList();
  }

  void _abrirMapaRutaCompleto() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapaCompletoScreen(
          centro: _oficina,
          zoom: 12,
          markers: _buildMarkers(),
          polylines: _buildPolylines(),
          titulo: 'Ruta · ${_puntosRuta.length} paradas',
        ),
      ),
    );
  }

  // ── Distancia total km ──
  double _distanciaTotal() {
    if (_puntosRuta.isEmpty) return 0;
    double total =
    _distancia(_oficina, _coordsPunto(_puntosRuta.first));
    for (int i = 0; i < _puntosRuta.length - 1; i++) {
      total += _distancia(
          _coordsPunto(_puntosRuta[i]), _coordsPunto(_puntosRuta[i + 1]));
    }
    total += _distancia(_coordsPunto(_puntosRuta.last), _oficina);
    return total / 1000;
  }

  int _tiempoEstimado() {
    final distKm = _distanciaTotal();
    return (distKm / 20 * 60 * 1.4).round() + _puntosRuta.length * 15;
  }

  String _sumarHora(String horaBase, int minutos) {
    final partes = horaBase.split(':');
    final total =
        int.parse(partes[0]) * 60 + int.parse(partes[1]) + minutos;
    return '${(total ~/ 60).toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }

  Color _colorPrioridad(String? p) {
    switch (p) {
      case 'alta':  return AppColors.prioAlta;
      case 'media': return AppColors.prioMedia;
      default:      return AppColors.prioBaja;
    }
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _buildTopbar(),
          Expanded(
            child: _rutaCalculada
                ? _buildVistaCalculada()
                : _buildVistaArmado(),
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
          // Si viene de Base Táctica mostrar botón regresar
          if (widget.puntosIniciales != null) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    widget.puntosIniciales != null
                        ? 'Ruta Táctica'
                        : 'Armar Ruta',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text(
                    _puntosRuta.isEmpty
                        ? 'Agrega clientes o caseríos'
                        : '${_puntosRuta.length} punto${_puntosRuta.length != 1 ? 's' : ''} en ruta',
                    style: const TextStyle(
                        color: Color(0xFFA8D5B5), fontSize: 11)),
              ],
            ),
          ),
          if (_puntosRuta.isNotEmpty)
            GestureDetector(
              onTap: _limpiarRuta,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Limpiar',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVistaArmado() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BUSCAR CLIENTE O LUGAR',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.verde,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _buscarController,
                  onChanged: _buscar,
                  decoration: InputDecoration(
                    hintText: 'Nombre del cliente o caserío...',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: AppColors.text3),
                    prefixIcon: const Icon(Icons.search,
                        color: AppColors.text3, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                      const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                      const BorderSide(color: AppColors.verde),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () =>
                    setState(() => _mostrarCaserios = !_mostrarCaserios),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _mostrarCaserios
                        ? AppColors.amarillo
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(Icons.location_city,
                      color: _mostrarCaserios
                          ? AppColors.verdeDark
                          : AppColors.text2,
                      size: 20),
                ),
              ),
            ],
          ),
          // Botón marcar en mapa
          GestureDetector(
            onTap: _abrirMapaSeleccion,
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.verdeLt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.verde.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_location_alt, color: AppColors.verde, size: 18),
                  SizedBox(width: 8),
                  Text('Marcar punto en el mapa',
                      style: TextStyle(
                          color: AppColors.verde,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),

          // Indicador cargando
          if (_buscando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child:
                  CircularProgressIndicator(color: AppColors.verde)),
            ),

          // Resultados clientes
          if (_resultadosClientes.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 0.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Text('CLIENTES',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text3,
                            letterSpacing: 1)),
                  ),
                  ..._resultadosClientes.map((c) {
                    final tieneGps =
                        c['lat_casa'] != null || c['lat_negocio'] != null;
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor:
                        _colorPrioridad(c['prioridad']),
                        child: const Icon(Icons.person,
                            color: Colors.white, size: 14),
                      ),
                      title: Text(c['nombre'] ?? '',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      subtitle: Text(c['caserio'] ?? '',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.text2)),
                      trailing: tieneGps
                          ? const Icon(Icons.add_circle,
                          color: AppColors.verde, size: 22)
                          : const Icon(Icons.location_off,
                          color: AppColors.text3, size: 18),
                      onTap: () => _agregarCliente(c),
                    );
                  }),
                ],
              ),
            ),

          // Resultados caseríos
          if (_resultadosCaserios.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 0.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Text('CASERÍOS',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text3,
                            letterSpacing: 1)),
                  ),
                  ..._resultadosCaserios.map((c) {
                    return ListTile(
                      dense: true,
                      leading: const CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.verde,
                        child: Icon(Icons.location_city,
                            color: Colors.white, size: 14),
                      ),
                      title: Text(c['nombre'] ?? '',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      subtitle: Text(
                          '${c['lat_centro']?.toStringAsFixed(4)}, ${c['lng_centro']?.toStringAsFixed(4)}',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.text3)),
                      trailing: const Icon(Icons.add_circle,
                          color: AppColors.amarillo, size: 22),
                      onTap: () => _agregarCaserio(c),
                    );
                  }),
                ],
              ),
            ),

          // Lista completa de caseríos
          if (_mostrarCaserios) ...[
            const SizedBox(height: 12),
            const Text('CASERÍOS GUARDADOS',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.verde,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                children: _caserios.map((c) {
                  return ListTile(
                    dense: true,
                    leading: const CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.verde,
                      child: Icon(Icons.location_city,
                          color: Colors.white, size: 14),
                    ),
                    title: Text(c['nombre'] ?? '',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                        '${c['lat_centro']?.toStringAsFixed(4)}, ${c['lng_centro']?.toStringAsFixed(4)}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.text3)),
                    trailing: const Icon(Icons.add_circle,
                        color: AppColors.amarillo, size: 22),
                    onTap: () => _agregarCaserio(c),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Puntos en ruta
          const Text('PUNTOS EN LA RUTA',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.verde,
                  letterSpacing: 1)),
          const SizedBox(height: 8),

          if (_puntosRuta.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.route, color: AppColors.text3, size: 32),
                    SizedBox(height: 8),
                    Text('No hay puntos agregados aún',
                        style: TextStyle(
                            color: AppColors.text3, fontSize: 13)),
                    SizedBox(height: 4),
                    Text('Busca un cliente o selecciona un caserío',
                        style: TextStyle(
                            color: AppColors.text3, fontSize: 11)),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                children: [
                  _filaLista('★', 'Oficina Mi Banco', 'Inicio',
                      AppColors.verdeDark),
                  ..._puntosRuta.asMap().entries.map((e) {
                    final i = e.key;
                    final p = e.value;
                    return _filaLista(
                      '${i + 1}',
                      p['nombre'] ?? '',
                      p['tipo_punto'] == 'caserio'
                          ? 'Caserío'
                          : '${p['tipo'] ?? ''} · ${p['caserio'] ?? ''}',
                      p['tipo_punto'] == 'caserio'
                          ? AppColors.verde
                          : _colorPrioridad(p['prioridad']),
                      onEliminar: () => _eliminarPunto(i),
                    );
                  }),
                  _filaLista(
                      '↩', 'Regreso Oficina', 'Fin', AppColors.verdeDark),
                ],
              ),
            ),

          const SizedBox(height: 16),

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
              onPressed:
              _puntosRuta.isEmpty || _calculando ? null : _calcularRuta,
              icon: _calculando
                  ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: AppColors.verdeDark, strokeWidth: 2))
                  : const Icon(Icons.calculate),
              label: Text(_calculando
                  ? 'Calculando... (~${_puntosRuta.length * 2}s)'
                  : 'Calcular Mejor Ruta'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _filaLista(
      String numero,
      String nombre,
      String subtitulo,
      Color color, {
        VoidCallback? onEliminar,
      }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color,
            child: Text(numero,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                Text(subtitulo,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.text2)),
              ],
            ),
          ),
          if (onEliminar != null)
            GestureDetector(
              onTap: onEliminar,
              child: const Icon(Icons.remove_circle_outline,
                  color: AppColors.prioAlta, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildVistaCalculada() {
    final distKm = _distanciaTotal();
    final mins = _tiempoEstimado();
    final horas = mins ~/ 60;
    final minutos = mins % 60;
    final horaFin = _sumarHora('08:00', mins);

    return Column(
      children: [
        // Resumen
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(child: _statCard('${_puntosRuta.length}', 'Paradas')),
              Expanded(
                  child: _statCard(
                      '${distKm.toStringAsFixed(1)} km', 'Distancia')),
              Expanded(
                  child: _statCard(
                      horas > 0 ? '${horas}h ${minutos}m' : '${minutos}m',
                      'Tiempo est.')),
              Expanded(child: _statCard(horaFin, 'Regreso')),
            ],
          ),
        ),

        // Mapa con botón pantalla completa
        SizedBox(
          height: 240,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: _oficina,
                  initialZoom: 12,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.rutech.app',
                  ),
                  if (_tramosPolyline.isNotEmpty)
                    PolylineLayer(polylines: _buildPolylines()),
                  MarkerLayer(markers: _buildMarkers()),
                ],
              ),
              // Botón pantalla completa
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _abrirMapaRutaCompleto,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4)
                      ],
                    ),
                    child: const Icon(Icons.fullscreen,
                        color: AppColors.verdeDark, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Lista pasos
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ORDEN DE VISITAS',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.verde,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border:
                    Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      _pasoRuta('★', 'Oficina Mi Banco', 'Salida 08:00',
                          AppColors.verdeDark),
                      ..._puntosRuta.asMap().entries.map((e) {
                        final i = e.key;
                        final p = e.value;
                        final anterior = i == 0
                            ? _oficina
                            : _coordsPunto(_puntosRuta[i - 1]);
                        final actual = _coordsPunto(p);
                        final distM = _distancia(anterior, actual);
                        final distKmT = distM / 1000;
                        final minsTraslado =
                        (distKmT / 20 * 60 * 1.4).round();

                        int minsAcum = 0;
                        for (int k = 0; k <= i; k++) {
                          final ant2 = k == 0
                              ? _oficina
                              : _coordsPunto(_puntosRuta[k - 1]);
                          final act2 = _coordsPunto(_puntosRuta[k]);
                          final d = _distancia(ant2, act2) / 1000;
                          minsAcum += (d / 20 * 60 * 1.4).round();
                          if (k < i) minsAcum += 15;
                        }
                        final horaLlegada = _sumarHora('08:00', minsAcum);
                        final colorTramo =
                        _coloresTramos[i % _coloresTramos.length];

                        return _pasoRuta(
                          '${i + 1}',
                          p['nombre'] ?? '',
                          '${distKmT.toStringAsFixed(1)} km · ~${minsTraslado}min · llega $horaLlegada',
                          colorTramo,
                        );
                      }),
                      _pasoRuta('↩', 'Regreso Oficina',
                          'Fin aprox. $horaFin', AppColors.verdeDark),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EjecutarRutaScreen(
                            puntosRuta: _puntosRuta,
                            tramosPolyline: _tramosPolyline,
                            coloresTramos: _coloresTramos,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text('Iniciar Ruta',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.verde,
                      side: const BorderSide(color: AppColors.verde),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () =>
                        setState(() => _rutaCalculada = false),
                    icon: const Icon(Icons.edit),
                    label: const Text('Modificar Ruta'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String valor, String label) {
    return Column(
      children: [
        Text(valor,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.verde)),
        Text(label,
            style:
            const TextStyle(fontSize: 9, color: AppColors.text3)),
      ],
    );
  }

  Widget _pasoRuta(String num, String nombre, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: color,
            child: Text(num,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.text2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}