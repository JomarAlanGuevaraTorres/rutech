import 'package:flutter/material.dart';
import '../services/rutech_api.dart';
import '../theme/colors.dart';

class PlanificadorScreen extends StatefulWidget {
  const PlanificadorScreen({super.key});

  @override
  State<PlanificadorScreen> createState() => _PlanificadorScreenState();
}

class _PlanificadorScreenState extends State<PlanificadorScreen> {
  final _api = RutechApi();
  List<Map<String, dynamic>> _agencias = [];
  Map<String, dynamic>? _plan;
  String _agencia = 'AG01';
  int _maxVisitas = 15;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    try {
      final agencias = await _api.agencias();
      if (!mounted) return;
      setState(() {
        _agencias = agencias;
        if (agencias.isNotEmpty) _agencia = agencias.first['Codigo'].toString();
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _cargando = false;
      });
    }
  }

  Future<void> _planificar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final plan = await _api.planificar(
        agencia: _agencia,
        maxVisitas: _maxVisitas,
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _cargando = false;
      });
    }
  }

  String _hora(dynamic minutes) {
    final value = (minutes as num?)?.toInt() ?? 0;
    return '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
  }

  Color _priorityColor(String priority) => switch (priority) {
    'P1' => Colors.red.shade700,
    'P2' => Colors.orange.shade700,
    'P3' => Colors.blue.shade700,
    _ => Colors.grey.shade700,
  };

  @override
  Widget build(BuildContext context) {
    final visits = ((_plan?['visitas'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(title: const Text('Planificador prioritario')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _agencia,
                  items: _agencias
                      .map(
                        (item) => DropdownMenuItem(
                          value: item['Codigo'].toString(),
                          child: Text(item['Agencia'].toString()),
                        ),
                      )
                      .toList(),
                  onChanged: _cargando
                      ? null
                      : (value) => setState(() => _agencia = value!),
                ),
                DropdownButton<int>(
                  value: _maxVisitas,
                  items: const [10, 15, 20, 25]
                      .map(
                        (n) => DropdownMenuItem(
                          value: n,
                          child: Text('$n visitas'),
                        ),
                      )
                      .toList(),
                  onChanged: _cargando
                      ? null
                      : (value) => setState(() => _maxVisitas = value!),
                ),
                FilledButton.icon(
                  onPressed: _cargando ? null : _planificar,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generar ruta VRPTW'),
                ),
              ],
            ),
          ),
          if (_cargando) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No se pudo conectar con el servidor Python. $_error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (_plan != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_plan!['metodo']} · ${_plan!['distancia_estimada_km']} km · ${visits.length} visitas',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: visits.length,
              itemBuilder: (context, index) {
                final item = visits[index];
                final priority = item['Prioridad'].toString();
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _priorityColor(priority),
                      foregroundColor: Colors.white,
                      child: Text('${item['Orden']}'),
                    ),
                    title: Text(item['Nombre_cliente'].toString()),
                    subtitle: Text(
                      '${item['Tipo_gestion']} · $priority (${item['Puntaje_prioridad']} puntos)\n${_hora(item['Llegada_min'])} a ${_hora(item['Salida_min'])}',
                    ),
                    trailing: Icon(
                      item['Tipo_gestion'] == 'COBRANZA'
                          ? Icons.payments_outlined
                          : Icons.handshake_outlined,
                      color: AppColors.verde,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
