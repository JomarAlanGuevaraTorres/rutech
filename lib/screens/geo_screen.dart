import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/colors.dart';
import '../database/db_helper.dart';

class GeoScreen extends StatefulWidget {
  const GeoScreen({super.key});
  @override
  State<GeoScreen> createState() => _GeoScreenState();
}

class _GeoScreenState extends State<GeoScreen> {
  // ── Estado GPS ──
  double? _lat;
  double? _lng;
  double? _precision;
  String _horaActualizacion = '--:--:--';
  bool _gpsActivo = false;
  bool _obteniendo = false;

  // ── Formulario ──
  final _dniController = TextEditingController();
  String _tipoUbicacion = 'casa';
  Map<String, dynamic>? _clienteEncontrado;
  bool _buscando = false;
  bool _guardando = false;
  String _mensajeEstado = '';

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
  }

  @override
  void dispose() {
    _dniController.dispose();
    super.dispose();
  }

  Future<void> _obtenerUbicacion() async {
    setState(() => _obteniendo = true);

    // Verificar permisos
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        setState(() {
          _mensajeEstado = 'Permiso de ubicación denegado';
          _obteniendo = false;
        });
        return;
      }
    }
    if (permiso == LocationPermission.deniedForever) {
      setState(() {
        _mensajeEstado = 'Activa la ubicación en ajustes del celular';
        _obteniendo = false;
      });
      return;
    }

    try {
      // Alta precisión — GPS puro, funciona sin internet
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final hora = TimeOfDay.now();
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _precision = pos.accuracy;
        _horaActualizacion =
        '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
        _gpsActivo = true;
        _obteniendo = false;
        _mensajeEstado = '';
      });
    } catch (e) {
      // Si falla intenta precisión media (usa red si hay señal)
      try {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
        final hora = TimeOfDay.now();
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _precision = pos.accuracy;
          _horaActualizacion =
          '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
          _gpsActivo = true;
          _obteniendo = false;
          _mensajeEstado = 'Usando señal disponible';
        });
      } catch (e2) {
        setState(() {
          _mensajeEstado = 'No se pudo obtener ubicación';
          _gpsActivo = false;
          _obteniendo = false;
        });
      }
    }
  }

  Future<void> _buscarCliente() async {
    final dni = _dniController.text.trim();
    if (dni.isEmpty) return;

    setState(() {
      _buscando = true;
      _clienteEncontrado = null;
      _mensajeEstado = '';
    });

    final cliente = await DBHelper.buscarClientePorDni(dni);

    setState(() {
      _buscando = false;
      if (cliente != null) {
        _clienteEncontrado = cliente;
        _mensajeEstado = '';
      } else {
        // No existe → lo registramos solo con el DNI
        _clienteEncontrado = {'dni': dni, 'nombre': 'DNI: $dni', 'esNuevo': true};
        _mensajeEstado = 'Cliente nuevo — se registrará con este DNI';
      }
    });
  }

  Future<void> _guardarGeolocalizacion() async {
    if (_lat == null || _lng == null) {
      _mostrarSnack('Primero obtén tu ubicación GPS', error: true);
      return;
    }
    if (_clienteEncontrado == null) {
      _mostrarSnack('Busca un DNI primero', error: true);
      return;
    }

    setState(() => _guardando = true);

    final esNuevo = _clienteEncontrado!['esNuevo'] == true;

    if (esNuevo) {
      // Registra solo el DNI con coordenadas — el resto llega del banco después
      final ahora = DateTime.now().toIso8601String().substring(0, 10);
      await DBHelper.insertCliente({
        'dni': _clienteEncontrado!['dni'],
        'nombre': _clienteEncontrado!['dni'], // temporal hasta que llegue del banco
        'lat_casa': _tipoUbicacion != 'negocio' ? _lat : null,
        'lng_casa': _tipoUbicacion != 'negocio' ? _lng : null,
        'lat_negocio': _tipoUbicacion != 'casa' ? _lat : null,
        'lng_negocio': _tipoUbicacion != 'casa' ? _lng : null,
        'tipo_ubicacion': _tipoUbicacion,
        'creado_en': ahora,
      });
    } else {
      // Cliente existente → actualiza coordenadas
      await DBHelper.updateUbicacionCliente(
        id: _clienteEncontrado!['id'],
        lat: _lat!,
        lng: _lng!,
        tipoUbicacion: _tipoUbicacion,
      );
    }

    setState(() {
      _guardando = false;
      _clienteEncontrado = null;
      _dniController.clear();
      _tipoUbicacion = 'casa';
      _mensajeEstado = '';
    });

    _mostrarSnack(esNuevo
        ? '✓ DNI registrado con ubicación'
        : '✓ Ubicación actualizada correctamente');
  }
  void _mostrarSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.prioAlta : AppColors.verde,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
  // ── UI ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _buildTopbar(),
          _buildGpsStatus(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardPosicion(),
                  const SizedBox(height: 12),
                  _buildBotonActualizar(),
                  const SizedBox(height: 20),
                  _buildSeccionGuardar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Topbar
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
                Text('Geolocalización',
                    style: TextStyle(color: Colors.white,
                        fontSize: 16, fontWeight: FontWeight.w600)),
                Text('Posición en tiempo real',
                    style: TextStyle(color: Color(0xFFA8D5B5), fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _obtenerUbicacion,
            child: Container(
              width: 36, height: 36,
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

  // Bloque GPS activo con animación de pulso
  Widget _buildGpsStatus() {
    return Container(
      color: AppColors.verde,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          // Círculo animado
          _obteniendo
              ? const SizedBox(
              width: 64, height: 64,
              child: CircularProgressIndicator(
                  color: AppColors.amarillo, strokeWidth: 3))
              : Stack(
            alignment: Alignment.center,
            children: [
              // Anillos decorativos
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.amarillo.withOpacity(0.3),
                      width: 1.5),
                ),
              ),
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.amarillo.withOpacity(0.15),
                      width: 1),
                ),
              ),
              // Círculo central
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.amarillo.withOpacity(0.2),
                ),
                child: Icon(
                  _gpsActivo
                      ? Icons.my_location
                      : Icons.location_off,
                  color: AppColors.amarillo,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _obteniendo
                ? 'Obteniendo ubicación...'
                : _gpsActivo
                ? 'GPS Activo'
                : 'GPS Inactivo',
            style: const TextStyle(color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            _mensajeEstado.isNotEmpty
                ? _mensajeEstado
                : _gpsActivo
                ? 'Señal disponible · Huancabamba'
                : 'Toca actualizar para obtener señal',
            style: const TextStyle(
                color: Color(0xFFA8D5B5), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // Card con las coordenadas actuales
  Widget _buildCardPosicion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TU POSICIÓN ACTUAL',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.verde, letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            children: [
              _coordRow('Latitud',
                  _lat != null ? _lat!.toStringAsFixed(6) : '---'),
              _coordRow('Longitud',
                  _lng != null ? _lng!.toStringAsFixed(6) : '---'),
              _coordRow('Precisión',
                  _precision != null
                      ? '±${_precision!.toStringAsFixed(0)} m'
                      : '---'),
              _coordRow('Actualizado', _horaActualizacion,
                  ultimo: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coordRow(String label, String valor, {bool ultimo = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: ultimo
            ? null
            : const Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.text2)),
          Text(valor,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.verde,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }

  // Botón actualizar ubicación
  Widget _buildBotonActualizar() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.verde,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: _obteniendo ? null : _obtenerUbicacion,
        icon: _obteniendo
            ? const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.gps_fixed),
        label: Text(_obteniendo
            ? 'Obteniendo...'
            : 'Actualizar ubicación al lugar actual'),
      ),
    );
  }

  // Sección guardar geolocalización
  Widget _buildSeccionGuardar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('GUARDAR GEOLOCALIZACIÓN',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                color: AppColors.verde, letterSpacing: 1)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Campo DNI + botón buscar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _dniController,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      decoration: InputDecoration(
                        labelText: 'DNI del cliente',
                        labelStyle:
                        const TextStyle(fontSize: 12, color: AppColors.text2),
                        counterText: '',
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
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.verde,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _buscando ? null : _buscarCliente,
                    child: _buscando
                        ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Text('Buscar'),
                  ),
                ],
              ),

              // Cliente encontrado
              if (_clienteEncontrado != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.verdeLt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person,
                          color: AppColors.verde, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_clienteEncontrado!['nombre'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text(
                                '${_clienteEncontrado!['tipo'] ?? ''} · ${_clienteEncontrado!['caserio'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.text2)),
                          ],
                        ),
                      ),
                      // Indicador si ya tiene ubicación
                      if (_clienteEncontrado!['lat_casa'] != null ||
                          _clienteEncontrado!['lat_negocio'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.verde,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Ya tiene GPS',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 9,
                                  fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
              ],

              // Mensaje error búsqueda
              if (_mensajeEstado.isNotEmpty &&
                  _clienteEncontrado == null) ...[
                const SizedBox(height: 8),
                Text(_mensajeEstado,
                    style: const TextStyle(
                        color: AppColors.prioAlta, fontSize: 12)),
              ],

              const SizedBox(height: 14),

              // Tipo de ubicación
              const Text('Tipo de ubicación',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text2)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _radioTipo('casa', 'Casa'),
                  const SizedBox(width: 8),
                  _radioTipo('negocio', 'Negocio'),
                  const SizedBox(width: 8),
                  _radioTipo('casa y negocio', 'Ambos'),
                ],
              ),

              const SizedBox(height: 14),

              // Coordenadas que se guardarán
              if (_lat != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('LAT',
                              style: TextStyle(
                                  fontSize: 9, color: AppColors.text3,
                                  fontWeight: FontWeight.w600)),
                          Text(_lat!.toStringAsFixed(6),
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.verde,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('LNG',
                              style: TextStyle(
                                  fontSize: 9, color: AppColors.text3,
                                  fontWeight: FontWeight.w600)),
                          Text(_lng!.toStringAsFixed(6),
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.verde,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('PRECISIÓN',
                              style: TextStyle(
                                  fontSize: 9, color: AppColors.text3,
                                  fontWeight: FontWeight.w600)),
                          Text('±${_precision?.toStringAsFixed(0) ?? '?'} m',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.verde,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 14),

              // Botón guardar
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
                  onPressed: (_guardando ||
                      _clienteEncontrado == null ||
                      _lat == null)
                      ? null
                      : _guardarGeolocalizacion,
                  child: _guardando
                      ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          color: AppColors.verdeDark, strokeWidth: 2))
                      : const Text('Guardar Geolocalización',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _radioTipo(String valor, String etiqueta) {
    final seleccionado = _tipoUbicacion == valor;
    return GestureDetector(
      onTap: () => setState(() => _tipoUbicacion = valor),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: seleccionado ? AppColors.verde : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: seleccionado ? AppColors.verde : AppColors.border,
              width: 1.5),
        ),
        child: Text(etiqueta,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: seleccionado ? Colors.white : AppColors.text2)),
      ),
    );
  }
}