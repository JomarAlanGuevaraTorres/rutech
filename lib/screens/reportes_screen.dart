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

  List<Map<String, dynamic>> _visitas = [];
  List<Map<String, dynamic>> _visitasFiltradas = [];
  bool _cargando = true;

  // Filtro seguimiento
  bool _soloInteresados = false;
  bool _soloConPromesa = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => _aplicarFiltros());
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final visitas = await DBHelper.getVisitasConCliente();
    setState(() {
      _visitas = visitas;
      _cargando = false;
    });
    _aplicarFiltros();
    _verificarPromesasVencidas();
  }

  void _aplicarFiltros() {
    final ahora = DateTime.now();
    List<Map<String, dynamic>> resultado = List.from(_visitas);

    // Filtro por período según tab
    resultado = resultado.where((v) {
      final fechaStr = v['fecha'] as String? ?? '';
      if (fechaStr.isEmpty) return false;
      final fecha = DateTime.tryParse(fechaStr);
      if (fecha == null) return false;

      switch (_tabController.index) {
        case 0: // Hoy
          return fecha.year == ahora.year &&
              fecha.month == ahora.month &&
              fecha.day == ahora.day;
        case 1: // Semana
          final inicio = ahora.subtract(Duration(days: ahora.weekday - 1));
          final fin = inicio.add(const Duration(days: 6));
          return fecha.isAfter(inicio.subtract(const Duration(days: 1))) &&
              fecha.isBefore(fin.add(const Duration(days: 1)));
        case 2: // Mes
          return fecha.year == ahora.year && fecha.month == ahora.month;
        default:
          return true;
      }
    }).toList();

    // Filtro interesados
    if (_soloInteresados) {
      resultado =
          resultado.where((v) => (v['interesado'] as int? ?? -1) == 1).toList();
    }

    // Filtro promesa de pago
    if (_soloConPromesa) {
      resultado = resultado
          .where((v) =>
      (v['resultado'] as String? ?? '').isNotEmpty &&
          (v['encontrado'] as int? ?? 0) == 1)
          .toList();
    }

    setState(() => _visitasFiltradas = resultado);
  }

  // ── Verificar promesas vencidas o próximas ──
  void _verificarPromesasVencidas() {
    final hoy = DateTime.now();
    final proximas = _visitas.where((v) {
      final resultado = v['resultado'] as String? ?? '';
      if (resultado.isEmpty) return false;
      // Buscar si tiene formato de fecha dd/mm/yyyy
      final regex = RegExp(r'(\d{2})/(\d{2})/(\d{4})');
      final match = regex.firstMatch(resultado);
      if (match == null) return false;
      final fecha = DateTime(
        int.parse(match.group(3)!),
        int.parse(match.group(2)!),
        int.parse(match.group(1)!),
      );
      final diff = fecha.difference(hoy).inDays;
      return diff >= 0 && diff <= 3; // próximos 3 días
    }).toList();

    if (proximas.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mostrarAlertaPromesas(proximas);
      });
    }
  }

  void _mostrarAlertaPromesas(List<Map<String, dynamic>> proximas) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.prioMedia, size: 22),
            const SizedBox(width: 8),
            Text('${proximas.length} promesa${proximas.length > 1 ? 's' : ''} próxima${proximas.length > 1 ? 's' : ''}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Clientes morosos con promesa de pago en los próximos 3 días:',
                style: TextStyle(fontSize: 12, color: AppColors.text2)),
            const SizedBox(height: 10),
            ...proximas.map((v) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.circle,
                      size: 6, color: AppColors.prioAlta),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      v['nombre'] ?? 'Cliente',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.verde,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ── Estadísticas calculadas ──
  Map<String, dynamic> _calcularStats(List<Map<String, dynamic>> visitas) {
    final total = visitas.length;
    final encontrados =
        visitas.where((v) => (v['encontrado'] as int? ?? 0) == 1).length;
    final noEncontrados = total - encontrados;
    final interesados =
        visitas.where((v) => (v['interesado'] as int? ?? -1) == 1).length;
    final noInteresados =
        visitas.where((v) => (v['interesado'] as int? ?? -1) == 0).length;
    final conPromesa = visitas
        .where((v) =>
    (v['resultado'] as String? ?? '').isNotEmpty &&
        (v['encontrado'] as int? ?? 0) == 1)
        .length;

    final pctEfectividad =
    total > 0 ? (encontrados / total * 100).round() : 0;
    final pctInteres =
    encontrados > 0 ? (interesados / encontrados * 100).round() : 0;

    return {
      'total': total,
      'encontrados': encontrados,
      'noEncontrados': noEncontrados,
      'interesados': interesados,
      'noInteresados': noInteresados,
      'conPromesa': conPromesa,
      'pctEfectividad': pctEfectividad,
      'pctInteres': pctInteres,
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
          _buildFiltrosSeguimiento(),
          Expanded(
            child: _cargando
                ? const Center(
                child:
                CircularProgressIndicator(color: AppColors.verde))
                : _visitasFiltradas.isEmpty
                ? _buildVacio()
                : _buildContenido(),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reportes',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text('Gestión de campo',
                    style: TextStyle(
                        color: Color(0xFFA8D5B5), fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _cargarDatos,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.refresh,
                  color: Colors.white, size: 18),
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
        labelStyle: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Hoy'),
          Tab(text: 'Semana'),
          Tab(text: 'Mes'),
        ],
      ),
    );
  }

  Widget _buildFiltrosSeguimiento() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Text('Filtrar:',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text3)),
          const SizedBox(width: 8),
          _chipFiltro(
            'Interesados',
            _soloInteresados,
            const Color(0xFF378ADD),
                () => setState(() {
              _soloInteresados = !_soloInteresados;
              _aplicarFiltros();
            }),
          ),
          const SizedBox(width: 6),
          _chipFiltro(
            'Con promesa',
            _soloConPromesa,
            AppColors.prioMedia,
                () => setState(() {
              _soloConPromesa = !_soloConPromesa;
              _aplicarFiltros();
            }),
          ),
        ],
      ),
    );
  }

  Widget _chipFiltro(
      String label, bool activo, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: activo ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: activo ? color : AppColors.border, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: activo ? Colors.white : AppColors.text2)),
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart, size: 48, color: AppColors.text3),
          const SizedBox(height: 12),
          const Text('Sin visitas registradas',
              style: TextStyle(color: AppColors.text2, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Las visitas aparecerán aquí al ejecutar rutas',
              style: TextStyle(color: AppColors.text3, fontSize: 12)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() {
              _soloInteresados = false;
              _soloConPromesa = false;
              _aplicarFiltros();
            }),
            child: const Text('Quitar filtros',
                style: TextStyle(color: AppColors.verde)),
          ),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    final stats = _calcularStats(_visitasFiltradas);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Estadísticas ──
          _buildStats(stats),
          const SizedBox(height: 16),

          // ── Métricas detalle ──
          _buildMetricas(stats),
          const SizedBox(height: 16),

          // ── Lista de visitas ──
          const Text('DETALLE DE VISITAS',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text3,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          ..._visitasFiltradas.map((v) => _buildCardVisita(v)),
        ],
      ),
    );
  }

  Widget _buildStats(Map<String, dynamic> stats) {
    return Column(
      children: [
        Row(
          children: [
            _statBox('${stats['total']}', 'Total\ngestionados',
                AppColors.verde),
            const SizedBox(width: 8),
            _statBox('${stats['encontrados']}', 'Encontrados',
                AppColors.prioBaja),
            const SizedBox(width: 8),
            _statBox('${stats['interesados']}', 'Interesados',
                const Color(0xFF378ADD)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _statBox('${stats['noEncontrados']}', 'No\nencontrados',
                AppColors.prioAlta),
            const SizedBox(width: 8),
            _statBox('${stats['noInteresados']}', 'No\ninteresados',
                AppColors.prioMedia),
            const SizedBox(width: 8),
            _statBox('${stats['conPromesa']}', 'Con\npromesa',
                const Color(0xFF9B59B6)),
          ],
        ),
      ],
    );
  }

  Widget _statBox(String valor, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          children: [
            Text(valor,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: color)),
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

  Widget _buildMetricas(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MÉTRICAS',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text3,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          _metricaFila(
            'Efectividad de contacto',
            '${stats['pctEfectividad']}%',
            stats['pctEfectividad'] / 100,
            AppColors.prioBaja,
          ),
          const SizedBox(height: 10),
          _metricaFila(
            'Tasa de interés',
            '${stats['pctInteres']}%',
            stats['pctInteres'] / 100,
            const Color(0xFF378ADD),
          ),
        ],
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
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.text2)),
            Text(valor,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progreso.clamp(0.0, 1.0),
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildCardVisita(Map<String, dynamic> v) {
    final encontrado = (v['encontrado'] as int? ?? 0) == 1;
    final interesado = (v['interesado'] as int? ?? -1) == 1;
    final noInteresado = (v['interesado'] as int? ?? -1) == 0;
    final notas = v['resultado'] as String? ?? '';
    final nombre = v['nombre'] as String? ?? 'Cliente';
    final fecha = v['fecha'] as String? ?? '';
    final hora = v['hora'] as String? ?? '';

    // Detectar si tiene promesa de pago (formato dd/mm/yyyy)
    final tienePromesa =
    RegExp(r'\d{2}/\d{2}/\d{4}').hasMatch(notas);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: interesado
              ? const Color(0xFF378ADD).withOpacity(0.4)
              : tienePromesa
              ? AppColors.prioMedia.withOpacity(0.4)
              : AppColors.border,
          width: interesado || tienePromesa ? 1.5 : 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre y hora
            Row(
              children: [
                Expanded(
                  child: Text(nombre,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                Text('$fecha $hora',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.text3)),
              ],
            ),
            const SizedBox(height: 6),

            // Badges de resultado
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _badge(
                  encontrado ? '✓ Encontrado' : '✗ No encontrado',
                  encontrado ? AppColors.prioBaja : AppColors.prioAlta,
                ),
                if (encontrado && interesado)
                  _badge('✓ Interesado', const Color(0xFF378ADD)),
                if (encontrado && noInteresado)
                  _badge('✗ No interesado', AppColors.prioMedia),
                if (tienePromesa)
                  _badge('📅 Promesa: $notas',
                      const Color(0xFF9B59B6)),
              ],
            ),

            // Notas
            if (notas.isNotEmpty && !tienePromesa) ...[
              const SizedBox(height: 6),
              Text(notas,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.text2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}