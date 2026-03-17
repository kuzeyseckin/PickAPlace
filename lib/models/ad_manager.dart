import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:pick_a_place/models/analytics_service.dart';

class AdManager {
  static final AdManager instance = AdManager._internal();
  factory AdManager() => instance;
  AdManager._internal();

  BannerAd? _bannerAd;
  bool isBannerLoaded = false;

  final String _bannerUnitId = Platform.isAndroid ? '' : '';

  InterstitialAd? _interstitialAd;
  bool isInterstitialLoaded = false;

  final String _interstitialUnitId = Platform.isAndroid ? '' : '';

  Future<void> loadBannerAd() async {
    if (isBannerLoaded || _bannerAd != null) return;

    _bannerAd = BannerAd(
      adUnitId: _bannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          isBannerLoaded = true;
          AnalyticsService().logBannerAdLoaded();
        },
        onAdClicked: (ad) => AnalyticsService().logBannerAdClicked(),
        onAdFailedToLoad: (ad, err) {
          AnalyticsService().logBannerAdFailed(err.toString());
          isBannerLoaded = false;
          ad.dispose();
          _bannerAd = null;
        },
      ),
    );

    await _bannerAd?.load();
  }

  Widget getBannerWidget() {
    if (!isBannerLoaded || _bannerAd == null) {
      return const SizedBox();
    }
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  void loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          isInterstitialLoaded = true;
          debugPrint("✅ AdManager: Tam Ekran Reklam Hazır.");
        },
        onAdFailedToLoad: (err) {
          debugPrint('❌ AdManager: Tam Ekran Yüklenemedi: $err');
          isInterstitialLoaded = false;
        },
      ),
    );
  }

  void showInterstitialAd({required VoidCallback onAdDismissed}) {
    if (isInterstitialLoaded && _interstitialAd != null) {
      AnalyticsService().logInterstitialAdShown();

      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          AnalyticsService().logInterstitialAdClosed();
          ad.dispose();
          isInterstitialLoaded = false;
          loadInterstitialAd();
          onAdDismissed();
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          AnalyticsService().logInterstitialAdFailed(err.toString());
          ad.dispose();
          isInterstitialLoaded = false;
          loadInterstitialAd();
          onAdDismissed();
        },
        onAdClicked: (ad) => AnalyticsService().logInterstitialAdClicked(),
      );

      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      debugPrint("⚠️ Reklam hazır değil, direkt geçiliyor.");
      onAdDismissed();
      loadInterstitialAd();
    }
  }

  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    isBannerLoaded = false;
    isInterstitialLoaded = false;
  }
}
