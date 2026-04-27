import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../api/api_service.dart';
import 'login_screen.dart';
import 'registrar_vehiculo_screen.dart';
import 'reportar_incidente_screen.dart';
import 'estado_incidente_screen.dart';
import 'historial_incidentes_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<dynamic>> _vehiculosFuture;
  LatLng? _currentLocation;
  final MapController _mapController = MapController();
  bool _isLoadingGps = true;

  @override
  void initState() {
    super.initState();
    _vehiculosFuture = ApiService.getVehiculos();
    _initMap();
  }

  Future<void> _initMap() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar servicios de ubicación
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Servicios de ubicación deshabilitados')));
      setState(() => _isLoadingGps = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoadingGps = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoadingGps = false);
      return;
    }

    // Obtener la posición
    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _isLoadingGps = false;
    });

    // Centrar mapa
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 15.0);
    }
  }

  void _refreshList() {
    setState(() {
      _vehiculosFuture = ApiService.getVehiculos();
    });
  }

  void _mostrarMisVehiculos() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return FutureBuilder<List<dynamic>>(
          future: _vehiculosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            }

            final vehiculos = snapshot.data ?? [];

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mi Garaje', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.indigo, size: 30),
                        onPressed: () async {
                          Navigator.pop(context); // Cierra el modal temporalmente
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => RegistrarVehiculoScreen()),
                          );
                          if (result == true) _refreshList();
                          if (mounted) _mostrarMisVehiculos(); // Lo reabre
                        },
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: vehiculos.isEmpty
                      ? const Center(child: Text("No tienes vehículos registrados"))
                      : ListView.builder(
                          itemCount: vehiculos.length,
                          itemBuilder: (context, index) {
                            final vehiculo = vehiculos[index];
                            return ListTile(
                              leading: const Icon(Icons.directions_car, color: Colors.indigo),
                              title: Text('${vehiculo['Marca']} ${vehiculo['Modelo']}'),
                              subtitle: Text('Placa: ${vehiculo['Placa']}'),
                            );
                          },
                        ),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _abrirHistorial() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistorialIncidentesScreen(gpsReal: _currentLocation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Rastreo Activo', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Color(0xFF4F46E5)),
            tooltip: 'Mi Perfil',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.indigo),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: () async {
              await ApiService.logout();
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
              }
            },
          )
        ],
      ),
      body: Stack(
        children: [
          // 1. CAPA DE MAPA DE FONDO
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? const LatLng(-17.7833, -63.1821), // Centro por defecto asumiendo Santa Cruz
              initialZoom: 14.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mobile_app',
              ),
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.local_taxi, // Auto icono
                        color: Colors.indigo,
                        size: 45,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 2. CAPA INFORMATIVA O DE CARGA DEL GPS
          if (_isLoadingGps)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                child: const Row(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text("Buscando tu ubicación...", style: TextStyle(fontWeight: FontWeight.bold))
                  ],
                ),
              ),
            ),
          
          // 3. CAPA DE INTERFACES UBER FLOTANTES
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Boton S.O.S Gigante
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final vehiculos = await _vehiculosFuture;
                          if (mounted) {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReportarIncidenteScreen(
                                  vehiculosRegistrados: vehiculos,
                                  gpsReal: _currentLocation, // <-- PASAMOS EL MAPA REAL
                                ),
                              ),
                            );
                            if (result == true) _refreshList();
                          }
                        },
                        icon: const Icon(Icons.warning_amber_rounded, size: 28),
                        label: const Text('S.O.S EMERGENCIA', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Mis vehículos panel
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _mostrarMisVehiculos,
                            icon: const Icon(Icons.garage),
                            label: const Text('Mi Garaje'),
                            style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _abrirHistorial,
                            icon: const Icon(Icons.assignment, color: Colors.orange),
                            label: const Text('Mis Solicitudes'),
                            style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange[800],
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                side: BorderSide(color: Colors.orange.withOpacity(0.5))),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton(
                          mini: true,
                          backgroundColor: Colors.indigo,
                          child: const Icon(Icons.my_location, color: Colors.white),
                          onPressed: () {
                            if (_currentLocation != null) {
                              _mapController.move(_currentLocation!, 16.0);
                            } else {
                              _initMap(); // reintenta
                            }
                          },
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
