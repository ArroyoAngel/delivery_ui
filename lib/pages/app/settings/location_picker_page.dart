import 'package:flutter/material.dart';
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

  // Santa Cruz de la Sierra, Bolivia (default center)
  static final Position _defaultCenter = Position(-63.1812, -17.7863);

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    setState(() => _isReady = true);
  }

  Future<void> _confirm() async {
    if (_mapboxMap == null) return;
    final cameraState = await _mapboxMap!.getCameraState();
    final coords = cameraState.center.coordinates;
    if (mounted) {
      Navigator.pop<PickedLocation>(
        context,
        (latitude: coords.lat.toDouble(), longitude: coords.lng.toDouble()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final initialCenter = (widget.initialLatitude != null && widget.initialLongitude != null)
        ? Position(widget.initialLongitude!, widget.initialLatitude!)
        : _defaultCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar ubicación',
            style: TextStyle(fontWeight: FontWeight.w700)),
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
                  Icon(Icons.touch_app_outlined,
                      color: theme.colorScheme.primary, size: 20),
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
                    borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
