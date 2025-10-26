import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../constants/ad_ids.dart';

/// Banner de anúncios (AdMob) discreto para o rodapé.
/// Usa AdSize.largeBanner (altura ~100dp) conforme pedido.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    // Exibe apenas em dispositivos Android
    if (!Platform.isAndroid) return;

    final ad = BannerAd(
      adUnitId: AdIds.homeBanner,
      request: const AdRequest(),
      size: AdSize.banner, // ~320x100 (telefones)
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          // Silencioso em produção; opcionalmente logar
        },
      ),
    );

    ad.load();
    _bannerAd = ad;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _bannerAd == null) {
      // Reserva espaço pequeno para evitar saltos na UI
      return const SizedBox(height: 0);
    }

    final ad = _bannerAd!;
    return Container(
      color: Colors.transparent,
      alignment: Alignment.center,
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
