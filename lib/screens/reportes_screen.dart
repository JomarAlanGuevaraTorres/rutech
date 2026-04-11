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
  // mapa rutaId → lista de visitas
  final Map<int, List<Map<String, dynamic>>> _visitasPorRuta = {};
  // qué rutas están expandidas
  final Set<int> _expandidas = {};
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
    setState(() {
      _rutas = rutas;
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
              Text('${_formatFecha(visita['fecha'] ?? '')} · ${visita['hora'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.text3)),
              const SizedBox(height: 16),
              const Text('¿Encontrado?',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
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
                  hintStyle: const TextStyle(
                      fontSize: 12, color: AppColors.text3),
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
                      encontrado: encontrado == true ? 1 : (encontrado == false ? 0 : -1),
                      interesado: interesado == true ? 1 : (interesado == false ? 0 : -1),
                      resultado: notasCtrl.text.trim(),
                    );
                    // Recargar visitas de esa ruta
                    final nuevas = await DBHelper.getVisitasDeLaRuta(rutaId);
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

  // ── Estadísticas globales de todas las rutas ──
  Map<String, dynamic> _calcularStats() {
    int totalVisitas = 0, encontrados = 0, interesados = 0;
    for (final visitas in _visitasPorRuta.values) {
      totalVisitas += visitas.length;
      encontrados += visitas.where((v) => (v['encontrado'] as int? ?? -1) == 1).length;
      interesados += visitas.where((v) => (v['interesado'] as int? ?? -1) == 1).length;
    }

    // Si hay rutas sin cargar, usar totales del encabezado
    int encEncontrados = 0, encInteresados = 0, encVisitados = 0;
    for (final r in _rutas) {
      encVisitados += (r['visitados'] as int? ?? 0);
      encEncontrados += (r['encontrados'] as int? ?? 0);
      encInteresados += (r['interesados'] as int? ?? 0);
    }

    final totalGlobal = encVisitados > 0 ? encVisitados : totalVisitas;
    final encG = encEncontrados > 0 ? encEncontrados : encontrados;
    final intG = encInteresados > 0 ? encInteresados : interesados;

    return {
      'totalRutas': _rutas.length,
      'totalVisitas': totalGlobal,
      'encontrados': encG,
      'noEncontrados': totalGlobal - encG,
      'interesados': intG,
      'noInteresados': encG - intG,
      'pctContacto': totalGlobal > 0 ? (encG / totalGlobal * 100).toStringAsFixed(0) : '0',
      'pctInteres': encG > 0 ? (intG / encG * 100).toStringAsFixed(0) : '0',
    };
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
                    '${_rutas.length} ruta${_rutas.length != 1 ? 's' : ''} ejecutada${_rutas.length != 1 ? 's' : ''}',
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

  // ─── TAB 1: Rutas ejecutadas ─────────────────────────

  Widget _buildTabRutas() {
    if (_rutas.isEmpty) {
      return _buildVacio(
        'Sin rutas ejecutadas aún',
        'Ejecuta tu primera ruta en la sección "Armar Ruta"',
        Icons.route,
      );
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
          // ── Encabezado de la ruta ──
          InkWell(
            onTap: () => _toggleExpandir(rutaId),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Ícono ruta
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
                            Text('$horaInicio → $horaFin · ${distancia.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.text3)),
                          ],
                        ),
                      ),
                      // Menú eliminar
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
                      // Flecha expandir
                      AnimatedRotation(
                        turns: expandida ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down,
                            color: AppColors.text3, size: 22),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Stats horizontales
                  Row(
                    children: [
                      _miniStat('$totalPuntos', 'Paradas', AppColors.text2),
                      _divider(),
                      _miniStat('$visitados', 'Gestión.', AppColors.verde),
                      _divider(),
                      _miniStat('$encontrados', 'Encontr.', AppColors.prioBaja),
                      _divider(),
                      _miniStat('$interesados', 'Interes.', const Color(0xFF378ADD)),
                      _divider(),
                      _miniStat('$pctContacto%', 'Efectiv.', AppColors.prioMedia),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Detalle expandible ──
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
        ...visitas.asMap().entries.map((e) {
          final idx = e.key;
          final v = e.value;
          return _buildFilaVisita(v, idx, visitas.length, rutaId);
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFilaVisita(
      Map<String, dynamic> v, int idx, int total, int rutaId) {
    final nombre = v['nombre'] as String? ?? 'Cliente';
    final encontrado = v['encontrado'] as int? ?? -1;
    final interesado = v['interesado'] as int? ?? -1;
    final notas = v['resultado'] as String? ?? '';
    final hora = v['hora'] as String? ?? '';
    final esUltimo = idx == total - 1;

    // Colores según resultado
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
            // Número + línea de tiempo
            Column(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: bgIcon,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: iconColor, size: 15),
                ),
                if (!esUltimo)
                  Container(
                      width: 1.5, height: 20,
                      color: AppColors.border),
              ],
            ),
            const SizedBox(width: 12),

            // Info principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Número + nombre + hora
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

                  // Badges resultado
                  Wrap(
                    spacing: 5,
                    runSpacing: 3,
                    children: [
                      if (encontrado == 1)
                        _badge('✓ Encontrado', AppColors.prioBaja),
                      if (encontrado == 0)
                        _badge('✗ No encontrado', AppColors.prioAlta),
                      if (encontrado == 1 && interesado == 1)
                        _badge('✓ Interesado', const Color(0xFF378ADD)),
                      if (encontrado == 1 && interesado == 0)
                        _badge('✗ No interesado', AppColors.prioMedia),
                    ],
                  ),

                  // Notas
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

            // Botón editar
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

  // ─── TAB 2: Estadísticas ─────────────────────────────

  Widget _buildTabEstadisticas() {
    if (_rutas.isEmpty) {
      return _buildVacio(
          'Sin datos aún',
          'Las estadísticas aparecen cuando ejecutes rutas',
          Icons.bar_chart);
    }

    final stats = _calcularStats();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen general
          const Text('RESUMEN GENERAL',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text3,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(
            children: [
              _statBox('${stats['totalRutas']}', 'Rutas\nejecutadas',
                  AppColors.verde),
              const SizedBox(width: 8),
              _statBox('${stats['totalVisitas']}', 'Total\nvisitas',
                  AppColors.text2),
              const SizedBox(width: 8),
              _statBox('${stats['interesados']}', 'Total\ninteresados',
                  const Color(0xFF378ADD)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _statBox('${stats['encontrados']}', 'Encontrados',
                  AppColors.prioBaja),
              const SizedBox(width: 8),
              _statBox('${stats['noEncontrados']}', 'No\nencontrados',
                  AppColors.prioAlta),
              const SizedBox(width: 8),
              _statBox('${stats['noInteresados']}', 'No\ninteresados',
                  AppColors.prioMedia),
            ],
          ),

          const SizedBox(height: 20),

          // Efectividad
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
            child: Column(
              children: [
                _metricaFila(
                  'Tasa de contacto',
                  '${stats['pctContacto']}%',
                  (int.tryParse(stats['pctContacto'] as String) ?? 0) / 100,
                  AppColors.prioBaja,
                ),
                const SizedBox(height: 14),
                _metricaFila(
                  'Tasa de interés (sobre encontrados)',
                  '${stats['pctInteres']}%',
                  (int.tryParse(stats['pctInteres'] as String) ?? 0) / 100,
                  const Color(0xFF378ADD),
                ),
                const SizedBox(height: 14),
                _metricaFila(
                  'Conversión total (interesados/visitas)',
                  stats['totalVisitas'] > 0
                      ? '${(stats['interesados'] / stats['totalVisitas'] * 100).toStringAsFixed(0)}%'
                      : '0%',
                  stats['totalVisitas'] > 0
                      ? (stats['interesados'] / stats['totalVisitas'])
                      .clamp(0.0, 1.0)
                      : 0.0,
                  AppColors.verde,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Rendimiento por ruta
          const Text('RENDIMIENTO POR RUTA',
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
            child: Column(
              children: [
                // Cabecera tabla
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.bg,
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text('Fecha',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text3))),
                      Expanded(
                          child: Text('Visitas',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text3))),
                      Expanded(
                          child: Text('Encont.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text3))),
                      Expanded(
                          child: Text('Interes.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text3))),
                    ],
                  ),
                ),
                ..._rutas.map((r) {
                  final fecha = _formatFecha(r['fecha'] as String? ?? '');
                  final visitados = r['visitados'] as int? ?? 0;
                  final encontrados = r['encontrados'] as int? ?? 0;
                  final interesados = r['interesados'] as int? ?? 0;
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
                        Expanded(
                            flex: 3,
                            child: Text(fecha,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.text))),
                        Expanded(
                            child: Text('$visitados',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.verde))),
                        Expanded(
                            child: Text('$encontrados',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.prioBaja))),
                        Expanded(
                            child: Text('$interesados',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF378ADD)))),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Distribución
          const Text('DISTRIBUCIÓN DE RESULTADOS',
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
            child: Column(
              children: [
                _distribucionFila('Encontrado + Interesado',
                    stats['interesados'] as int,
                    stats['totalVisitas'] as int,
                    const Color(0xFF378ADD)),
                const SizedBox(height: 10),
                _distribucionFila('Encontrado + No interesado',
                    stats['noInteresados'] as int,
                    stats['totalVisitas'] as int,
                    AppColors.prioMedia),
                const SizedBox(height: 10),
                _distribucionFila('No encontrado',
                    stats['noEncontrados'] as int,
                    stats['totalVisitas'] as int,
                    AppColors.prioAlta),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
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
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(label,
              style: const TextStyle(fontSize: 9, color: AppColors.text3)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 28, color: AppColors.border,
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
                    fontSize: 22, fontWeight: FontWeight.w700, color: color)),
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
                      fontSize: 12, color: AppColors.text2)),
            ),
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

  Widget _distribucionFila(
      String label, int valor, int total, Color color) {
    final pct = total > 0 ? valor / total : 0.0;
    return Row(
      children: [
        Container(
            width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.text2))),
        Text('$valor',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 6),
        Text('(${(pct * 100).toStringAsFixed(0)}%)',
            style: const TextStyle(fontSize: 11, color: AppColors.text3)),
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