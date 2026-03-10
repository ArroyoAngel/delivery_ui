import 'package:flutter/material.dart';
import '../../../services/address_service.dart';
import 'location_picker_page.dart';

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  final _service = AddressService();
  late Future<List<UserAddress>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() { _future = _service.getAddresses(); });
  }

  Future<void> _delete(UserAddress address) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar dirección'),
        content: Text('¿Eliminar "${address.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.deleteAddress(address.id);
      _load();
    }
  }

  Future<void> _openForm({UserAddress? address}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddressFormPage(address: address)),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Mis Direcciones', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva dirección'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<UserAddress>>(
        future: _future,
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
                  Text('Error al cargar direcciones', style: TextStyle(color: Colors.grey.shade600)),
                  TextButton(onPressed: _load, child: const Text('Reintentar')),
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
                  Icon(Icons.location_off_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No tenés direcciones guardadas',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Agregá una para hacer pedidos más rápido',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: addresses.length,
            itemBuilder: (_, i) => _AddressCard(
              address: addresses[i],
              onEdit: () => _openForm(address: addresses[i]),
              onDelete: () => _delete(addresses[i]),
            ),
          );
        },
      ),
    );
  }
}

// ─── Address Card ─────────────────────────────────────────────────────────────

class _AddressCard extends StatelessWidget {
  final UserAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressCard({required this.address, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: address.isDefault
            ? Border.all(color: theme.colorScheme.primary, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.location_on, color: theme.colorScheme.primary, size: 22),
            ),
            title: Row(
              children: [
                Expanded(child: Text(address.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Principal',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(address.fullAddress, style: TextStyle(color: Colors.grey.shade700)),
                  if (address.floor != null && address.floor!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Piso ${address.floor}',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ),
                  if (address.reference != null && address.reference!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 13, color: Colors.orange.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address.reference!,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.orange.shade800, fontStyle: FontStyle.italic),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16),
          Row(
            children: [
              if (address.latitude != null && address.longitude != null)
                TextButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Lat: ${address.latitude!.toStringAsFixed(6)}, Lng: ${address.longitude!.toStringAsFixed(6)}'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Ver en mapa', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
                color: Colors.grey.shade600,
                tooltip: 'Editar',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onDelete,
                color: Colors.red.shade400,
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Address Form ─────────────────────────────────────────────────────────────

class AddressFormPage extends StatefulWidget {
  final UserAddress? address;
  const AddressFormPage({super.key, this.address});

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  final _service = AddressService();
  final _form = GlobalKey<FormState>();
  bool _saving = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _numberCtrl;
  late final TextEditingController _floorCtrl;
  late final TextEditingController _referenceCtrl;
  bool _isDefault = false;

  double? _latitude;
  double? _longitude;

  bool get _isEditing => widget.address != null;
  bool get _hasLocation => _latitude != null && _longitude != null;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    _nameCtrl = TextEditingController(text: a?.name ?? '');
    _streetCtrl = TextEditingController(text: a?.street ?? '');
    _numberCtrl = TextEditingController(text: a?.number ?? '');
    _floorCtrl = TextEditingController(text: a?.floor ?? '');
    _referenceCtrl = TextEditingController(text: a?.reference ?? '');
    _isDefault = a?.isDefault ?? false;
    _latitude = a?.latitude;
    _longitude = a?.longitude;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _streetCtrl.dispose();
    _numberCtrl.dispose();
    _floorCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!_hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seleccioná la ubicación en el mapa antes de guardar'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'street': _streetCtrl.text.trim(),
        'number': _numberCtrl.text.trim(),
        'floor': _floorCtrl.text.trim(),
        'reference': _referenceCtrl.text.trim(),
        'isDefault': _isDefault,
        'latitude': _latitude,
        'longitude': _longitude,
      };
      if (_isEditing) {
        await _service.updateAddress(widget.address!.id, body);
      } else {
        await _service.createAddress(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar dirección' : 'Nueva dirección',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionLabel('Ubicación en mapa'),
            GestureDetector(
              onTap: _pickLocation,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasLocation
                        ? theme.colorScheme.primary
                        : Colors.grey.shade200,
                    width: _hasLocation ? 1.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _hasLocation
                            ? theme.colorScheme.primaryContainer
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _hasLocation ? Icons.location_on : Icons.add_location_alt_outlined,
                        color: _hasLocation
                            ? theme.colorScheme.primary
                            : Colors.grey.shade500,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _hasLocation
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ubicación seleccionada',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.primary)),
                                Text(
                                  '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            )
                          : Text('Seleccionar ubicación en mapa',
                              style: TextStyle(color: Colors.grey.shade700)),
                    ),
                    Icon(Icons.chevron_right,
                        color: Colors.grey.shade400, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel('Información'),
            _buildField(context, _nameCtrl, 'Nombre descriptivo', 'Ej: Casa, Trabajo, Casa de mamá...', Icons.label_outline,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
            const SizedBox(height: 12),
            _buildField(context, _streetCtrl, 'Calle / Avenida', 'Ej: Av. 6 de Agosto', Icons.signpost_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _buildField(context, _numberCtrl, 'Número / Casa', 'Ej: 1234', Icons.home_outlined)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildField(context, _floorCtrl, 'Piso / Depto', 'Ej: 3B', Icons.apartment_outlined)),
              ],
            ),
            const SizedBox(height: 20),
            _sectionLabel('Instrucciones para el repartidor'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Icon(Icons.info_outline, color: Colors.orange.shade600, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _referenceCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText:
                            'Ej: Tocar timbre 2 veces. Llamar al llegar. Portón azul al costado del kiosco...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SwitchListTile(
                title: const Text('Dirección principal', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Se usará por defecto al hacer pedidos',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                activeThumbColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_isEditing ? 'Guardar cambios' : 'Agregar dirección',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5)),
      );

  Widget _buildField(
    BuildContext context,
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon, {
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red)),
        ),
      );
}
