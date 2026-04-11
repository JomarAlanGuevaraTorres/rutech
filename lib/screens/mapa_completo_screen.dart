import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/colors.dart';

class MapaCompletoScreen extends StatefulWidget {
  final LatLng centro;
  final double zoom;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final String titulo;

  const MapaCompletoScreen({
    super.key,
    required this.centro,
    required this.markers,
    this.polylines = const [],
    this.zoom = 12,
    this.titulo = 'Mapa',
  });

  @override
  State<MapaCompletoScreen> createState() => _MapaCompletoScreenState();
}

class _MapaCompletoScreenState extends State<MapaCompletoScreen> {
  final MapController _mapController = MapController();
  final _buscarController = TextEditingController();
  bool _mostrarBusqueda = false;

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa completo
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.centro,
              initialZoom: widget.zoom,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.rutech.app',
              ),
              if (widget.polylines.isNotEmpty)
                PolylineLayer(polylines: widget.polylines),
              MarkerLayer(markers: widget.markers),
            ],
          ),

          // Topbar transparente
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 48, 8, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Botón regresar
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 4)
                        ],
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: AppColors.verdeDark, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Título
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 4)
                        ],
                      ),
                      child: Text(widget.titulo,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.verdeDark)),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Botón buscar
                  GestureDetector(
                    onTap: () =>
                        setState(() => _mostrarBusqueda = !_mostrarBusqueda),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 4)
                        ],
                      ),
                      child: Icon(
                          _mostrarBusqueda ? Icons.close : Icons.search,
                          color: AppColors.verdeDark,
                          size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Barra de búsqueda expandida
          if (_mostrarBusqueda)
            Positioned(
              top: 110,
              left: 12,
              right: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 8)
                  ],
                ),
                child: TextField(
                  controller: _buscarController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Buscar cliente o caserío...',
                    hintStyle:
                    TextStyle(fontSize: 13, color: AppColors.text3),
                    prefixIcon: Icon(Icons.search,
                        color: AppColors.text3, size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  onChanged: (v) {
                    // Buscar en los markers por nombre
                    // Por ahora solo cierra al escribir
                  },
                ),
              ),
            ),

          // Controles de zoom
          Positioned(
            right: 12,
            bottom: 100,
            child: Column(
              children: [
                _botonMapa(
                  icon: Icons.add,
                  onTap: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(
                        _mapController.camera.center, zoom + 1);
                  },
                ),
                const SizedBox(height: 8),
                _botonMapa(
                  icon: Icons.remove,
                  onTap: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(
                        _mapController.camera.center, zoom - 1);
                  },
                ),
                const SizedBox(height: 8),
                _botonMapa(
                  icon: Icons.my_location,
                  onTap: () {
                    _mapController.move(widget.centro, widget.zoom);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonMapa({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15), blurRadius: 4)
          ],
        ),
        child: Icon(icon, color: AppColors.verdeDark, size: 20),
      ),
    );
  }
}