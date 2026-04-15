import 'package:flutter/foundation.dart';
import 'dart:math';
import 'api_client.dart';

class DeliveryZone {
  final String id;
  final String name;
  final String city;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final bool isActive;

  DeliveryZone({
    required this.id,
    required this.name,
    required this.city,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    required this.isActive,
  });

  factory DeliveryZone.fromJson(Map<String, dynamic> json) => DeliveryZone(
    id: json['id'] as String,
    name: json['name'] as String,
    city: json['city'] as String,
    centerLat: double.tryParse(json['centerLat'].toString()) ?? 0.0,
    centerLng: double.tryParse(json['centerLng'].toString()) ?? 0.0,
    radiusMeters: double.tryParse(json['radiusMeters'].toString()) ?? 5000.0,
    isActive: json['isActive'] as bool? ?? true,
  );
}

class ZonesService {
  static final ZonesService _instance = ZonesService._internal();
  factory ZonesService() => _instance;
  ZonesService._internal();

  final _api = ApiClient();

  Future<List<DeliveryZone>> getAllZones() async {
    try {
      final data = await _api.get('/zones') as List;
      return data.map((e) => DeliveryZone.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[ZonesService] Error loading zones: $e');
      return [];
    }
  }

  /// Detecta qué zona contiene una coordenada (usando Haversine localmente)
  /// Devuelve null si no está en ninguna zona
  Future<DeliveryZone?> detectZone(double latitude, double longitude) async {
    try {
      final zones = await getAllZones();
      if (zones.isEmpty) return null;

      DeliveryZone? closest;
      double minDistance = double.infinity;

      const earthRadiusKm = 6371.0;
      const pi = 3.14159265359;

      for (final zone in zones) {
        // Calcular distancia Haversine
        final lat1Rad = latitude * pi / 180;
        final lat2Rad = zone.centerLat * pi / 180;
        final deltaLat = (zone.centerLat - latitude) * pi / 180;
        final deltaLng = (zone.centerLng - longitude) * pi / 180;

        final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
            cos(lat1Rad) * cos(lat2Rad) * sin(deltaLng / 2) * sin(deltaLng / 2);
        final c = 2 * atan2(sqrt(a), sqrt(1 - a));
        final distanceKm = earthRadiusKm * c;
        final distanceMeters = distanceKm * 1000;

        // Si está dentro del radio de esta zona
        if (distanceMeters <= zone.radiusMeters) {
          if (distanceMeters < minDistance) {
            minDistance = distanceMeters;
            closest = zone;
          }
        }
      }

      return closest;
    } catch (e) {
      debugPrint('[ZonesService] Error detecting zone: $e');
      return null;
    }
  }
}
