import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço de compras no app (Versão PRO)
class PurchaseService extends ChangeNotifier {
  static const String _kProVersionId = 'pro_book_quest';
  static const String _kPurchaseStatusKey = 'pro_version_purchased';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  bool _isPurchasing = false;
  bool _isProVersion = false;
  List<ProductDetails> _products = [];
  String _purchaseError = '';

  bool get isAvailable => _isAvailable;
  bool get isPurchasing => _isPurchasing;
  bool get isProVersion => _isProVersion;
  List<ProductDetails> get products => _products;
  String get purchaseError => _purchaseError;
  String get proVersionId => _kProVersionId;

  PurchaseService() {
    _initialize();
  }

  /// Carrega status PRO rapidamente (antes da UI iniciar)
  Future<void> loadPurchaseStatusSync() async {
    final prefs = await SharedPreferences.getInstance();
    _isProVersion = prefs.getBool(_kPurchaseStatusKey) ?? false;
  }

  Future<void> _initialize() async {
    _isAvailable = await _inAppPurchase.isAvailable();

    if (_isAvailable) {
      final Stream<List<PurchaseDetails>> purchaseStream = _inAppPurchase.purchaseStream;
      _subscription = purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription?.cancel(),
        onError: (error) => debugPrint('Purchase stream error: $error'),
      );

      await _loadProducts();
      await _restorePurchases();
    }

    // Garante status inicial do SharedPreferences
    await _loadPurchaseStatus();
    notifyListeners();
  }

  Future<void> _loadProducts() async {
    if (!_isAvailable) return;
    const Set<String> ids = {_kProVersionId};
    final response = await _inAppPurchase.queryProductDetails(ids);
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Produtos não encontrados: ${response.notFoundIDs}');
    }
    _products = response.productDetails;
    notifyListeners();
  }

  Future<void> _loadPurchaseStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _isProVersion = prefs.getBool(_kPurchaseStatusKey) ?? _isProVersion;
  }

  Future<void> _savePurchaseStatus(bool isPro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPurchaseStatusKey, isPro);
    _isProVersion = isPro;
    notifyListeners();
  }

  ProductDetails? getProVersionProduct() {
    try {
      return _products.firstWhere((p) => p.id == _kProVersionId);
    } catch (_) {
      return null;
    }
  }

  Future<void> buyProVersion() async {
    if (!_isAvailable || _isPurchasing) return;

    final product = getProVersionProduct();
    if (product == null) {
      _purchaseError = 'Produto não encontrado';
      notifyListeners();
      return;
    }

    _isPurchasing = true;
    _purchaseError = '';
    notifyListeners();

    final param = PurchaseParam(productDetails: product);
    await _inAppPurchase.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    await _restorePurchases();
  }

  Future<void> _restorePurchases() async {
    if (!_isAvailable) return;
    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      debugPrint('Erro ao restaurar compras: $e');
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> list) {
    for (final details in list) {
      _handlePurchase(details);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails details) async {
    if (details.productID == _kProVersionId) {
      switch (details.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _savePurchaseStatus(true);
          _isPurchasing = false;
          _purchaseError = '';
          break;
        case PurchaseStatus.error:
          _isPurchasing = false;
          _purchaseError = details.error?.message ?? 'Erro na compra';
          await _savePurchaseStatus(false);
          break;
        case PurchaseStatus.pending:
          _isPurchasing = true;
          _purchaseError = '';
          break;
        case PurchaseStatus.canceled:
          _isPurchasing = false;
          _purchaseError = '';
          break;
      }
    }

    if (details.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(details);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
