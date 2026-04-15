import 'package:flutter/material.dart';
import '../../services/address_service.dart';
import '../../services/session_context.dart';
import '../app/settings/location_picker_page.dart';
import '../app/settings/addresses_page.dart';
import '../app/app_root.dart';

/// Modal para seleccionar dirección después del login
class AddressSelectionPage extends StatefulWidget {
  final bool isInitialSetup;

  const AddressSelectionPage({super.key, this.isInitialSetup = false});

  @override
  State<AddressSelectionPage> createState() => _AddressSelectionPageState();
}

class _AddressSelectionPageState extends State<AddressSelectionPage> {
  final _addressService = AddressService();
  final _sessionContext = SessionContext();
  late Future<List<UserAddress>> _addressesFuture;
  bool _isCreatingNew = false;

  @override
  void initState() {
    super.initState();
    _addressesFuture = _addressService.getAddresses();
  }

  Future<void> _createNewAddress() async {
    setState(() => _isCreatingNew = true);
    try {
      final location = await Navigator.push<PickedLocation>(
        context,
        MaterialPageRoute(builder: (_) => const LocationPickerPage()),
      );

      if (location == null || !mounted) {
        if (mounted) setState(() => _isCreatingNew = false);
        return;
      }

      // Crear la dirección (AddressFormPage se encargará de validar zona)
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AddressFormPage(
            initialLatitude: location.latitude,
            initialLongitude: location.longitude,
          ),
        ),
      );

      if (!mounted) return;

      if (result == true && mounted) {
        // Recargar direcciones para obtener la recién creada
        final addresses = await _addressService.getAddresses();
        if (addresses.isNotEmpty && mounted) {
          final newAddress = addresses.last;
          _sessionContext.setAddress(newAddress);
          if (widget.isInitialSetup) {
            // Ir directamente a AppRoot (después de setup inicial)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AppRoot()),
            );
          } else {
            Navigator.pop(context);
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isCreatingNew = false);
    }
  }

  void _selectAddress(UserAddress address) {
    _sessionContext.setAddress(address);
    if (widget.isInitialSetup) {
      // Ir directamente a AppRoot (después de setup inicial)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppRoot()),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.isInitialSetup ? 'Seleccionar ubicación' : 'Mis Direcciones',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCreatingNew ? null : _createNewAddress,
        icon: const Icon(Icons.add),
        label: const Text('Nueva dirección'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<UserAddress>>(
        future: _addressesFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(
                    'Error al cargar direcciones',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          final addresses = snap.data ?? [];

          if (addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off_outlined,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'No tenés direcciones guardadas',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agregá una para continuar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: addresses.length,
            itemBuilder: (_, i) => _AddressSelectionCard(
              address: addresses[i],
              onSelect: () => _selectAddress(addresses[i]),
            ),
          );
        },
      ),
    );
  }
}

class _AddressSelectionCard extends StatelessWidget {
  final UserAddress address;
  final VoidCallback onSelect;

  const _AddressSelectionCard({
    required this.address,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onSelect,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: address.isDefault
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_on,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            address.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (address.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Principal',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      address.fullAddress,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                color: theme.colorScheme.primary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
