import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pick_a_place/models/restaurants_model.dart';
import 'package:pick_a_place/Screens/home_screen.dart';
import 'package:pick_a_place/models/analytics_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key});

  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  Position? _initialUserPosition;

  late AnimationController _bgController;

  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  String _statusMessage = "";

  @override
  void initState() {
    AnalyticsService().logFunnelStep('user_onboarding', 1);
    super.initState();
    AnalyticsService().logScreenView('opening_screen');

    _statusMessage = "opening.scanning_places";
    FlutterNativeSplash.remove();
    AnalyticsService().logAppOpened();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService().logInitialLanguage(context.locale.languageCode);
      setState(() {
        _statusMessage = "opening.scanning_places".tr();
      });
    });

    WidgetsBinding.instance.addObserver(this);

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startAppFlow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgController.dispose();
    _pulseController.dispose();
    AnalyticsService().logSettingsClosed();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionAndFetch();
    }
  }

  void _startAppFlow() {
    Future.delayed(const Duration(seconds: 2), _checkPermissionAndFetch);
  }

  Future<void> _checkPermissionAndFetch() async {
    if (!mounted) return;
    setState(() => _statusMessage = "opening.checking_permissions".tr());

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      AnalyticsService().logLocationServiceDisabled();
      _showMandatoryDialog(
        "alerts.location_service_off".tr(),
        "alerts.enable_location".tr(),
        true,
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        AnalyticsService().logLocationPermissionDenied();
        _showMandatoryDialog(
          "alerts.permission_required".tr(),
          "alerts.permission_msg".tr(),
          false,
        );
        return;
      } else {
        AnalyticsService().logLocationPermissionGranted();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showMandatoryDialog(
        "alerts.permission_denied_forever".tr(),
        "alerts.open_settings_msg".tr(),
        true,
      );
      return;
    }

    _fetchLocationAndData();
  }

  Future<void> _fetchLocationAndData() async {
    if (!mounted) return;
    setState(() => _statusMessage = "opening.fetching_location".tr());

    try {
      Position position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Konum alınamadı'),
          );

      _initialUserPosition = position;
      AnalyticsService().logUserLocation(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() => _statusMessage = "opening.scanning_places".tr());
      AnalyticsService().logFunnelStep('user_onboarding', 2);

      PlacesResponse response = await fetchRestaurantsSmart(
        lat: position.latitude,
        lon: position.longitude,
        radius: 1000,
        languageCode: context.locale.languageCode,
      );

      List<Restaurant> restaurants = response.restaurants;

      AnalyticsService().logRestaurantsFetched(
        count: restaurants.length,
        radiusKm: 1.0,
        source: 'startup',
      );
      AnalyticsService().logHomeScreenReached();

      for (var r in restaurants) {
        r.distanceKm =
            Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              r.lat,
              r.lon,
            ) /
            1000;
      }
      restaurants.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              initialRestaurants: restaurants,
              initialPosition: _initialUserPosition,
              initialNextPageToken: response.nextPageToken,
              initialTomTomOffset: response.tomTomOffset,
            ),
          ),
        );
        AnalyticsService().logFunnelStep('user_onboarding', 3);
      }
    } catch (e) {
      AnalyticsService().logLocationError(e.toString());
      _showMandatoryDialog(
        "alerts.error_title".tr(),
        "alerts.fetch_error".tr(),
        false,
      );
    }
  }

  void _showMandatoryDialog(String title, String content, bool openSettings) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: Text(title, style: const TextStyle(color: Color(0xFFD4352A))),
          content: Text(content),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (openSettings) {
                  AnalyticsService().logPermissionDialogAction(
                    'settings_clicked',
                  );
                  Geolocator.openLocationSettings();
                } else {
                  AnalyticsService().logPermissionDialogAction('retry_clicked');
                  _checkPermissionAndFetch();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4352A),
              ),
              child: Text(
                openSettings
                    ? "alerts.btn_settings".tr()
                    : "alerts.btn_retry".tr(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staticContent = Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset(
              'assets/images/logo/app_logo_splash.png',
              width: 350,
              height: 350,
            ),
          ),
          const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              color: Colors.black54,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(_statusMessage, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: _bgController,
      child: staticContent,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF7B281C),
          body: Stack(
            children: [
              Align(
                alignment: Alignment(
                  -1.0 + (_bgController.value * 2),
                  -1.0 + (_bgController.value),
                ),
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFD4352A),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFD4352A),
                        blurRadius: 100,
                        spreadRadius: 50,
                      ),
                    ],
                  ),
                ),
              ),

              Align(
                alignment: Alignment(
                  1.0 - (_bgController.value * 2),
                  -0.5 + (_bgController.value),
                ),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 120,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(child: child!),
            ],
          ),
        );
      },
    );
  }
}
