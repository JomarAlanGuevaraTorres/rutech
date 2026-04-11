import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../theme/colors.dart';
import '../database/db_helper.dart';
import 'ruta_screen.dart';

class BaseScreen extends StatefulWidget {
  const BaseScreen({super.key});
  @override
  State<BaseScreen> createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> {
  // ── Datos ──
  List<Map<String, dynamic>> _todos = [];
  List<Map<String, dynamic>> _filtrados = [];
  List<Map<String, dynamic>> _seleccionados = [];
  bool _cargando = false;

  // ── Filtros de campaña (combinables) ──
  bool _filtroCDD = false;
  bool _filtroWinay = false;
  bool _filtroDisposicion = false;
  bool _filtroCapitalExpress = false;
  bool _filtroMorosos = false;
  bool _filtroNuevo = false;
  bool _filtroInactivo = false;
  bool _filtroVigente = false;

  // ── Ordenamiento ──
  bool _ordenTasa = false;
  bool _ordenMonto = false;
  bool _ordenDistancia = false;
  bool _ordenMora = false;

  final LatLng _oficina = const LatLng(-5.238109, -79.451223);

  @override
  void initState() {
    super.initState();
    _cargarTacticos();
  }

  Future<void> _cargarTacticos() async {
    setState(() => _cargando = true);
    final data = await DBHelper.getTacticos();
    setState(() {
      _todos = data;
      _cargando = false;
    });
    _aplicarFiltros();
  }

  double _distanciaOficina(Map<String, dynamic> c) {
    final lat = c['lat'] as double?;
    final lng = c['lng'] as double?;
    if (lat == null || lng == null) return double.infinity;
    const d = Distance();
    return d(_oficina, LatLng(lat, lng));
  }

  void _aplicarFiltros() {
    List<Map<String, dynamic>> resultado = List.from(_todos);

    final campanaActiva = _filtroCDD || _filtroWinay ||
        _filtroDisposicion || _filtroCapitalExpress;

    if (campanaActiva && _filtroMorosos) {
      resultado = resultado.where((c) {
        final campana = (c['campana'] ?? '').toString().toLowerCase();
        final mora = (c['morosidad'] as int? ?? 0);
        final esMoroso = mora > 0 && campana.isEmpty;
        bool esDeCampana = false;
        if (_filtroCDD && campana.contains('cdd')) esDeCampana = true;
        if (_filtroWinay && campana.contains('wiñay')) esDeCampana = true;
        if (_filtroDisposicion && campana.contains('disposici'))
          esDeCampana = true;
        if (_filtroCapitalExpress && campana.contains('capital'))
          esDeCampana = true;
        return esMoroso || esDeCampana;
      }).toList();
    } else if (campanaActiva) {
      resultado = resultado.where((c) {
        final campana = (c['campana'] ?? '').toString().toLowerCase();
        final mora = (c['morosidad'] as int? ?? 0);
        if (mora > 0) return false;
        if (_filtroCDD && campana.contains('cdd')) return true;
        if (_filtroWinay && campana.contains('wiñay')) return true;
        if (_filtroDisposicion && campana.contains('disposici')) return true;
        if (_filtroCapitalExpress && campana.contains('capital')) return true;
        return false;
      }).toList();
    } else if (_filtroMorosos) {
      resultado = resultado
          .where((c) => (c['morosidad'] as int? ?? 0) > 0)
          .toList();
    }

    final tipoActivo = _filtroNuevo || _filtroInactivo || _filtroVigente;
    if (tipoActivo) {
      resultado = resultado.where((c) {
        final tipo = (c['tipo_cliente'] ?? '').toString().toLowerCase();
        if (_filtroNuevo && tipo.contains('nuevo')) return true;
        if (_filtroInactivo && tipo.contains('inactivo')) return true;
        if (_filtroVigente && tipo.contains('vigente')) return true;
        return false;
      }).toList();
    }

    resultado.sort((a, b) {
      if (_ordenTasa && _ordenMonto) {
        final montoA = (a['saldo'] as num? ?? 0).toDouble();
        final montoB = (b['saldo'] as num? ?? 0).toDouble();
        final tasaA = (a['tasa'] as num? ?? 0).toDouble();
        final tasaB = (b['tasa'] as num? ?? 0).toDouble();
        final puntajeA = montoA - (tasaA * 1000);
        final puntajeB = montoB - (tasaB * 1000);
        return puntajeB.compareTo(puntajeA);
      }
      if (_ordenTasa) {
        final tasaA = (a['tasa'] as num? ?? 0).toDouble();
        final tasaB = (b['tasa'] as num? ?? 0).toDouble();
        return tasaA.compareTo(tasaB);
      }
      if (_ordenMonto) {
        final montoA = (a['saldo'] as num? ?? 0).toDouble();
        final montoB = (b['saldo'] as num? ?? 0).toDouble();
        return montoB.compareTo(montoA);
      }
      if (_ordenDistancia) {
        return _distanciaOficina(a).compareTo(_distanciaOficina(b));
      }
      if (_ordenMora) {
        final moraA = (a['morosidad'] as int? ?? 0);
        final moraB = (b['morosidad'] as int? ?? 0);
        return moraB.compareTo(moraA);
      }
      return 0;
    });

    setState(() => _filtrados = resultado);
  }

  void _toggleFiltro(String tipo) {
    setState(() {
      switch (tipo) {
        case 'cdd':         _filtroCDD = !_filtroCDD; break;
        case 'winay':       _filtroWinay = !_filtroWinay; break;
        case 'disposicion': _filtroDisposicion = !_filtroDisposicion; break;
        case 'capital':     _filtroCapitalExpress = !_filtroCapitalExpress; break;
        case 'morosos':     _filtroMorosos = !_filtroMorosos; break;
        case 'nuevo':       _filtroNuevo = !_filtroNuevo; break;
        case 'inactivo':    _filtroInactivo = !_filtroInactivo; break;
        case 'vigente':     _filtroVigente = !_filtroVigente; break;
      }
    });
    _aplicarFiltros();
  }

  void _toggleOrden(String tipo) {
    setState(() {
      switch (tipo) {
        case 'tasa':      _ordenTasa = !_ordenTasa; break;
        case 'monto':     _ordenMonto = !_ordenMonto; break;
        case 'distancia': _ordenDistancia = !_ordenDistancia; break;
        case 'mora':      _ordenMora = !_ordenMora; break;
      }
    });
    _aplicarFiltros();
  }

  void _toggleSeleccion(Map<String, dynamic> cliente) {
    setState(() {
      final yaEsta = _seleccionados.any((c) => c['id'] == cliente['id']);
      if (yaEsta) {
        _seleccionados.removeWhere((c) => c['id'] == cliente['id']);
      } else {
        _seleccionados.add(cliente);
      }
    });
  }

  void _limpiarFiltros() {
    setState(() {
      _filtroCDD = false;
      _filtroWinay = false;
      _filtroDisposicion = false;
      _filtroCapitalExpress = false;
      _filtroMorosos = false;
      _filtroNuevo = false;
      _filtroInactivo = false;
      _filtroVigente = false;
      _ordenTasa = false;
      _ordenMonto = false;
      _ordenDistancia = false;
      _ordenMora = false;
      _seleccionados = [];
    });
    _aplicarFiltros();
  }

  void _mostrarSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.prioAlta : AppColors.verde,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  Color _colorTipo(String? tipo) {
    switch ((tipo ?? '').toLowerCase()) {
      case 'nuevo':    return const Color(0xFF378ADD);
      case 'inactivo': return AppColors.prioMedia;
      case 'vigente':  return AppColors.prioBaja;
      default:         return AppColors.text3;
    }
  }

  String _formatMonto(double m) {
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)}k';
    return m.toStringAsFixed(0);
  }

  // ── Navegación a ruta ──
  void _irARuta() {
    if (_seleccionados.isEmpty) {
      _mostrarSnack('Selecciona al menos un cliente', error: true);
      return;
    }
    final conUbicacion = _seleccionados
        .where((c) => c['lat'] != null && c['lng'] != null)
        .toList();
    if (conUbicacion.isEmpty) {
      _mostrarSnack('Ningún cliente seleccionado tiene GPS', error: true);
      return;
    }
    if (conUbicacion.length < _seleccionados.length) {
      _mostrarSnack(
          '${_seleccionados.length - conUbicacion.length} sin GPS serán omitidos');
    }
    _navegarARuta(conUbicacion);
  }

  void _irARutaAuto() {
    final conUbicacion = _filtrados
        .where((c) => c['lat'] != null && c['lng'] != null)
        .take(10)
        .toList();
    if (conUbicacion.isEmpty) {
      _mostrarSnack('No hay clientes con GPS en la lista', error: true);
      return;
    }
    setState(() => _seleccionados = conUbicacion);
    _navegarARuta(conUbicacion);
  }

  void _navegarARuta(List<Map<String, dynamic>> clientes) {
    final puntosRuta = clientes.map((c) => {
      'id': c['id'] ?? c['dni'],
      'nombre': c['nombre'] ?? '',
      'tipo': c['tipo_cliente'] ?? '',
      'caserio': c['direccion'] ?? '',
      'prioridad': (c['morosidad'] as int? ?? 0) > 0 ? 'alta' : 'media',
      'lat_casa': c['lat'],
      'lng_casa': c['lng'],
      'lat_negocio': null,
      'lng_negocio': null,
      'tipo_punto': 'cliente',
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RutaScreen(puntosIniciales: puntosRuta),
      ),
    );
  }

  // ── Datos de prueba ──
  Future<void> _cargarDatosDePrueba() async {
    setState(() => _cargando = true);
    await DBHelper.limpiarTacticos();
    await DBHelper.insertarTacticosBatch([
      // Con campaña
      {'dni':'11111111','nombre':'Rosa Quispe Flores',  'tipo_cliente':'Vigente', 'direccion':'Tierra Negra',   'tasa':18.5,'saldo':12000,'morosidad':0,'campana':'CDD',            'lat':-5.231399,'lng':-79.422371},
      {'dni':'22222222','nombre':'Juan Ramos Torres',   'tipo_cliente':'Nuevo',   'direccion':'Tayapampa',      'tasa':16.0,'saldo':8500, 'morosidad':0,'campana':'Wiñay',          'lat':-5.243605,'lng':-79.406617},
      {'dni':'44444444','nombre':'Pedro Ojeda Silva',   'tipo_cliente':'Inactivo','direccion':'Laumache',       'tasa':19.5,'saldo':15000,'morosidad':0,'campana':'Disposición',    'lat':-5.186929,'lng':-79.464988},
      {'dni':'55555555','nombre':'Ana Tocto Guerrero',  'tipo_cliente':'Nuevo',   'direccion':'Quispe Bajo',    'tasa':14.5,'saldo':20000,'morosidad':0,'campana':'CDD',            'lat':-5.184127,'lng':-79.484030},
      {'dni':'77777777','nombre':'Carmen Flores Díaz',  'tipo_cliente':'Inactivo','direccion':'Sapalache',      'tasa':17.0,'saldo':9000, 'morosidad':0,'campana':'Capital Express','lat':-5.148567,'lng':-79.428904},
      {'dni':'88888888','nombre':'Jorge Panta Rojas',   'tipo_cliente':'Nuevo',   'direccion':'Cajas Canchaque','tasa':15.5,'saldo':11000,'morosidad':0,'campana':'Capital Express','lat':-5.170512,'lng':-79.426881},
      {'dni':'10101010','nombre':'Roberto Mío Huanca',  'tipo_cliente':'Inactivo','direccion':'Tres Acequias',  'tasa':20.0,'saldo':6800, 'morosidad':0,'campana':'Wiñay',          'lat':-5.199125,'lng':-79.431660},
      {'dni':'12121212','nombre':'Sandra Zapata León',  'tipo_cliente':'Nuevo',   'direccion':'Quispe Alto',    'tasa':13.5,'saldo':25000,'morosidad':0,'campana':'CDD',            'lat':-5.177373,'lng':-79.490919},
      {'dni':'14141414','nombre':'Carlos Vera Mío',     'tipo_cliente':'Vigente', 'direccion':'Comenderos',     'tasa':21.0,'saldo':7200, 'morosidad':0,'campana':'Wiñay',          'lat':-5.211001,'lng':-79.433143},
      {'dni':'15151515','nombre':'Lucía Peña Torres',   'tipo_cliente':'Nuevo',   'direccion':'Chontapampa',    'tasa':16.5,'saldo':18000,'morosidad':0,'campana':'CDD',            'lat':-5.212892,'lng':-79.439631},
      {'dni':'16161616','nombre':'Marco Flores Ruiz',   'tipo_cliente':'Vigente', 'direccion':'Cruz Grande',    'tasa':22.0,'saldo':5500, 'morosidad':0,'campana':'Disposición',    'lat':-5.217021,'lng':-79.457669},
      {'dni':'17171717','nombre':'Patricia Ojeda Paz',  'tipo_cliente':'Inactivo','direccion':'Caserío Cabeza', 'tasa':15.0,'saldo':14000,'morosidad':0,'campana':'Capital Express','lat':-5.239914,'lng':-79.426675},
      // Morosos sin campaña
      {'dni':'33333333','nombre':'María Chunga Paz',    'tipo_cliente':'Vigente', 'direccion':'Aterrizaje',     'tasa':22.0,'saldo':5000, 'morosidad':30,'campana':'','lat':-5.258456,'lng':-79.442114},
      {'dni':'66666666','nombre':'Luis Carrasco Vega',  'tipo_cliente':'Vigente', 'direccion':'Catulun',        'tasa':21.0,'saldo':3500, 'morosidad':15,'campana':'','lat':-5.170609,'lng':-79.471757},
      {'dni':'99999999','nombre':'Elena Ruiz Castro',   'tipo_cliente':'Vigente', 'direccion':'Ñangaly',        'tasa':23.0,'saldo':4200, 'morosidad':60,'campana':'','lat':-5.175335,'lng':-79.451303},
      {'dni':'13131313','nombre':'Miguel Ángel Bravo',  'tipo_cliente':'Vigente', 'direccion':'Yumbe',          'tasa':18.0,'saldo':7500, 'morosidad':45,'campana':'','lat':-5.158862,'lng':-79.448086},
    ]);
    await _cargarTacticos();
    _mostrarSnack('✓ Datos de prueba cargados');
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
          _buildFiltros(),
          _buildOrdenamiento(),
          _buildResumen(),
          Expanded(child: _buildLista()),
          if (_seleccionados.isNotEmpty) _buildBarraAccion(),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Base Táctica',
                    style: TextStyle(color: Colors.white,
                        fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                    '${_filtrados.length} registros · ${_seleccionados.length} seleccionados',
                    style: const TextStyle(
                        color: Color(0xFFA8D5B5), fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _mostrarDialogoCarga,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.amarillo,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.upload_file,
                      color: AppColors.verdeDark, size: 14),
                  SizedBox(width: 4),
                  Text('Cargar CSV',
                      style: TextStyle(
                          color: AppColors.verdeDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _limpiarFiltros,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.filter_alt_off,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CAMPAÑA',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: AppColors.text3, letterSpacing: 1)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('CDD', _filtroCDD,
                        () => _toggleFiltro('cdd'),
                    color: const Color(0xFF378ADD)),
                _chip('Wiñay', _filtroWinay,
                        () => _toggleFiltro('winay'),
                    color: const Color(0xFF1D9E75)),
                _chip('Disposición', _filtroDisposicion,
                        () => _toggleFiltro('disposicion'),
                    color: const Color(0xFF9B59B6)),
                _chip('Capital Express', _filtroCapitalExpress,
                        () => _toggleFiltro('capital'),
                    color: const Color(0xFFE67E22)),
                _chip('Morosos', _filtroMorosos,
                        () => _toggleFiltro('morosos'),
                    color: AppColors.prioAlta),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text('TIPO DE CLIENTE',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: AppColors.text3, letterSpacing: 1)),
          const SizedBox(height: 6),
          Row(
            children: [
              _chip('Nuevo', _filtroNuevo,
                      () => _toggleFiltro('nuevo'),
                  color: const Color(0xFF378ADD)),
              _chip('Inactivo', _filtroInactivo,
                      () => _toggleFiltro('inactivo'),
                  color: AppColors.prioMedia),
              _chip('Vigente', _filtroVigente,
                      () => _toggleFiltro('vigente'),
                  color: AppColors.prioBaja),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOrdenamiento() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          const Text('ORDENAR POR',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: AppColors.text3, letterSpacing: 1)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chipOrden('Tasa ↑', _ordenTasa,
                        () => _toggleOrden('tasa')),
                _chipOrden('Monto ↓', _ordenMonto,
                        () => _toggleOrden('monto')),
                _chipOrden('Distancia', _ordenDistancia,
                        () => _toggleOrden('distancia')),
                _chipOrden('Mora ↓', _ordenMora,
                        () => _toggleOrden('mora')),
              ],
            ),
          ),
          if (_ordenTasa && _ordenMonto)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '✦ Combinado: mayor monto con menor tasa primero',
                style: TextStyle(fontSize: 10, color: AppColors.verde,
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResumen() {
    final conUbicacion =
        _filtrados.where((c) => c['lat'] != null).length;
    final morosos =
        _filtrados.where((c) => (c['morosidad'] as int? ?? 0) > 0).length;
    final tasaPromedio = _filtrados.isEmpty
        ? 0.0
        : _filtrados.fold<double>(
        0,
            (s, c) =>
        s + (c['tasa'] as num? ?? 0).toDouble()) /
        _filtrados.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.bg,
      child: Row(
        children: [
          _statMini('${_filtrados.length}', 'Total'),
          _statMini('$conUbicacion', 'Con GPS'),
          _statMini('$morosos', 'Morosos'),
          _statMini('${tasaPromedio.toStringAsFixed(1)}%', 'Tasa prom.'),
        ],
      ),
    );
  }

  Widget _statMini(String valor, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          children: [
            Text(valor,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.verde)),
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: AppColors.text3)),
          ],
        ),
      ),
    );
  }

  Widget _buildLista() {
    if (_cargando) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.verde));
    }
    if (_todos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.upload_file,
                size: 48, color: AppColors.text3),
            const SizedBox(height: 12),
            const Text('No hay base táctica cargada',
                style: TextStyle(
                    color: AppColors.text2, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Toca "Cargar CSV" para importar la base del mes',
                style: TextStyle(
                    color: AppColors.text3, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amarillo,
                foregroundColor: AppColors.verdeDark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _mostrarDialogoCarga,
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('Cargar base táctica'),
            ),
          ],
        ),
      );
    }
    if (_filtrados.isEmpty) {
      return const Center(
        child: Text('Sin resultados con los filtros actuales',
            style: TextStyle(color: AppColors.text3, fontSize: 13)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: _filtrados.length,
      itemBuilder: (ctx, i) {
        final c = _filtrados[i];
        final seleccionado =
        _seleccionados.any((s) => s['id'] == c['id']);
        final mora = (c['morosidad'] as int? ?? 0);
        final tasa = (c['tasa'] as num? ?? 0).toDouble();
        final saldo = (c['saldo'] as num? ?? 0).toDouble();
        final tieneGps = c['lat'] != null;

        return GestureDetector(
          onTap: () => _toggleSeleccion(c),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: seleccionado ? AppColors.verdeLt : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: seleccionado
                    ? AppColors.verde
                    : AppColors.border,
                width: seleccionado ? 1.5 : 0.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Checkbox visual
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: seleccionado
                          ? AppColors.verde
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: seleccionado
                              ? AppColors.verde
                              : AppColors.border,
                          width: 1.5),
                    ),
                    child: seleccionado
                        ? const Icon(Icons.check,
                        color: Colors.white, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 10),

                  // Info cliente
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(c['nombre'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _colorTipo(c['tipo_cliente'])
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                c['tipo_cliente'] ?? '',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: _colorTipo(c['tipo_cliente'])),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if ((c['campana'] ?? '').toString().isNotEmpty)
                              Text(c['campana'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.text2)),
                            if ((c['campana'] ?? '').toString().isNotEmpty &&
                                (c['direccion'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                              const Text(' · ',
                                  style: TextStyle(
                                      color: AppColors.text3,
                                      fontSize: 11)),
                            Expanded(
                              child: Text(c['direccion'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.text3),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        if (mora > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 12,
                                    color: AppColors.prioAlta),
                                const SizedBox(width: 3),
                                Text('$mora días de mora',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.prioAlta,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Tasa y monto
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${tasa.toStringAsFixed(1)}%',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.verde)),
                      Text('S/. ${_formatMonto(saldo)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.text2)),
                      const SizedBox(height: 2),
                      Icon(
                        tieneGps
                            ? Icons.location_on
                            : Icons.location_off,
                        size: 12,
                        color: tieneGps
                            ? AppColors.prioBaja
                            : AppColors.text3,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarraAccion() {
    final conGps = _seleccionados
        .where((c) => c['lat'] != null && c['lng'] != null)
        .length;
    final autoDisponibles = _filtrados
        .where((c) => c['lat'] != null && c['lng'] != null)
        .take(10)
        .length;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: AppColors.verde, size: 14),
              const SizedBox(width: 6),
              Text(
                '${_seleccionados.length} seleccionados · $conGps con GPS',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.text2),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _seleccionados = []),
                child: const Text('Limpiar',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.prioAlta,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amarillo,
                foregroundColor: AppColors.verdeDark,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _irARuta,
              icon: const Icon(Icons.route, size: 16),
              label: Text(
                  'Calcular ruta con ${_seleccionados.length} seleccionados',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.verde,
                side: const BorderSide(color: AppColors.verde),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _irARutaAuto,
              icon: const Icon(Icons.auto_awesome, size: 14),
              label: Text(
                  'Auto: calcular ruta con los $autoDisponibles primeros',
                  style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCarga() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('Cargar base táctica',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'El archivo CSV debe tener las columnas:\n'
                  'DNI, Nombre, Tipo, Dirección, Tasa, Saldo, Mora, Campaña',
              style: TextStyle(fontSize: 12, color: AppColors.text2),
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
                onPressed: () {
                  Navigator.pop(context);
                  _mostrarSnack(
                      'Próximamente: importar CSV desde el celular');
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Seleccionar archivo CSV',
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _cargarDatosDePrueba();
                },
                icon: const Icon(Icons.science, size: 16),
                label: const Text('Cargar datos de prueba',
                    style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool activo, VoidCallback onTap,
      {Color color = AppColors.verde}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6, bottom: 4),
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border:
          Border.all(color: activo ? color : AppColors.border, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: activo ? Colors.white : AppColors.text2)),
      ),
    );
  }

  Widget _chipOrden(String label, bool activo, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: activo ? AppColors.verdeLt : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: activo ? AppColors.verde : AppColors.border,
              width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: activo ? AppColors.verde : AppColors.text2)),
      ),
    );
  }
}