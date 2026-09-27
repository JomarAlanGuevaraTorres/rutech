import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/rutech_api.dart';
import '../theme/colors.dart';

class OperacionScreen extends StatefulWidget {
  const OperacionScreen({super.key});
  @override
  State<OperacionScreen> createState() => _OperacionScreenState();
}

class _OperacionScreenState extends State<OperacionScreen> {
  final _api = RutechApi();
  int _tab = 0, _maxVisits = 15;
  bool _loading = true, _planning = false;
  String? _error;
  String _agencyCode = 'AG01', _priority = 'Todas';
  List<Map<String, dynamic>> _agencies = [], _clients = [];
  Map<String, dynamic>? _plan;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final agencies = await _api.agencias();
      final code = agencies.isEmpty ? 'AG01' : '${agencies.first['Codigo']}';
      final clients = await _api.clientes(agencia: code);
      if (!mounted) return;
      setState(() {
        _agencies = agencies;
        _agencyCode = code;
        _clients = clients;
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = '$e';
          _loading = false;
        });
    }
  }

  Future<void> _changeAgency(String code) async {
    setState(() {
      _agencyCode = code;
      _loading = true;
      _plan = null;
      _error = null;
    });
    try {
      final clients = await _api.clientes(agencia: code);
      if (mounted)
        setState(() {
          _clients = clients;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = '$e';
          _loading = false;
        });
    }
  }

  Future<void> _generate() async {
    setState(() {
      _planning = true;
      _error = null;
    });
    try {
      final plan = await _api.planificar(
        agencia: _agencyCode,
        maxVisitas: _maxVisits,
      );
      if (mounted)
        setState(() {
          _plan = plan;
          _planning = false;
          _tab = 3;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = '$e';
          _planning = false;
        });
    }
  }

  Map<String, dynamic>? get _agency {
    for (final a in _agencies) {
      if ('${a['Codigo']}' == _agencyCode) return a;
    }
    return null;
  }

  List<Map<String, dynamic>> get _filtered => _priority == 'Todas'
      ? _clients
      : _clients.where((c) => c['Prioridad'] == _priority).toList();
  List<Map<String, dynamic>> get _visits =>
      ((_plan?['visitas'] as List?) ?? const []).cast<Map<String, dynamic>>();
  Color _color(String? p) => switch (p) {
    'P1' => const Color(0xffc62828),
    'P2' => const Color(0xffef6c00),
    'P3' => const Color(0xff1565c0),
    _ => const Color(0xff616161),
  };
  String _time(dynamic value) {
    final m = (value as num?)?.toInt() ?? 0;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  LatLng _coords(Map<String, dynamic> x) => LatLng(
    (x['Latitud'] as num).toDouble(),
    (x['Longitud'] as num).toDouble(),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xfff5f7f6),
    appBar: AppBar(
      backgroundColor: AppColors.verdeDark,
      foregroundColor: Colors.white,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RUTECH',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
          Text(
            'Visitas comerciales y cobranza',
            style: TextStyle(fontSize: 11),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _errorView()
        : IndexedStack(
            index: _tab,
            children: [_home(), _clientList(), _map(_clients), _route()],
          ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Clientes',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: 'Mapa',
        ),
        NavigationDestination(
          icon: Icon(Icons.route_outlined),
          selectedIcon: Icon(Icons.route),
          label: 'Ruta',
        ),
      ],
    ),
  );

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 54, color: Colors.redAccent),
          const SizedBox(height: 12),
          const Text(
            'No se pudo cargar la operación',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );

  Widget _agencySelector() => DropdownButtonFormField<String>(
    initialValue: _agencyCode,
    decoration: const InputDecoration(
      labelText: 'Agencia de salida y retorno',
      border: OutlineInputBorder(),
      prefixIcon: Icon(Icons.account_balance),
    ),
    items: _agencies
        .map(
          (a) => DropdownMenuItem(
            value: '${a['Codigo']}',
            child: Text('${a['Agencia']}'),
          ),
        )
        .toList(),
    onChanged: _planning
        ? null
        : (v) {
            if (v != null) _changeAgency(v);
          },
  );

  Widget _home() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        'Planifica la jornada',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      const Text(
        'Primero se priorizan las visitas y después se optimiza el recorrido respetando sus ventanas horarias.',
      ),
      const SizedBox(height: 18),
      _agencySelector(),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ['P1', 'P2', 'P3', 'P4']
            .map(
              (p) => _metric(
                p,
                '${_clients.where((c) => c['Prioridad'] == p).length} clientes',
                _color(p),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configuración de ruta',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text('Máximo de visitas: $_maxVisits'),
              Slider(
                value: _maxVisits.toDouble(),
                min: 5,
                max: 25,
                divisions: 4,
                label: '$_maxVisits',
                onChanged: (v) => setState(() => _maxVisits = v.round()),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _planning ? null : _generate,
                  icon: _planning
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _planning ? 'Optimizando…' : 'Generar ruta priorizada',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Card(
        child: ListTile(
          leading: Icon(Icons.shield_outlined, color: AppColors.verde),
          title: Text('Escenario simulado'),
          subtitle: Text(
            'Los 200 registros son sintéticos y protegen la información real de los clientes.',
          ),
        ),
      ),
    ],
  );

  Widget _metric(String title, String subtitle, Color color) => Container(
    width: (MediaQuery.sizeOf(context).width - 48) / 2,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border(left: BorderSide(color: color, width: 5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        Text(subtitle),
      ],
    ),
  );

  Widget _clientList() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _agencySelector(),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Todas', 'P1', 'P2', 'P3', 'P4']
                    .map(
                      (p) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(p),
                          selected: _priority == p,
                          onSelected: (_) => setState(() => _priority = p),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: _filtered.length,
          itemBuilder: (_, i) => _clientTile(_filtered[i]),
        ),
      ),
    ],
  );

  Widget _clientTile(Map<String, dynamic> c) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: _color('${c['Prioridad']}'),
        foregroundColor: Colors.white,
        child: Text('${c['Prioridad']}'.substring(1)),
      ),
      title: Text(
        '${c['Nombre_cliente']}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${c['Tipo_gestion']} · ${c['Prioridad']} (${c['Puntaje_prioridad']} puntos)\n${c['Direccion_referencial'] ?? 'Ubicación registrada'}',
      ),
      isThreeLine: true,
      trailing: Icon(
        c['Tipo_gestion'] == 'COBRANZA'
            ? Icons.payments_outlined
            : Icons.handshake_outlined,
        color: AppColors.verde,
      ),
    ),
  );

  Widget _map(List<Map<String, dynamic>> items, {bool route = false}) {
    final agency = route
        ? (_plan?['agencia'] as Map<String, dynamic>?)
        : _agency;
    final center = agency == null
        ? const LatLng(-5.1945, -80.6328)
        : _coords(agency);
    final markers = <Marker>[
      Marker(
        point: center,
        width: 48,
        height: 48,
        child: const Icon(
          Icons.account_balance,
          color: AppColors.verdeDark,
          size: 38,
        ),
      ),
      ...items.map(
        (c) => Marker(
          point: _coords(c),
          width: 38,
          height: 38,
          child: Tooltip(
            message: '${c['Nombre_cliente']} · ${c['Prioridad']}',
            child: Icon(
              Icons.location_on,
              color: _color('${c['Prioridad']}'),
              size: route ? 34 : 26,
            ),
          ),
        ),
      ),
    ];
    final points = <LatLng>[center, ...items.map(_coords), if (route) center];
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: route ? 12.5 : 11.5,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.rutech',
        ),
        if (route && points.length > 2)
          PolylineLayer(
            polylines: [
              Polyline(points: points, strokeWidth: 5, color: AppColors.verde),
            ],
          ),
        MarkerLayer(markers: markers),
        RichAttributionWidget(
          attributions: const [
            TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  Widget _route() {
    if (_plan == null)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.route, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Aún no hay una ruta',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Genera un recorrido desde Inicio para aplicar prioridades y ventanas horarias.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => setState(() => _tab = 0),
                child: const Text('Ir al inicio'),
              ),
            ],
          ),
        ),
      );
    return Column(
      children: [
        SizedBox(height: 260, child: _map(_visits, route: true)),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_plan!['metodo']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_visits.length} visitas · ${_plan!['distancia_estimada_km']} km · ${_time(_plan!['inicio_min'])} a ${_time(_plan!['fin_min'])}',
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _visits.isEmpty
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RouteExecutionScreen(plan: _plan!),
                        ),
                      ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _visits.length,
            itemBuilder: (_, i) {
              final c = _visits[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _color('${c['Prioridad']}'),
                    foregroundColor: Colors.white,
                    child: Text('${c['Orden']}'),
                  ),
                  title: Text('${c['Nombre_cliente']}'),
                  subtitle: Text(
                    '${c['Tipo_gestion']} · ${c['Prioridad']} · ${_time(c['Llegada_min'])}–${_time(c['Salida_min'])}',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class RouteExecutionScreen extends StatefulWidget {
  const RouteExecutionScreen({super.key, required this.plan});
  final Map<String, dynamic> plan;
  @override
  State<RouteExecutionScreen> createState() => _RouteExecutionScreenState();
}

class _RouteExecutionScreenState extends State<RouteExecutionScreen> {
  int _index = 0;
  final Map<String, String> _results = {};
  List<Map<String, dynamic>> get _visits =>
      (widget.plan['visitas'] as List).cast<Map<String, dynamic>>();
  Map<String, dynamic> get _current => _visits[_index];
  String _time(dynamic value) {
    final m = (value as num).toInt();
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _navigate() => launchUrl(
    Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${_current['Latitud']},${_current['Longitud']}&travelmode=driving',
    ),
    mode: LaunchMode.externalApplication,
  );
  void _record(String result) {
    _results['${_current['ID_cliente']}'] = result;
    setState(() => _index++);
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= _visits.length)
      return Scaffold(
        appBar: AppBar(title: const Text('Ruta finalizada')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.task_alt, size: 76, color: AppColors.verde),
                const SizedBox(height: 14),
                const Text(
                  'Jornada registrada',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_results.values.where((v) => v == 'Visitado').length} visitados · ${_results.values.where((v) => v == 'No ubicado').length} no ubicados · ${_results.values.where((v) => v == 'Reprogramado').length} reprogramados',
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver a la ruta'),
                ),
              ],
            ),
          ),
        ),
      );
    final point = LatLng(
      (_current['Latitud'] as num).toDouble(),
      (_current['Longitud'] as num).toDouble(),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('Visita ${_index + 1} de ${_visits.length}'),
        backgroundColor: AppColors.verdeDark,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_index + 1) / _visits.length),
          SizedBox(
            height: 310,
            child: FlutterMap(
              options: MapOptions(initialCenter: point, initialZoom: 15),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.rutech',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 54,
                      height: 54,
                      child: const Icon(
                        Icons.location_on,
                        size: 50,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text(
                        '${_current['Prioridad']} · ${_current['Puntaje_prioridad']} puntos',
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_time(_current['Llegada_min'])}–${_time(_current['Salida_min'])}',
                    ),
                  ],
                ),
                Text(
                  '${_current['Nombre_cliente']}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_current['Tipo_gestion']} · ${_current['Direccion_referencial'] ?? 'Ubicación registrada'}',
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _navigate,
                  icon: const Icon(Icons.navigation),
                  label: const Text('Abrir navegación GPS'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _record('Visitado'),
                  icon: const Icon(Icons.check),
                  label: const Text('Registrar visita realizada'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => _record('No ubicado'),
                        child: const Text('No ubicado'),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => _record('Reprogramado'),
                        child: const Text('Reprogramar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
