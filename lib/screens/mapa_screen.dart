import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/colors.dart';
import '../database/db_helper.dart';
import 'mapa_completo_screen.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});
  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final LatLng _centro = const LatLng(-5.2381, -79.4512);
  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _caserios = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarClientes();
    _cargarCaserios();
  }

  Future<void> _cargarClientes() async {
    final data = await DBHelper.getClientesConUbicacion();
    setState(() {
      _clientes = data;
      _cargando = false;
    });
  }

  Future<void> _cargarCaserios() async {
    final data = await DBHelper.getCaserios();
    setState(() => _caserios = data);
  }

  Color _colorPrioridad(String? p) {
    switch (p) {
      case 'alta':  return AppColors.prioAlta;
      case 'media': return AppColors.prioMedia;
      default:      return AppColors.prioBaja;
    }
  }

  LatLng _ubicacionCliente(Map<String, dynamic> c) {
    if (c['lat_casa'] != null) return LatLng(c['lat_casa'], c['lng_casa']);
    return LatLng(c['lat_negocio'], c['lng_negocio']);
  }

  List<Marker> _buildMarkers() {
    return [
      // Pin oficina
      Marker(
        point: _centro,
        width: 36,
        height: 36,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.verdeDark,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.star, color: AppColors.amarillo, size: 16),
        ),
      ),
      // Pines caseríos sutiles
      ..._caserios.map((c) => Marker(
        point: LatLng(c['lat_centro'], c['lng_centro']),
        width: 8,
        height: 8,
        child: Tooltip(
          message: c['nombre'] ?? '',
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.verde.withOpacity(0.5), width: 1.2),
            ),
          ),
        ),
      )),
      // Pines clientes
      ..._clientes.map((c) => Marker(
        point: _ubicacionCliente(c),
        width: 32,
        height: 32,
        child: GestureDetector(
          onTap: () => _mostrarModal(c),
          child: Container(
            decoration: BoxDecoration(
              color: _colorPrioridad(c['prioridad']),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4)
              ],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 16),
          ),
        ),
      )),
    ];
  }

  void _abrirMapaCompleto() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapaCompletoScreen(
          centro: _centro,
          zoom: 12,
          markers: _buildMarkers(),
          titulo: 'Mapa de Clientes · Huancabamba',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // Topbar
          Container(
            color: AppColors.verde,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mapa de Clientes',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          Text(
                              'Huancabamba · ${_clientes.length} puntos activos',
                              style: const TextStyle(
                                  color: Color(0xFFA8D5B5), fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.amarillo,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Hoy',
                          style: TextStyle(
                              color: Color(0xFF145A25),
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: Colors.white54, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          style:
                          TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Buscar cliente, caserío...',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mapa
          Expanded(
            child: _cargando
                ? const Center(
                child: CircularProgressIndicator(color: AppColors.verde))
                : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _centro,
                    initialZoom: 12,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.rutech.app',
                    ),
                    // Caseríos primero (debajo)
                    MarkerLayer(
                      markers: _caserios.map((c) {
                        return Marker(
                          point: LatLng(
                              c['lat_centro'], c['lng_centro']),
                          width: 8,
                          height: 8,
                          child: Tooltip(
                            message: c['nombre'] ?? '',
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.85),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.verde
                                      .withOpacity(0.5),
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    // Clientes encima
                    MarkerLayer(
                      markers: _clientes.map((c) {
                        return Marker(
                          point: _ubicacionCliente(c),
                          width: 36,
                          height: 36,
                          child: GestureDetector(
                            onTap: () => _mostrarModal(c),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _colorPrioridad(c['prioridad']),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4)
                                ],
                              ),
                              child: const Icon(Icons.person,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                // Botón pantalla completa sobre el mapa
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'refresh',
                        backgroundColor: Colors.white,
                        onPressed: () {
                          _cargarClientes();
                          _cargarCaserios();
                        },
                        child: const Icon(Icons.refresh,
                            color: AppColors.verde),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: 'fullmap',
                        backgroundColor: AppColors.amarillo,
                        onPressed: _abrirMapaCompleto,
                        child: const Icon(Icons.fullscreen,
                            color: AppColors.verdeDark, size: 28),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarModal(Map<String, dynamic> cliente) {
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
            Text(cliente['nombre'] ?? '',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
                '${cliente['tipo'] ?? ''} · ${cliente['caserio'] ?? ''}',
                style: const TextStyle(color: AppColors.text2)),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _colorPrioridad(cliente['prioridad']),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text('Prioridad ${cliente['prioridad'] ?? ''}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.text2)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amarillo,
                  foregroundColor: AppColors.verdeDark,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}