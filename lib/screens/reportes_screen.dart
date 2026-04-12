import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../database/db_helper.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});
  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _rutas = [];
  final Map<int, List<Map<String, dynamic>>> _visitasPorRuta = {};
  final Set<int> _expandidas = {};

  List<Map<String, dynamic>> _pendientes = [];
  List<Map<String, dynamic>> _cobrados = [];
  bool _verCobrados = false;

  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final rutas = await DBHelper.getRutasEjecutadas();
    final pendientes = await DBHelper.getSeguimientosPendientes();
    final cobrados = await DBHelper.getSeguimientosCobrados();
    setState(() {
      _rutas = rutas;
      _pendientes = pendientes;
      _cobrados = cobrados;
      _cargando = false;
      _visitasPorRuta.clear();
      _expandidas.clear();
    });
  }

  Future<List<Map<String, dynamic>>> _cargarVisitasDeRuta(int rutaId) async {
    if (_visitasPorRuta.containsKey(rutaId)) return _visitasPorRuta[rutaId]!;
    final visitas = await DBHelper.getVisitasDeLaRuta(rutaId);
    _visitasPorRuta[rutaId] = visitas;
    return visitas;
  }

  Future<void> _toggleExpandir(int rutaId) async {
    if (_expandidas.contains(rutaId)) {
      setState(() => _expandidas.remove(rutaId));
    } else {
      final visitas = await _cargarVisitasDeRuta(rutaId);
      setState(() {
        _visitasPorRuta[rutaId] = visitas;
        _expandidas.add(rutaId);
      });
    }
  }

  Future<void> _eliminarRuta(int rutaId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('¿Eliminar ruta?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        content: const Text(
            'Se eliminarán la ruta y todas sus visitas. Esta acción no se puede deshacer.',
            style: TextStyle(fontSize: 13, color: AppColors.text2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await DBHelper.eliminarRuta(rutaId);
      _cargarDatos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ruta eliminada'),
          backgroundColor: AppColors.prioAlta,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _editarVisita(Map<String, dynamic> visita, int rutaId) async {
    final notasCtrl =
    TextEditingController(text: visita['resultado'] as String? ?? '');
    bool? encontrado = _intToBool(visita['encontrado'] as int? ?? -1);
    bool? interesado = _intToBool(visita['interesado'] as int? ?? -1);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text(visita['nombre'] ?? 'Editar visita',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              Text(
                  '${_formatFecha(visita['fecha'] ?? '')} · ${visita['hora'] ?? ''}',
                  style:
                  const TextStyle(fontSize: 11, color: AppColors.text3)),
              const SizedBox(height: 16),
              const Text('¿Encontrado?',
                  style:
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Row(children: [
                _chipEditar('Sí', encontrado == true, AppColors.prioBaja,
                        () => setModal(() => encontrado = true)),
                const SizedBox(width: 8),
                _chipEditar('No', encontrado == false, AppColors.prioAlta,
                        () => setModal(() {
                      encontrado = false;
                      interesado = null;
                    })),
              ]),
              if (encontrado == true) ...[
                const SizedBox(height: 14),
                const Text('¿Interesado?',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(children: [
                  _chipEditar('Sí', interesado == true, AppColors.prioBaja,
                          () => setModal(() => interesado = true)),
                  const SizedBox(width: 8),
                  _chipEditar('No', interesado == false, AppColors.prioAlta,
                          () => setModal(() => interesado = false)),
                ]),
              ],
              const SizedBox(height: 14),
              const Text('Notas',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: notasCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Observaciones...',
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amarillo,
                    foregroundColor: AppColors.verdeDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () async {
                    await DBHelper.actualizarVisita(
                      id: visita['id'] as int,
                      encontrado: encontrado == true
                          ? 1
                          : (encontrado == false ? 0 : -1),
                      interesado: interesado == true
                          ? 1
                          : (interesado == false ? 0 : -1),
                      resultado: notasCtrl.text.trim(),
                    );
                    final nuevas =
                    await DBHelper.getVisitasDeLaRuta(rutaId);
                    setState(() => _visitasPorRuta[rutaId] = nuevas);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Guardar cambios',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  bool? _intToBool(int v) {
    if (v == 1) return true;
    if (v == 0) return false;
    return null;
  }

  // ── Modal seguimiento ────────────────────────────────
  Future<void> _mostrarModalSeguimiento(Map<String, dynamic> seg) async {
    final notasCtrl = TextEditingController(
        text: seg['notas_seguimiento'] as String? ?? '');
    final montoCtrl = TextEditingController(
        text: seg['monto_cobro'] != null
            ? (seg['monto_cobro'] as num).toStringAsFixed(0)
            : '');
    String? fechaCobro;
    bool guardando = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person,
                          color: Color(0xFF1565C0), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(seg['nombre'] ?? '',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                          Text(
                              'Visitado el ${_formatFecha(seg['fecha_visita'] ?? '')}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.text3)),
                        ],
                      ),
                    ),
                  ],
                ),
                if ((seg['notas_visita'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            color: AppColors.text3, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (seg['notas_visita'] as String)
                                .replaceAll(
                                RegExp(r'Punto: .+?(\s*\||\s*$)'), '')
                                .trim(),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.text2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Divider(color: AppColors.border),
                const SizedBox(height: 10),
                const Text('Notas de seguimiento',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: notasCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Acuerdos, próxima visita, observaciones...',
                    hintStyle: const TextStyle(
                        fontSize: 12, color: AppColors.text3),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                        const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                        const BorderSide(color: AppColors.verde)),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 14),
                // Cobro
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.verde.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'Marcar préstamo como cobrado / desembolsado',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.verde)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: montoCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Monto S/.',
                                labelStyle: const TextStyle(
                                    fontSize: 11, color: AppColors.text2),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: AppColors.border)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: AppColors.verde)),
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () async {
                              final fecha = await showDatePicker(
                                context: ctx,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2024),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 30)),
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
                                setModal(() {
                                  fechaCobro = fecha
                                      .toIso8601String()
                                      .substring(0, 10);
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                    color: fechaCobro != null
                                        ? AppColors.verde
                                        : AppColors.border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 14,
                                      color: fechaCobro != null
                                          ? AppColors.verde
                                          : AppColors.text3),
                                  const SizedBox(width: 6),
                                  Text(
                                    fechaCobro != null
                                        ? _formatFecha(fechaCobro!)
                                        : 'Fecha',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: fechaCobro != null
                                            ? AppColors.verde
                                            : AppColors.text3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.prioAlta,
                          side: const BorderSide(color: AppColors.prioAlta),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          await DBHelper.descartarSeguimiento(
                              seg['id'] as int);
                          await _cargarDatos();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('No se convirtió',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.verde,
                          side: const BorderSide(color: AppColors.verde),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          await DBHelper.actualizarNotasSeguimiento(
                            id: seg['id'] as int,
                            notas: notasCtrl.text.trim(),
                          );
                          await _cargarDatos();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Guardar notas',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.verde,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: guardando
                        ? null
                        : () async {
                      setModal(() => guardando = true);
                      await DBHelper.marcarCobrado(
                        id: seg['id'] as int,
                        fechaCobro: fechaCobro ??
                            DateTime.now()
                                .toIso8601String()
                                .substring(0, 10),
                        montoCobro: double.tryParse(montoCtrl.text),
                        notas: notasCtrl.text.trim(),
                      );
                      await _cargarDatos();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('✓ Préstamo cobrado / desembolsado',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _calcularStats() {
    int encEncontrados = 0, encInteresados = 0, encVisitados = 0;
    for (final r in _rutas) {
      encVisitados += (r['visitados'] as int? ?? 0);
      encEncontrados += (r['encontrados'] as int? ?? 0);
      encInteresados += (r['interesados'] as int? ?? 0);
    }
    return {
      'totalRutas': _rutas.length,
      'totalVisitas': encVisitados,
      'encontrados': encEncontrados,
      'interesados': encInteresados,
      'noEncontrados': encVisitados - encEncontrados,
      'noInteresados': encEncontrados - encInteresados,
      'pctContacto': encVisitados > 0
          ? (encEncontrados / encVisitados * 100).toStringAsFixed(0)
          : '0',
      'pctInteres': encEncontrados > 0
          ? (encInteresados / encEncontrados * 100).toStringAsFixed(0)
          : '0',
    };
  }

  // ══════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _buildTopbar(),
          _buildTabs(),
          Expanded(
            child: _cargando
                ? const Center(
                child: CircularProgressIndicator(color: AppColors.verde))
                : TabBarView(
              controller: _tabController,
              children: [
                _buildTabRutas(),
                _buildTabEstadisticas(),
              ],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reportes',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text(
                    '${_rutas.length} ruta${_rutas.length != 1 ? 's' : ''} · ${_pendientes.length} pendientes de seguimiento',
                    style: const TextStyle(
                        color: Color(0xFFA8D5B5), fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _cargarDatos,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: AppColors.verde,
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.amarillo,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle:
        const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Rutas ejecutadas'),
          Tab(text: 'Estadísticas'),
        ],
      ),
    );
  }

  // ─── TAB 1: Rutas ─────────────────────────────────────

  Widget _buildTabRutas() {
    if (_rutas.isEmpty) {
      return _buildVacio('Sin rutas ejecutadas aún',
          'Ejecuta tu primera ruta en la sección "Armar Ruta"', Icons.route);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _rutas.length,
      itemBuilder: (ctx, i) => _buildCardRuta(_rutas[i]),
    );
  }

  Widget _buildCardRuta(Map<String, dynamic> ruta) {
    final rutaId = ruta['id'] as int;
    final expandida = _expandidas.contains(rutaId);
    final fecha = _formatFecha(ruta['fecha'] as String? ?? '');
    final horaInicio = ruta['hora_inicio'] as String? ?? '--:--';
    final horaFin = ruta['hora_fin'] as String? ?? '--:--';
    final totalPuntos = ruta['total_puntos'] as int? ?? 0;
    final visitados = ruta['visitados'] as int? ?? 0;
    final encontrados = ruta['encontrados'] as int? ?? 0;
    final interesados = ruta['interesados'] as int? ?? 0;
    final distancia = ruta['distancia_km'] as double? ?? 0.0;
    final pctContacto = visitados > 0
        ? (encontrados / visitados * 100).toStringAsFixed(0)
        : '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExpandir(rutaId),
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.verdeLt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.route,
                            color: AppColors.verde, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ruta del $fecha',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text)),
                            Text(
                                '$horaInicio → $horaFin · ${distancia.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.text3)),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert,
                            color: AppColors.text3, size: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        onSelected: (val) {
                          if (val == 'eliminar') _eliminarRuta(rutaId);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'eliminar',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    color: AppColors.prioAlta, size: 16),
                                SizedBox(width: 8),
                                Text('Eliminar ruta',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.prioAlta)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      AnimatedRotation(
                        turns: expandida ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down,
                            color: AppColors.text3, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _miniStat('$totalPuntos', 'Paradas', AppColors.text2),
                      _divider(),
                      _miniStat('$visitados', 'Gestión.', AppColors.verde),
                      _divider(),
                      _miniStat(
                          '$encontrados', 'Encontr.', AppColors.prioBaja),
                      _divider(),
                      _miniStat(
                          '$interesados', 'Interes.', const Color(0xFF378ADD)),
                      _divider(),
                      _miniStat(
                          '$pctContacto%', 'Efectiv.', AppColors.prioMedia),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expandida) ...[
            const Divider(height: 1, color: AppColors.border),
            _buildDetalleRuta(rutaId, totalPuntos),
          ],
        ],
      ),
    );
  }

  Widget _buildDetalleRuta(int rutaId, int totalPuntos) {
    final visitas = _visitasPorRuta[rutaId] ?? [];
    if (visitas.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text('Sin visitas registradas en esta ruta',
              style: TextStyle(fontSize: 12, color: AppColors.text3)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Text('DETALLE DE PARADAS',
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text3,
                  letterSpacing: 1)),
        ),
        ...visitas.asMap().entries.map((e) =>
            _buildFilaVisita(e.value, e.key, visitas.length, rutaId)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFilaVisita(
      Map<String, dynamic> v, int idx, int total, int rutaId) {
    final nombre = v['nombre'] as String? ?? 'Cliente';
    final encontrado = v['encontrado'] as int? ?? -1;
    final interesado = v['interesado'] as int? ?? -1;
    final notas = (v['resultado'] as String? ?? '')
        .replaceAll(RegExp(r'Punto: .+?(\s*\||\s*$)'), '')
        .trim();
    final hora = v['hora'] as String? ?? '';
    final esUltimo = idx == total - 1;

    Color iconColor;
    IconData iconData;
    Color bgIcon;
    if (encontrado == 1 && interesado == 1) {
      iconColor = const Color(0xFF378ADD);
      iconData = Icons.thumb_up_outlined;
      bgIcon = const Color(0xFFE3F2FD);
    } else if (encontrado == 1 && interesado == 0) {
      iconColor = AppColors.prioMedia;
      iconData = Icons.thumb_down_outlined;
      bgIcon = const Color(0xFFFFF3E0);
    } else if (encontrado == 1) {
      iconColor = AppColors.prioBaja;
      iconData = Icons.check_circle_outline;
      bgIcon = const Color(0xFFE8F5E9);
    } else if (encontrado == 0) {
      iconColor = AppColors.prioAlta;
      iconData = Icons.person_off_outlined;
      bgIcon = const Color(0xFFFFEBEE);
    } else {
      iconColor = AppColors.text3;
      iconData = Icons.help_outline;
      bgIcon = AppColors.bg;
    }

    return Container(
      decoration: BoxDecoration(
        border: esUltimo
            ? null
            : const Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration:
                  BoxDecoration(color: bgIcon, shape: BoxShape.circle),
                  child: Icon(iconData, color: iconColor, size: 15),
                ),
                if (!esUltimo)
                  Container(width: 1.5, height: 20, color: AppColors.border),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${idx + 1}',
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text3)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(nombre,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (hora.isNotEmpty)
                        Text(hora,
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.text3)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(spacing: 5, runSpacing: 3, children: [
                    if (encontrado == 1)
                      _badge('✓ Encontrado', AppColors.prioBaja),
                    if (encontrado == 0)
                      _badge('✗ No encontrado', AppColors.prioAlta),
                    if (encontrado == 1 && interesado == 1)
                      _badge('✓ Interesado', const Color(0xFF378ADD)),
                    if (encontrado == 1 && interesado == 0)
                      _badge('✗ No interesado', AppColors.prioMedia),
                  ]),
                  if (notas.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(notas,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.text2,
                              fontStyle: FontStyle.italic),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  const SizedBox(height: 6),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _editarVisita(v, rutaId),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.verdeLt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.edit_outlined,
                    color: AppColors.verde, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 2: Estadísticas + Seguimiento ──────────────

  Widget _buildTabEstadisticas() {
    if (_rutas.isEmpty) {
      return _buildVacio('Sin datos aún',
          'Las estadísticas aparecen cuando ejecutes rutas', Icons.bar_chart);
    }

    final stats = _calcularStats();
    final cobrados = _cobrados.length;
    final montoTotal = _cobrados.fold<double>(
        0, (s, c) => s + ((c['monto_cobro'] as num? ?? 0).toDouble()));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Resumen general ──────────────────────────
          const Text('RESUMEN GENERAL',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text3,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(children: [
            _statBox('${stats['totalRutas']}', 'Rutas\nejecutadas',
                AppColors.verde),
            const SizedBox(width: 8),
            _statBox('${stats['totalVisitas']}', 'Total\nvisitas',
                AppColors.text2),
            const SizedBox(width: 8),
            _statBox('${stats['interesados']}', 'Interesados',
                const Color(0xFF378ADD)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _statBox('$cobrados', 'Cobrados/\nDesemb.', AppColors.prioBaja),
            const SizedBox(width: 8),
            _statBox('${_pendientes.length}', 'Pendientes\nseguim.',
                AppColors.prioMedia),
            const SizedBox(width: 8),
            _statBox(
                montoTotal > 0
                    ? 'S/.${(montoTotal / 1000).toStringAsFixed(1)}k'
                    : 'S/.0',
                'Monto\ncobrado',
                AppColors.verdeDark),
          ]),

          const SizedBox(height: 20),

          // ── Efectividad ──────────────────────────────
          const Text('EFECTIVIDAD',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text3,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(children: [
              _metricaFila(
                'Tasa de contacto',
                '${stats['pctContacto']}%',
                (int.tryParse(stats['pctContacto'] as String) ?? 0) / 100,
                AppColors.prioBaja,
              ),
              const SizedBox(height: 14),
              _metricaFila(
                'Interés (sobre encontrados)',
                '${stats['pctInteres']}%',
                (int.tryParse(stats['pctInteres'] as String) ?? 0) / 100,
                const Color(0xFF378ADD),
              ),
              const SizedBox(height: 14),
              _metricaFila(
                'Conversión (interesados/visitas)',
                stats['totalVisitas'] > 0
                    ? '${((stats['interesados'] as int) / (stats['totalVisitas'] as int) * 100).toStringAsFixed(0)}%'
                    : '0%',
                stats['totalVisitas'] > 0
                    ? ((stats['interesados'] as int) /
                    (stats['totalVisitas'] as int))
                    .clamp(0.0, 1.0)
                    : 0.0,
                AppColors.verde,
              ),
              if ((stats['interesados'] as int) > 0) ...[
                const SizedBox(height: 14),
                _metricaFila(
                  'Cierre (cobrados / interesados)',
                  '${(cobrados / (stats['interesados'] as int) * 100).toStringAsFixed(0)}%',
                  (cobrados / (stats['interesados'] as int)).clamp(0.0, 1.0),
                  AppColors.verdeDark,
                ),
              ],
            ]),
          ),

          const SizedBox(height: 20),

          // ── Por ruta ─────────────────────────────────
          const Text('POR RUTA',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text3,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppColors.bg,
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: const Row(children: [
                  Expanded(
                      flex: 3,
                      child: Text('Fecha',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text3))),
                  Expanded(
                      child: Text('Visit.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text3))),
                  Expanded(
                      child: Text('Enc.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text3))),
                  Expanded(
                      child: Text('Int.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text3))),
                ]),
              ),
              ..._rutas.map((r) {
                final fecha = _formatFecha(r['fecha'] as String? ?? '');
                final v = r['visitados'] as int? ?? 0;
                final e = r['encontrados'] as int? ?? 0;
                final i = r['interesados'] as int? ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom:
                        BorderSide(color: AppColors.border, width: 0.5)),
                  ),
                  child: Row(children: [
                    Expanded(
                        flex: 3,
                        child: Text(fecha,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.text))),
                    Expanded(
                        child: Text('$v',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.verde))),
                    Expanded(
                        child: Text('$e',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.prioBaja))),
                    Expanded(
                        child: Text('$i',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF378ADD)))),
                  ]),
                );
              }),
            ]),
          ),

          const SizedBox(height: 24),

          // ══ SEGUIMIENTO DE INTERESADOS ═══════════════
          const Text('SEGUIMIENTO DE INTERESADOS',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text3,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          const Text(
              'Clientes que se interesaron — gestiona su cierre aquí',
              style: TextStyle(fontSize: 10, color: AppColors.text3)),
          const SizedBox(height: 10),

          // Toggle
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _verCobrados = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: !_verCobrados
                        ? const Color(0xFF378ADD)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: !_verCobrados
                            ? const Color(0xFF378ADD)
                            : AppColors.border),
                  ),
                  child: Center(
                    child: Text('Pendientes (${_pendientes.length})',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: !_verCobrados
                                ? Colors.white
                                : AppColors.text2)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _verCobrados = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color:
                    _verCobrados ? AppColors.prioBaja : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _verCobrados
                            ? AppColors.prioBaja
                            : AppColors.border),
                  ),
                  child: Center(
                    child: Text('Cobrados (${_cobrados.length})',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _verCobrados
                                ? Colors.white
                                : AppColors.text2)),
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          // Lista
          Builder(builder: (_) {
            final lista = _verCobrados ? _cobrados : _pendientes;
            if (lista.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        _verCobrados
                            ? Icons.check_circle_outline
                            : Icons.track_changes,
                        color: AppColors.text3,
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _verCobrados
                            ? 'Sin préstamos cobrados aún'
                            : 'Sin interesados pendientes',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.text2),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: lista.map(_buildCardSeguimiento).toList(),
            );
          }),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCardSeguimiento(Map<String, dynamic> seg) {
    final nombre = seg['nombre'] as String? ?? 'Sin nombre';
    final fechaVisita = _formatFecha(seg['fecha_visita'] as String? ?? '');
    final estado = seg['estado'] as String? ?? 'pendiente';
    final notas = seg['notas_seguimiento'] as String? ?? '';
    final notasVisita = (seg['notas_visita'] as String? ?? '')
        .replaceAll(RegExp(r'Punto: .+?(\s*\||\s*$)'), '')
        .trim();
    final esCobrado = estado == 'cobrado';
    final fechaCobro =
    esCobrado ? _formatFecha(seg['fecha_cobro'] as String? ?? '') : null;
    final monto = seg['monto_cobro'] as num?;

    return GestureDetector(
      onTap: esCobrado ? null : () => _mostrarModalSeguimiento(seg),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: esCobrado
                ? AppColors.prioBaja.withOpacity(0.35)
                : const Color(0xFF378ADD).withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: esCobrado
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFE3F2FD),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    esCobrado ? Icons.check_circle : Icons.person_outline,
                    color: esCobrado
                        ? AppColors.prioBaja
                        : const Color(0xFF1565C0),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text)),
                      Text('Visitado el $fechaVisita',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.text3)),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: esCobrado
                        ? AppColors.prioBaja.withOpacity(0.12)
                        : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    esCobrado ? '✓ Cobrado' : 'Pendiente',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: esCobrado
                            ? AppColors.prioBaja
                            : const Color(0xFF1565C0)),
                  ),
                ),
              ]),
              if (esCobrado) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.monetization_on_outlined,
                        color: AppColors.prioBaja, size: 15),
                    const SizedBox(width: 8),
                    Text(
                      monto != null
                          ? 'S/. ${monto.toStringAsFixed(0)} · Cobrado el $fechaCobro'
                          : 'Cobrado el $fechaCobro',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.prioBaja),
                    ),
                  ]),
                ),
              ],
              if (notasVisita.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 12, color: AppColors.text3),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(notasVisita,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.text2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],
              if (notas.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.edit_note,
                          size: 13, color: AppColors.verde),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(notas,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.text2,
                                fontStyle: FontStyle.italic),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              ],
              if (!esCobrado) ...[
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  const Text('Toca para gestionar',
                      style: TextStyle(fontSize: 10, color: AppColors.text3)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      size: 16, color: AppColors.text3),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────

  String _formatFecha(String fecha) {
    if (fecha.isEmpty) return 'Sin fecha';
    try {
      final p = fecha.split('-');
      if (p.length == 3) return '${p[2]}/${p[1]}/${p[0]}';
    } catch (_) {}
    return fecha;
  }

  Widget _buildVacio(String titulo, String subtitulo, IconData icono) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 52, color: AppColors.text3),
            const SizedBox(height: 12),
            Text(titulo,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text2)),
            const SizedBox(height: 6),
            Text(subtitulo,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.text3)),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String valor, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(valor,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 9, color: AppColors.text3)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1,
      height: 28,
      color: AppColors.border,
      margin: const EdgeInsets.symmetric(horizontal: 4));

  Widget _badge(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _statBox(String valor, String label, Color color) {
    return Expanded(
      child: Container(
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
                    fontSize: 19, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 9, color: AppColors.text3, height: 1.3)),
          ],
        ),
      ),
    );
  }

  Widget _metricaFila(
      String label, String valor, double progreso, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.text2))),
            Text(valor,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progreso.clamp(0.0, 1.0),
            backgroundColor: AppColors.bg,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _chipEditar(
      String label, bool sel, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? color : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border:
            Border.all(color: sel ? color : AppColors.border, width: 1.5),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppColors.text2)),
          ),
        ),
      ),
    );
  }
}