import 'package:flutter/foundation.dart';
import 'address_service.dart';

/// Contexto de sesión del usuario — mantiene la dirección seleccionada
class SessionContext with ChangeNotifier {
  static final SessionContext _instance = SessionContext._internal();

  factory SessionContext() => _instance;
  SessionContext._internal();

  UserAddress? _selectedAddress;

  UserAddress? get selectedAddress => _selectedAddress;

  void setAddress(UserAddress address) {
    _selectedAddress = address;
    notifyListeners();
  }

  void clearAddress() {
    _selectedAddress = null;
    notifyListeners();
  }

  bool get hasAddress => _selectedAddress != null;
}
