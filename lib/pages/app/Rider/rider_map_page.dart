import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../mapbox_config.dart';
import '../../../services/rider_service.dart';

class RiderMapPage extends StatefulWidget {
  final RiderGroup group;

  const RiderMapPage({super.key, required this.group});

  @override
  State<RiderMapPage> createState() => _RiderMapPageState();
}

class _RiderMapPageState extends State<RiderMapPage> {
  MapboxMap? _mapboxMap;
  geo.Position? _riderPosition;
  bool _styleLoaded = false;
  bool _loadingRoute = true;
  String? _routeError;
  String? _gpsError;

  // Waypoints en orden: rider → restaurantes → clientes
  List<_Waypoint> get _waypoints {
    final result = <_Waypoint>[];

    if (_riderPosition != null) {
      result.add(_Waypoint(
        lat: _riderPosition!.latitude,
        lng: _riderPosition!.longitude,
        label: 'Tu ubicación',
        type: WaypointType.rider,
      ));
    }

    // Restaurantes únicos (pickup) — solo los que aún no han sido recogidos
    final seen = <String>{};
    for (final order in widget.group.orders) {
      // Si el rider ya recogió este pedido, no necesita pasar por el restaurante
      if (order.status == 'en_camino' || order.status == 'entregado') continue;
      final key = '${order.restaurantLat},${order.restaurantLng}';
      if (!seen.contains(key) && order.restaurantLat != null && order.restaurantLng != null) {
        seen.add(key);
        result.add(_Waypoint(
          lat: order.restaurantLat!,
          lng: order.restaurantLng!,
          label: order.restaurantName,
          type: WaypointType.pickup,
          status: order.status,
        ));
      }
    }

    // Clientes (entrega)
    for (final order in widget.group.orders) {
      if (order.clientLat != null && order.clientLng != null) {
        result.add(_Waypoint(
          lat: order.clientLat!,
          lng: order.clientLng!,
          label: order.clientAddress ?? 'Destino',
          type: WaypointType.delivery,
        ));
      }
    }

    return result;
  }

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.deniedForever) {
        throw Exception('Permiso de ubicación denegado permanentemente');
      }
      // Intenta posición actual; si tarda, usa la última conocida como fallback
      geo.Position? pos;
      try {
        pos = await geo.Geolocator.getCurrentPosition(
          locationSettings: const geo.LocationSettings(accuracy: geo.LocationAccuracy.high),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {
        pos = await geo.Geolocator.getLastKnownPosition();
      }
      if (mounted && pos != null) setState(() => _riderPosition = pos);
    } catch (e) {
      if (mounted) setState(() => _gpsError = e.toString());
    }
    _tryDrawRoute();
  }

  void _tryDrawRoute() {
    if (!_styleLoaded || _mapboxMap == null || !mounted) return;
    if (_waypoints.length >= 2) {
      _drawRoute();
    } else {
      setState(() => _loadingRoute = false);
    }
  }

  Future<void> _drawRoute() async {
    final wps = _waypoints;
    if (wps.length < 2) {
      setState(() { _loadingRoute = false; });
      return;
    }

    try {
      // Construir string de coordenadas para Directions API
      final coords = wps.map((w) => '${w.lng},${w.lat}').join(';');
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/$coords'
        '?geometries=geojson&overview=full&access_token=$mapboxAccessToken',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) throw Exception('Error API: ${response.statusCode}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;

      if (routes != null && routes.isNotEmpty) {
        final geometry = routes[0]['geometry'] as Map<String, dynamic>;
        final coordinates = (geometry['coordinates'] as List)
            .map((c) => [(c as List)[0] as double, c[1] as double])
            .toList();
        await _addRouteToMap(coordinates, wps);
      } else {
        // Sin ruta conducible — igual muestra los marcadores
        await _addMarkersOnly(wps);
      }
      if (mounted) setState(() => _loadingRoute = false);
    } catch (e) {
      // Error de red u otro — igual muestra marcadores
      await _addMarkersOnly(wps);
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  /// Crea un bitmap circular de 56×56 px con el número centrado.
  /// Rider → azul, pickup → rojo (primary), delivery → naranja.
  Future<Uint8List> _createMarkerImage(Color color, int number) async {
    const size = 56.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Sombra
    canvas.drawCircle(
      const ui.Offset(size / 2, size / 2 + 2),
      size / 2 - 2,
      ui.Paint()..color = const Color(0x44000000),
    );

    // Relleno
    canvas.drawCircle(
      const ui.Offset(size / 2, size / 2),
      size / 2 - 2,
      ui.Paint()..color = color,
    );

    // Borde blanco
    canvas.drawCircle(
      const ui.Offset(size / 2, size / 2),
      size / 2 - 2,
      ui.Paint()
        ..color = Colors.white
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Número
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 20,
        fontWeight: ui.FontWeight.w700,
      ),
    )
      ..pushStyle(ui.TextStyle(color: Colors.white))
      ..addText('$number');
    final para = builder.build()
      ..layout(const ui.ParagraphConstraints(width: size));
    canvas.drawParagraph(
      para,
      ui.Offset(0, (size - para.height) / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _addMarkersOnly(List<_Waypoint> wps) async {
    final map = _mapboxMap;
    if (map == null) return;
    await _placeMarkers(map, wps);
    await _fitCamera(map, wps);
  }

  Future<void> _addRouteToMap(List<List<double>> routeCoords, List<_Waypoint> wps) async {
    final map = _mapboxMap;
    if (map == null) return;

    // Línea de ruta
    final routeGeoJson = jsonEncode({
      'type': 'Feature',
      'geometry': {'type': 'LineString', 'coordinates': routeCoords},
      'properties': {},
    });

    await map.style.addSource(GeoJsonSource(id: 'route-source', data: routeGeoJson));
    await map.style.addLayer(LineLayer(
      id: 'route-layer',
      sourceId: 'route-source',
      lineColor: const Color(0xFF1565C0).toARGB32(),
      lineWidth: 5.0,
      lineOpacity: 0.85,
      lineCap: LineCap.ROUND,
      lineJoin: LineJoin.ROUND,
    ));

    await _placeMarkers(map, wps);
    await _fitCamera(map, wps);
  }

  Future<void> _placeMarkers(MapboxMap map, List<_Waypoint> wps) async {
    final annotationManager = await map.annotations.createPointAnnotationManager();
    for (int i = 0; i < wps.length; i++) {
      final wp = wps[i];
      final color = switch (wp.type) {
        WaypointType.rider    => const Color(0xFF1565C0),
        WaypointType.pickup   => const Color(0xFFE53935),
        WaypointType.delivery => const Color(0xFFFF8F00),
      };
      final markerImage = await _createMarkerImage(color, i + 1);
      await annotationManager.create(PointAnnotationOptions(
        geometry: Point(coordinates: Position(wp.lng, wp.lat)),
        image: markerImage,
        iconSize: 1.0,
      ));
    }
  }

  Future<void> _fitCamera(MapboxMap map, List<_Waypoint> wps) async {
    final points = wps.map((w) => Point(coordinates: Position(w.lng, w.lat))).toList();
    final camera = await map.cameraForCoordinatesPadding(
      points,
      CameraOptions(),
      MbxEdgeInsets(top: 80, left: 40, bottom: 200, right: 40),
      null,
      null,
    );
    await map.flyTo(camera, MapAnimationOptions(duration: 1000));
  }

  void _onMapCreated(MapboxMap map) {
    _mapboxMap = map;
  }

  void _onStyleLoaded(StyleLoadedEventData _) {
    _styleLoaded = true;
    _tryDrawRoute();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wps = _waypoints;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MapWidget(
            onMapCreated: _onMapCreated,
            onStyleLoadedListener: _onStyleLoaded,
            cameraOptions: CameraOptions(
              center: Point(coordinates: wps.isNotEmpty
                  ? Position(wps.first.lng, wps.first.lat)
                  : Position(-68.15, -16.50)),
              zoom: 13,
            ),
          ),

          // Botón volver
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                ),
                child: const Icon(Icons.arrow_back, size: 22),
              ),
            ),
          ),

          // Loading overlay
          if (_loadingRoute)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 8),
                      const Text('Calculando ruta...', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),

          // Panel inferior con paradas
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                top: 12,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ruta de entrega',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (_gpsError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.location_off, size: 14, color: Colors.orange),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Sin ubicación GPS — el marcador de tu posición no aparece',
                              style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_routeError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Sin ruta: $_routeError',
                        style: const TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  if (!_loadingRoute && _routeError == null && wps.length < 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'La orden no tiene coordenadas de entrega. '
                              'El cliente debe agregar una dirección con ubicación al pedir.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: wps.where((w) => w.type != WaypointType.rider).length,
                      separatorBuilder: (_, __) => Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Container(height: 20, width: 2, color: Colors.grey.shade200),
                      ),
                      itemBuilder: (_, i) {
                        final wp = wps.where((w) => w.type != WaypointType.rider).toList()[i];
                        final labelColor = wp.type == WaypointType.pickup
                            ? theme.colorScheme.primary
                            : Colors.orange[700];
                        // +2 porque el marcador 1 en el mapa es siempre el rider
                        final markerIndex = _riderPosition != null ? i + 2 : i + 1;
                        return Row(
                          children: [
                            _WaypointDot(index: markerIndex, type: wp.type),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    wp.type == WaypointType.pickup
                                        ? 'Recoger: ${wp.label}'
                                        : 'Entregar: ${wp.label}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: labelColor,
                                    ),
                                  ),
                                  if (wp.type == WaypointType.pickup && wp.status != null)
                                    _MapPrepBadge(status: wp.status!),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum WaypointType { rider, pickup, delivery }

class _Waypoint {
  final double lat;
  final double lng;
  final String label;
  final WaypointType type;
  final String? status; // order preparation status (pickup waypoints only)
  const _Waypoint({required this.lat, required this.lng, required this.label, required this.type, this.status});
}

class _MapPrepBadge extends StatelessWidget {
  final String status;
  const _MapPrepBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'listo'      => ('✓ Listo para recoger', Colors.green.shade700),
      'preparando' => ('⏱ Preparando...', Colors.orange.shade700),
      'en_camino'  => ('En camino', Colors.blue.shade700),
      'confirmado' => ('Confirmado', Colors.blue.shade400),
      _            => ('Pendiente', Colors.grey.shade500),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

class _WaypointDot extends StatelessWidget {
  final int index;
  final WaypointType type;
  const _WaypointDot({required this.index, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = type == WaypointType.rider
        ? Colors.grey[600]!
        : type == WaypointType.pickup
            ? Theme.of(context).colorScheme.primary
            : Colors.orange[700]!;

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(
          '$index',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
