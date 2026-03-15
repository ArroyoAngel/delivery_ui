import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

typedef PickedLocation = ({double latitude, double longitude});

class LocationPickerPage extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  MapboxMap? _mapboxMap;
  bool _isReady = false;
  bool _isLocating = false;

  // Santa Cruz de la Sierra, Bolivia (default center)
  static final Position _defaultCenter = Position(-63.1812, -17.7863);

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    setState(() => _isReady = true);

    // Si no hay ubicación inicial provista, intentar centrar en la ubicación actual.
    if (widget.initialLatitude == null || widget.initialLongitude == null) {
      _centerToCurrentLocation();
    }
  }

  Future<void> _centerToCurrentLocation() async {
    if (_mapboxMap == null || _isLocating) return;

    setState(() => _isLocating = true);
    try {
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se concedió permiso de ubicación'),
            ),
          );
        }
        return;
      }

      geo.Position? pos;
      try {
        pos = await geo.Geolocator.getCurrentPosition(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
          ),
        ).timeout(const Duration(seconds: 8));
      } catch (_) {
        pos = await geo.Geolocator.getLastKnownPosition();
      }

      if (pos == null || _mapboxMap == null) return;

      final camera = CameraOptions(
        center: Point(coordinates: Position(pos.longitude, pos.latitude)),
        zoom: 16,
      );
      await _mapboxMap!.flyTo(camera, MapAnimationOptions(duration: 900));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener tu ubicación actual'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _confirm() async {
    if (_mapboxMap == null) return;
    final cameraState = await _mapboxMap!.getCameraState();
    final coords = cameraState.center.coordinates;
    if (mounted) {
      Navigator.pop<PickedLocation>(context, (
        latitude: coords.lat.toDouble(),
        longitude: coords.lng.toDouble(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final initialCenter =
        (widget.initialLatitude != null && widget.initialLongitude != null)
        ? Position(widget.initialLongitude!, widget.initialLatitude!)
        : _defaultCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Seleccionar ubicación',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Map
          MapWidget(
            key: const ValueKey('location_picker_map'),
            cameraOptions: CameraOptions(
              center: Point(coordinates: initialCenter),
              zoom: 15,
            ),
            onMapCreated: _onMapCreated,
          ),

          // Centered pin icon (offset upward so base of pin = map center)
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Icon(
                  Icons.location_pin,
                  color: theme.colorScheme.primary,
                  size: 52,
                  shadows: const [Shadow(color: Colors.black26, blurRadius: 8)],
                ),
              ),
            ),
          ),

          // Instruction banner
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Arrastrá el mapa para posicionar el pin en tu dirección exacta',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Confirm button
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: ElevatedButton.icon(
              onPressed: _isReady ? _confirm : null,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                'Confirmar ubicación',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),

          // Recenter button (Google Maps-style)
          Positioned(
            right: 24,
            bottom: 108,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 5,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isReady && !_isLocating
                    ? _centerToCurrentLocation
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _isLocating
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : Icon(
                          Icons.my_location,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
