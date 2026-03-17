import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pick_a_place/screens/opening_screen.dart';
import 'package:pick_a_place/models/ad_manager.dart';
import 'package:pick_a_place/models/analytics_service.dart';

void main() {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
      FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

      await Firebase.initializeApp();

      await MobileAds.instance.initialize();

      await _initializeCrashlytics();

      AdManager.instance.loadBannerAd();
      AdManager.instance.loadInterstitialAd();

      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      await EasyLocalization.ensureInitialized();

      runApp(
        EasyLocalization(
          supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
          path: 'assets/languages',
          fallbackLocale: const Locale('en', 'US'),
          startLocale: null,
          child: const MyApp(),
        ),
      );
    },
    (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      navigatorObservers: [AnalyticsService().getAnalyticsObserver()],
      title: 'Pick A Place',
      home: const OpeningScreen(),
    );
  }
}

Future<void> _initializeCrashlytics() async {
  await FirebaseCrashlytics.instance.setCustomKey('environment', 'production');

  final prefs = await SharedPreferences.getInstance();
  await FirebaseCrashlytics.instance.setCustomKey(
    'total_sessions',
    prefs.getInt('session_count') ?? 0,
  );
}
