import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class CreditPackage {
  final String id;
  final String name;
  final int credits;
  final int bonusCredits;
  final double price;
  final bool isActive;
  final int sortOrder;
  final String qrData;
  final String? qrImageUrl;

  CreditPackage({
    required this.id,
    required this.name,
    required this.credits,
    required this.bonusCredits,
    required this.price,
    required this.isActive,
    required this.sortOrder,
    required this.qrData,
    this.qrImageUrl,
  });

  int get totalCredits => credits + bonusCredits;

  factory CreditPackage.fromJson(Map<String, dynamic> j) => CreditPackage(
    id: j['id'] as String,
    name: j['name'] as String,
    credits: j['credits'] as int? ?? 0,
    bonusCredits: j['bonusCredits'] as int? ?? j['bonus_credits'] as int? ?? 0,
    price: double.tryParse((j['price'] ?? '0').toString()) ?? 0,
    isActive: j['isActive'] as bool? ?? j['is_active'] as bool? ?? true,
    sortOrder: j['sortOrder'] as int? ?? j['sort_order'] as int? ?? 0,
    qrData: j['qrData'] as String? ?? j['qr_data'] as String? ?? '',
    qrImageUrl: j['qrImageUrl'] as String? ?? j['qr_image_url'] as String?,
  );
}

class CreditPurchase {
  final String id;
  final String packageName;
  final int creditsGranted;
  final double amountPaid;
  final String status;
  final String paymentReference;
  final String createdAt;
  final String? bnbQrImage;
  final String? proofImageUrl;
  final String? rejectionReason;

  CreditPurchase({
    required this.id,
    required this.packageName,
    required this.creditsGranted,
    required this.amountPaid,
    required this.status,
    this.rejectionReason,
    required this.paymentReference,
    required this.createdAt,
    this.bnbQrImage,
    this.proofImageUrl,
  });

  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isConfirmed => status == 'confirmed';
  bool get hasProof => proofImageUrl != null && proofImageUrl!.isNotEmpty;

  factory CreditPurchase.fromJson(Map<String, dynamic> j) => CreditPurchase(
    id: j['id'] as String,
    packageName:
        j['packageName'] as String? ?? j['package_name'] as String? ?? '—',
    creditsGranted:
        j['creditsGranted'] as int? ?? j['credits_granted'] as int? ?? 0,
    amountPaid:
        double.tryParse(
          (j['amountPaid'] ?? j['amount_paid'] ?? '0').toString(),
        ) ??
        0,
    status: j['status'] as String? ?? 'pending',
    rejectionReason:
        j['rejection_reason'] as String? ?? j['rejection_reason'] as String?,
    paymentReference:
        j['paymentReference'] as String? ??
        j['payment_reference'] as String? ??
        '',
    createdAt: j['createdAt'] as String? ?? j['created_at'] as String? ?? '',
    bnbQrImage: j['bnbQrImage'] as String? ?? j['bnb_qr_image'] as String?,
    proofImageUrl:
        j['proofImageUrl'] as String? ?? j['proof_image_url'] as String?,
  );
}

/// Resultado de iniciar una compra
class ClaimResult {
  final String purchaseId;
  final String reference;
  final String? bnbQrImage; // Base64 PNG del QR dinámico BNB
  final String?
  staticQrUrl; // URL de imagen del QR estático (prioridad sobre BNB)
  final bool useBnb;
  final String packageName;
  final double amount;
  final int creditsGranted;

  ClaimResult({
    required this.purchaseId,
    required this.reference,
    required this.bnbQrImage,
    this.staticQrUrl,
    required this.useBnb,
    required this.packageName,
    required this.amount,
    required this.creditsGranted,
  });

  factory ClaimResult.fromJson(Map<String, dynamic> j) => ClaimResult(
    purchaseId: j['purchaseId'] as String,
    reference: j['reference'] as String,
    bnbQrImage: j['bnbQrImage'] as String?,
    staticQrUrl: j['staticQrUrl'] as String?,
    useBnb: j['useBnb'] as bool? ?? false,
    packageName: j['packageName'] as String? ?? '',
    amount: double.tryParse((j['amount'] ?? '0').toString()) ?? 0,
    creditsGranted: j['creditsGranted'] as int? ?? 0,
  );
}

class CreditService {
  static final CreditService _instance = CreditService._internal();
  factory CreditService() => _instance;
  CreditService._internal();

  final _api = ApiClient();

  Future<List<CreditPackage>> getPackages() async {
    final data = await _api.get('/credits/packages') as List;
    return data
        .map((e) => CreditPackage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getMyBalance() async {
    final data = await _api.get('/credits/my-balance') as Map<String, dynamic>;
    return data['balance'] as int? ?? 0;
  }

  Future<Map<String, dynamic>> getMyBalanceFull() async {
    final data = await _api.get('/credits/my-balance') as Map<String, dynamic>;
    return data;
  }

  Future<List<CreditPurchase>> getMyHistory() async {
    final data = await _api.get('/credits/my-history') as List;
    return data
        .map((e) => CreditPurchase.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Inicia la compra: backend genera QR BNB dinámico y crea el registro pendiente.
  Future<ClaimResult> claimPurchase(String packageId) async {
    final data = await _api.post('/credits/packages/$packageId/claim', {});
    return ClaimResult.fromJson(data as Map<String, dynamic>);
  }

  /// Obtiene la URL del QR estático de la plataforma (si está configurado).
  /// NestJS devuelve strings primitivos como texto plano (no JSON),
  /// por eso se hace la petición directamente sin pasar por jsonDecode.
  Future<String?> getStaticQrUrl() async {
    try {
      final token = await _api.getToken();
      final uri = Uri.parse(
        '${ApiClient.baseUrl}/config/platform_qr_image_url',
      );
      print('[CreditService] getStaticQrUrl → GET $uri (token: ${token != null ? "present" : "null"})');
      final res = await http.get(
        uri,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );
      print('[CreditService] getStaticQrUrl ← status=${res.statusCode} body="${res.body.trim()}"');
      if (res.statusCode != 200) return null;
      final body = res.body.trim();
      if (body.isEmpty || body == 'null') return null;
      // Puede venir como JSON string "\"url\"" o como texto plano
      String url;
      try {
        url = jsonDecode(body) as String;
      } catch (_) {
        url = body;
      }
      // En emulador Android, localhost apunta al emulador, no al host — reemplazar igual que ApiClient
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          final uri = Uri.parse(url);
          if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
            url = uri.replace(host: '10.0.2.2').toString();
          }
        } catch (_) {}
      }
      print('[CreditService] getStaticQrUrl → parsed url="$url"');
      return url.isNotEmpty ? url : null;
    } catch (e) {
      print('[CreditService] getStaticQrUrl ← ERROR: $e');
      return null;
    }
  }

  /// Sube comprobante de pago para una compra pendiente.
  Future<void> submitProof(String purchaseId, String filePath) async {
    await _api.postMultipart(
      '/credits/purchases/$purchaseId/proof',
      filePath,
      'file',
    );
  }

  /// Cancela una compra pendiente.
  Future<void> cancelPurchase(String purchaseId) async {
    await _api.delete('/credits/purchases/$purchaseId');
  }
}
