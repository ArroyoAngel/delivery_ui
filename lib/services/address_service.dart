import 'api_client.dart';

class UserAddress {
  final String id;
  final String name;
  final String street;
  final String? number;
  final String? floor;
  final String? reference;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  UserAddress({
    required this.id,
    required this.name,
    required this.street,
    this.number,
    this.floor,
    this.reference,
    this.latitude,
    this.longitude,
    this.isDefault = false,
  });

  factory UserAddress.fromJson(Map<String, dynamic> j) => UserAddress(
        id: j['id'] as String,
        name: j['name'] as String,
        street: j['street'] as String,
        number: j['number'] as String?,
        floor: j['floor'] as String?,
        reference: j['reference'] as String?,
        latitude: j['latitude'] == null ? null : double.tryParse(j['latitude'].toString()),
        longitude: j['longitude'] == null ? null : double.tryParse(j['longitude'].toString()),
        isDefault: j['isDefault'] as bool? ?? j['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'name': name, 'street': street, 'isDefault': isDefault};
    if (number != null && number!.isNotEmpty) m['number'] = number;
    if (floor != null && floor!.isNotEmpty) m['floor'] = floor;
    if (reference != null && reference!.isNotEmpty) m['reference'] = reference;
    if (latitude != null) m['latitude'] = latitude;
    if (longitude != null) m['longitude'] = longitude;
    return m;
  }

  String get fullAddress {
    final parts = <String>[street];
    if (number != null && number!.isNotEmpty) parts.add(number!);
    if (floor != null && floor!.isNotEmpty) parts.add('Piso ${floor!}');
    return parts.join(', ');
  }
}

class AddressService {
  static final AddressService _instance = AddressService._internal();
  factory AddressService() => _instance;
  AddressService._internal();

  final _api = ApiClient();

  Future<List<UserAddress>> getAddresses() async {
    final data = await _api.get('/addresses') as List;
    return data.map((e) => UserAddress.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UserAddress> createAddress(Map<String, dynamic> body) async {
    final data = await _api.post('/addresses', body) as Map<String, dynamic>;
    return UserAddress.fromJson(data);
  }

  Future<UserAddress> updateAddress(String id, Map<String, dynamic> body) async {
    final data = await _api.put('/addresses/$id', body) as Map<String, dynamic>;
    return UserAddress.fromJson(data);
  }

  Future<void> deleteAddress(String id) async {
    await _api.delete('/addresses/$id');
  }
}
