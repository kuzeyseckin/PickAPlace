import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:confetti/confetti.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:pick_a_place/models/restaurants_model.dart';
import 'package:pick_a_place/screens/settings_screen.dart';
import 'package:pick_a_place/models/google_banner_ad.dart';
import 'package:pick_a_place/screens/roulette_dialog.dart';
import 'package:pick_a_place/models/analytics_service.dart';
import 'package:pick_a_place/models/ad_manager.dart';

class HomeScreen extends StatefulWidget {
  final List<Restaurant> initialRestaurants;
  final Position? initialPosition;

  final String? initialNextPageToken;
  final int? initialTomTomOffset;

  const HomeScreen({
    super.key,
    required this.initialRestaurants,
    required this.initialPosition,
    this.initialNextPageToken,
    this.initialTomTomOffset,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _sessionApiCallCount = 0;
  final double _searchRadiusKm = 5.0;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";

  List<Restaurant> displayedRestaurants = [];
  List<Restaurant> _masterRestaurantList = [];
  List<Restaurant> selectedRestaurants = [];

  String? _nextPageToken;
  int? _tomTomOffset;
  bool _isLoadingMore = false;
  bool _isRefetching = false;

  int? selectedCategoryIndex;
  late ConfettiController _confettiController;
  late Position _currentMonitoringPosition;

  Position? _lastFetchedPosition;
  DateTime? _lastFetchTime;

  List<String> _excludedKeywords = [];
  String _lastLoadedLang = '';

  final List<String> _categoriesTr = [
    "Hamburger",
    "Kebap",
    "Et Restoranı",
    "Tavuk",
    "Pizza",
    "Makarna",
    "Deniz Ürünleri",
    "Ev Yemekleri",
    "Kahve",
    "Pastane",
    "Restaurant",
    "Pub & Bar",
  ];

  final List<String> _categoriesEn = [
    "Hamburger",
    "Kebab",
    "Steakhouse",
    "Chicken",
    "Pizza",
    "Pasta",
    "Seafood",
    "Home Cooking",
    "Coffee",
    "Bakery",
    "Restaurant",
    "Pub & Bar",
  ];

  List<String> get categoryMap =>
      (context.locale.languageCode == 'en') ? _categoriesEn : _categoriesTr;

  int _viewedRestaurantsCount = 0;
  int _categoryChangeCount = 0;
  int _searchCount = 0;
  final DateTime _sessionStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService().logScreenView('home_screen');

    _masterRestaurantList = List.from(widget.initialRestaurants);
    displayedRestaurants = List.from(widget.initialRestaurants);

    _nextPageToken = widget.initialNextPageToken;
    _tomTomOffset = widget.initialTomTomOffset;

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );

    if (widget.initialPosition != null) {
      _currentMonitoringPosition = widget.initialPosition!;
      _lastFetchedPosition = widget.initialPosition;
      _lastFetchTime = DateTime.now();
    } else {
      _currentMonitoringPosition = Position(
        longitude: 28.9784,
        latitude: 41.0082,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _confettiController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshLocationAndRestaurants();
      AnalyticsService().logAppResumed();
    } else if (state == AppLifecycleState.paused) {
      final sessionDuration = DateTime.now().difference(_sessionStartTime);
      AnalyticsService().logSessionQuality(
        restaurantsViewed: _viewedRestaurantsCount,
        categoriesUsed: _categoryChangeCount,
        searchesPerformed: _searchCount,
        sessionDuration: sessionDuration,
      );
      AnalyticsService().logAppBackgrounded(
        selectedCount: selectedRestaurants.length,
        displayedCount: displayedRestaurants.length,
      );
      AnalyticsService().logSessionApiUsage(_sessionApiCallCount);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentLang = context.locale.languageCode;
    if (_lastLoadedLang != currentLang) {
      _lastLoadedLang = currentLang;
      _loadFilterConfig().then((_) {
        if (_masterRestaurantList.isNotEmpty) {
          _refetchRestaurants(
            _currentMonitoringPosition,
            source: 'language_change',
          );
        }
      });
    }
  }

  Future<void> _loadFilterConfig() async {
    try {
      String fileName = (context.locale.languageCode == 'en')
          ? 'category_filters_en.json'
          : 'category_filters_tr.json';
      final String response = await rootBundle.loadString(
        'assets/files/$fileName',
      );
      final data = json.decode(response);
      if (data['exclude_words'] != null) {
        if (mounted) {
          setState(() {
            _excludedKeywords = List<String>.from(data['exclude_words']);
            _applyFilters();
          });
        }
      }
    } catch (e) {
      debugPrint("Filtre dosyası okunamadı: $e");
    }
  }

  Future<void> _refreshLocationAndRestaurants({
    bool isSettingsChange = false,
    String source = 'movement',
  }) async {
    if (_isRefetching || !mounted) return;

    if (!isSettingsChange && _lastFetchTime != null) {
      final difference = DateTime.now().difference(_lastFetchTime!);
      if (difference.inMinutes < 2) return;
    }

    try {
      Position currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!isSettingsChange && _lastFetchedPosition != null) {
        double distanceMeters = Geolocator.distanceBetween(
          _lastFetchedPosition!.latitude,
          _lastFetchedPosition!.longitude,
          currentPosition.latitude,
          currentPosition.longitude,
        );
        if (distanceMeters < 200) return;
      }

      AnalyticsService().logUserLocation(
        currentPosition.latitude,
        currentPosition.longitude,
      );
      if (mounted) _refetchRestaurants(currentPosition, source: source);
    } catch (e) {
      if (isSettingsChange) _refetchRestaurants(_currentMonitoringPosition);
    }
  }

  Future<void> _refetchRestaurants(
    Position position, {
    String source = 'unknown',
  }) async {
    if (!mounted) return;
    setState(() {
      _isRefetching = true;
      _nextPageToken = null;
      _tomTomOffset = null;
    });

    try {
      _sessionApiCallCount++;

      PlacesResponse response = await fetchRestaurantsSmart(
        lat: position.latitude,
        lon: position.longitude,
        radius: (_searchRadiusKm * 1000).toInt(),
        languageCode: context.locale.languageCode,
      );

      _lastFetchTime = DateTime.now();
      _lastFetchedPosition = position;

      List<Restaurant> fetched = response.restaurants;

      for (var r in fetched) {
        r.distanceKm =
            Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              r.lat,
              r.lon,
            ) /
            1000;
      }
      fetched.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      AnalyticsService().logRestaurantsFetched(
        count: fetched.length,
        radiusKm: _searchRadiusKm,
        source: source,
      );
      AnalyticsService().logRestaurantsRefreshed(
        fetched.length,
        _searchRadiusKm,
      );
      AnalyticsService().setUserAverageRadius(_searchRadiusKm);

      if (mounted) {
        setState(() {
          _currentMonitoringPosition = position;
          _masterRestaurantList = fetched;
          _applyFilters();
          selectedRestaurants = [];

          _nextPageToken = response.nextPageToken;
          _tomTomOffset = response.tomTomOffset;

          if (response.source == 'google' && _nextPageToken == null) {
            debugPrint(
              "🚀 Google tek seferde bitti, sonraki tıklama TomTom olacak.",
            );
            _tomTomOffset = 0;
          }

          _isRefetching = false;
        });
      }
    } catch (e) {
      AnalyticsService().logApiError(e.toString());
      if (mounted) setState(() => _isRefetching = false);
    }
  }

  void _loadMoreRestaurants() {
    if (_nextPageToken == null && _tomTomOffset == null) {
      setState(() => _tomTomOffset = 0);
    }

    if ((_nextPageToken == null && _tomTomOffset == null) || _isLoadingMore) {
      return;
    }

    AnalyticsService().logLoadMoreClicked();

    AdManager.instance.showInterstitialAd(
      onAdDismissed: () async {
        setState(() => _isLoadingMore = true);
        try {
          PlacesResponse response = await fetchRestaurantsSmart(
            lat: _currentMonitoringPosition.latitude,
            lon: _currentMonitoringPosition.longitude,
            radius: (_searchRadiusKm * 1000).toInt(),
            languageCode: context.locale.languageCode,
            googleToken: _nextPageToken,
            tomTomOffset: _tomTomOffset,
          );

          List<Restaurant> newOnes = response.restaurants;
          List<Restaurant> uniqueNewOnes = [];

          for (var newItem in newOnes) {
            newItem.distanceKm =
                Geolocator.distanceBetween(
                  _currentMonitoringPosition.latitude,
                  _currentMonitoringPosition.longitude,
                  newItem.lat,
                  newItem.lon,
                ) /
                1000;

            bool exists = _masterRestaurantList.any((existing) {
              double dist = Geolocator.distanceBetween(
                existing.lat,
                existing.lon,
                newItem.lat,
                newItem.lon,
              );
              return dist < 20 ||
                  existing.name.toLowerCase() == newItem.name.toLowerCase();
            });

            if (!exists) uniqueNewOnes.add(newItem);
          }

          if (mounted) {
            setState(() {
              _masterRestaurantList.addAll(uniqueNewOnes);
              _masterRestaurantList.sort(
                (a, b) => a.distanceKm.compareTo(b.distanceKm),
              );

              _applyFilters();

              _nextPageToken = response.nextPageToken;
              _tomTomOffset = response.tomTomOffset;

              if (response.source == 'google' && _nextPageToken == null) {
                debugPrint(
                  "🚀 Google sayfaları bitti, sonraki tıklama TomTom olacak.",
                );
                _tomTomOffset = 0;
              }

              _isLoadingMore = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  uniqueNewOnes.isEmpty
                      ? "alerts.no_new_places".tr()
                      : "+${uniqueNewOnes.length} ${'alerts.places_added'.tr()}",
                ),
                duration: const Duration(milliseconds: 800),
              ),
            );
          }
        } catch (e) {
          debugPrint("Hata: $e");
          setState(() => _isLoadingMore = false);
        }
      },
    );
  }

  Future<void> _openMaps(double lat, double lon, String name) async {
    final String encodedName = Uri.encodeComponent(name);
    Uri uri;
    if (Platform.isAndroid) {
      uri = Uri.parse("geo:0,0?q=$lat,$lon($encodedName)");
    } else if (Platform.isIOS) {
      uri = Uri.parse("https://maps.apple.com/?ll=$lat,$lon&q=$encodedName");
    } else {
      uri = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=$lat,$lon",
      );
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(
          Uri.parse(
            "https://www.google.com/maps/search/?api=1&query=$lat,$lon",
          ),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint('Map Error: $e');
      AnalyticsService().logMapLaunchFailed(
        e.toString(),
        Platform.operatingSystem,
      );
    }
  }

  void _applyFilters() {
    List<Restaurant> temp = List.from(_masterRestaurantList);

    temp = temp.where((r) => r.distanceKm <= _searchRadiusKm).toList();

    if (_excludedKeywords.isNotEmpty) {
      temp = temp.where((r) {
        for (var banned in _excludedKeywords) {
          if (r.name.toLowerCase().contains(banned.toLowerCase())) return false;
        }
        return true;
      }).toList();
    }

    if (selectedCategoryIndex != null) {
      String selectedCatName = categoryMap[selectedCategoryIndex!];

      temp = temp.where((r) {
        return r.category.toLowerCase().contains(selectedCatName.toLowerCase());
      }).toList();
    }

    if (_searchText.isNotEmpty) {
      final s = _searchText.toLowerCase();
      temp = temp
          .where(
            (r) =>
                r.name.toLowerCase().contains(s) ||
                r.category.toLowerCase().contains(s),
          )
          .toList();
    }

    debugPrint("✅ Ekranda Gösterilen: ${temp.length}");
    setState(() => displayedRestaurants = temp);
  }

  void _handleCategoryTap(int index) {
    _categoryChangeCount++;
    AnalyticsService().setUserFavoriteCategory(categoryMap[index]);
    setState(() {
      if (selectedCategoryIndex == index) {
        selectedCategoryIndex = null;
        AnalyticsService().logCategoryDeselected(categoryMap[index]);
      } else {
        selectedCategoryIndex = index;
        AnalyticsService().logCategorySelected(categoryMap[index]);
      }
      _applyFilters();
    });
  }

  void _handleSearch(String value) {
    if (value.isNotEmpty) _searchCount++;
    setState(() {
      _searchText = value;
      _applyFilters();
    });
    if (value.isNotEmpty) {
      AnalyticsService().logSearchBox(value, displayedRestaurants.length);
    }
  }

  void _toggleSelection(Restaurant r) {
    _viewedRestaurantsCount++;
    setState(() {
      if (selectedRestaurants.contains(r)) {
        selectedRestaurants.remove(r);
      } else {
        selectedRestaurants.add(r);
      }
    });
    AnalyticsService().logRestaurantToggled(
      restaurantName: r.name,
      category: r.category,
      distanceKm: r.distanceKm,
      isAdded: selectedRestaurants.contains(r),
    );
  }

  void _showWinnerDialog(Restaurant winner, {required String source}) {
    final random = Random();
    final align1 = Alignment(
      -0.9 + random.nextDouble() * 0.8,
      -0.8 + random.nextDouble() * 0.6,
    );
    final align2 = Alignment(
      0.1 + random.nextDouble() * 0.8,
      -0.8 + random.nextDouble() * 0.6,
    );

    AnalyticsService().logWinnerDialogShown(winner.name, source);
    _confettiController.play();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Stack(
        alignment: Alignment.center,
        children: [
          AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Column(
              children: [
                const Text('🥳', style: TextStyle(fontSize: 50)),
                const SizedBox(height: 8),
                Text(
                  'home.winner_title'.tr(),
                  style: const TextStyle(
                    color: Color(0xFFCB3221),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    winner.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'categories.${winner.category}'.tr(),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "home.distance_display".tr(
                      args: [winner.distanceKm.toStringAsFixed(2)],
                    ),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
            ),
            actions: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 10,
                children: [
                  TextButton(
                    onPressed: () {
                      AnalyticsService().logWinnerButtonAccepted(winner.name);
                      _confettiController.stop();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'home.winner_button'.tr(),
                      style: const TextStyle(
                        color: Color(0xFFCB3221),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      AnalyticsService().logDirectionsFromWinnerPopUp(
                        winner.name,
                      );
                      _confettiController.stop();
                      Navigator.pop(context);
                      _openMaps(winner.lat, winner.lon, winner.name);
                    },
                    icon: const Icon(
                      Icons.directions,
                      size: 20,
                      color: Color(0xFFCB3221),
                    ),
                    label: Text(
                      'home.directions'.tr(),
                      style: const TextStyle(
                        color: Color(0xFFCB3221),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          IgnorePointer(
            child: Align(
              alignment: align1,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.purple,
                ],
                createParticlePath: drawStar,
                numberOfParticles: 15,
                gravity: 0.2,
              ),
            ),
          ),
          IgnorePointer(
            child: Align(
              alignment: align2,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.orange,
                  Colors.yellow,
                  Colors.red,
                  Color(0xFFCB3221),
                ],
                createParticlePath: drawStar,
                numberOfParticles: 15,
                gravity: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Path drawStar(Size size) {
    double degToRad(double deg) => deg * (pi / 180.0);
    const numberOfPoints = 10;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);
    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(
        halfWidth + externalRadius * cos(step),
        halfWidth + externalRadius * sin(step),
      );
      path.lineTo(
        halfWidth + internalRadius * cos(step + halfDegreesPerStep),
        halfWidth + internalRadius * sin(step + halfDegreesPerStep),
      );
    }
    path.close();
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xC7FFFFFF),
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: const Color(0xFFCB3221),
            unselectedItemColor: Colors.grey,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.restaurant),
                label: 'home.nav_home'.tr(),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings),
                label: 'home.nav_settings'.tr(),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _currentIndex == 0
                ? _buildMainStack(height, width)
                : const SettingsScreen(),
          ),
          const Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(child: GoogleBannerAd()),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStack(double height, double width) {
    bool isSmallScreen = height < 700;
    double topPadding = MediaQuery.of(context).padding.top;
    double headerHeight =
        topPadding +
        (isSmallScreen ? 52.0 : (width * 0.14).clamp(26.0, 100.0)) +
        130;
    double cardTop =
        topPadding +
        (isSmallScreen ? 52.0 : (width * 0.14).clamp(26.0, 100.0)) +
        30;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: headerHeight,
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
              gradient: LinearGradient(
                colors: [Color(0xFFA02619), Color(0xFFA02619)],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(top: topPadding + 10),
              child: Align(
                alignment: Alignment.topCenter,
                child: Transform.translate(
                  offset: const Offset(0, -30),
                  child: Image.asset(
                    'assets/images/logo/app_logo.png',
                    width: 250,
                  ),
                ),
              ),
            ),
          ),
        ),

        Positioned(
          top: cardTop,
          left: 20,
          right: 20,
          bottom: 70,
          child: Card(
            color: Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, isSmallScreen ? 15 : 20, 20, 10),
              child: Column(
                children: [
                  SizedBox(
                    height: isSmallScreen ? 85 : 90,
                    child: _OptimizedCategoryList(
                      onCategoryTap: _handleCategoryTap,
                      isSmallScreen: isSmallScreen,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 5 : 10),
                  SizedBox(
                    height: isSmallScreen ? 45 : 50,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _handleSearch,
                      decoration: InputDecoration(
                        hintText: 'home.search_hint'.tr(),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFFD4352A),
                        ),
                        suffixIcon: _searchText.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () {
                                  AnalyticsService().logSearchBoxCleared();
                                  _searchController.clear();
                                  _handleSearch("");
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xC7FFFFFF).withOpacity(0.5),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedCategoryIndex == null
                            ? "${'home.nearby'.tr()} (${displayedRestaurants.length})"
                            : "${'categories.${categoryMap[selectedCategoryIndex!]}'.tr()} (${displayedRestaurants.length})",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      if (_isRefetching)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFD4352A),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: displayedRestaurants.isEmpty
                        ? Center(
                            child: Text(
                              _isRefetching
                                  ? 'home.finding'.tr()
                                  : 'home.not_found'.tr(),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(3),
                            itemCount: displayedRestaurants.length + 1,
                            itemBuilder: (context, index) {
                              if (index == displayedRestaurants.length) {
                                if (_nextPageToken == null &&
                                    _tomTomOffset == null) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 30.0,
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline,
                                          color: Color(0xFFD4352A),
                                          size: 40,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "home.list_end".tr(),
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontStyle: FontStyle.italic,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: _isLoadingMore
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFFD4352A),
                                          ),
                                        )
                                      : TextButton(
                                          onPressed: _loadMoreRestaurants,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              const Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2.0,
                                                ),
                                                child: const Icon(
                                                  Icons.refresh,
                                                  color: Color(0xFFD4352A),
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 2.0,
                                                ),
                                                child: Text(
                                                  "home.load_more".tr(),
                                                  style: const TextStyle(
                                                    color: Color(0xFFD4352A),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    height: 1.0,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              Image.asset(
                                                'assets/images/icons/ad.png',
                                                width: 24,
                                                height: 24,
                                                fit: BoxFit.contain,
                                              ),
                                            ],
                                          ),
                                        ),
                                );
                              }

                              final r = displayedRestaurants[index];
                              final isSelected = selectedRestaurants.contains(
                                r,
                              );
                              return Card(
                                clipBehavior: Clip.hardEdge,
                                elevation: isSelected ? 4 : 2,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  side: isSelected
                                      ? const BorderSide(
                                          color: Color(0xFFD4352A),
                                          width: 2,
                                        )
                                      : BorderSide.none,
                                ),
                                color: isSelected
                                    ? const Color.fromARGB(255, 247, 228, 228)
                                    : Colors.white,
                                child: ListTile(
                                  visualDensity: VisualDensity.compact,
                                  onTap: () => _toggleSelection(r),
                                  title: Text(
                                    r.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: isSelected
                                          ? const Color(0xFFD4352A)
                                          : Colors.black,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${r.category} • ${(r.distanceKm.toStringAsFixed(2))} ${'common.km'.tr()}',
                                  ),
                                  trailing: isSelected
                                      ? SizedBox(
                                          width: 100,
                                          child: TextButton.icon(
                                            onPressed: () {
                                              AnalyticsService()
                                                  .logDirectionsButtonFromList(
                                                    r.name,
                                                  );
                                              _openMaps(r.lat, r.lon, r.name);
                                            },
                                            icon: const Icon(
                                              Icons.directions,
                                              size: 16,
                                            ),
                                            label: Text(
                                              'home.directions'.tr(),
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(
                                                0xFFD4352A,
                                              ),
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                  ),

                  if (selectedRestaurants.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          AnalyticsService().logChooseSelectionButtonClicked(
                            selectedRestaurants.length,
                          );
                          if (selectedRestaurants.isEmpty) return;
                          if (selectedRestaurants.length < 2) {
                            _showWinnerDialog(
                              selectedRestaurants.first,
                              source: 'single_selection',
                            );
                            return;
                          }
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) {
                              return RouletteDialog(
                                selectedRestaurants: selectedRestaurants,

                                onWinnerFound: (winner) {
                                  _showWinnerDialog(winner, source: 'roulette');
                                },
                              );
                            },
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4352A),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        icon: const ImageIcon(
                          AssetImage('assets/images/roulette_wheel/wheel.png'),
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          "${'home.pick_button'.tr()} (${selectedRestaurants.length})",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OptimizedCategoryList extends StatefulWidget {
  final Function(int) onCategoryTap;
  final bool isSmallScreen;
  const _OptimizedCategoryList({
    required this.onCategoryTap,
    this.isSmallScreen = false,
  });
  @override
  State<_OptimizedCategoryList> createState() => _OptimizedCategoryListState();
}

class _OptimizedCategoryListState extends State<_OptimizedCategoryList> {
  int? _animatingIndex;
  final List<IconData> _icons = [
    Icons.lunch_dining,
    Icons.kebab_dining,
    Icons.restaurant_menu,
    Icons.fastfood,
    Icons.local_pizza,
    Icons.dinner_dining,
    Icons.set_meal,
    Icons.soup_kitchen,
    Icons.coffee,
    Icons.cake,
    Icons.local_dining,
    Icons.wine_bar,
  ];

  @override
  Widget build(BuildContext context) {
    double boxSize = widget.isSmallScreen ? 60 : 74;
    String langCode = context.locale.languageCode;
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _icons.length,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemBuilder: (context, index) {
        final isAnimating = _animatingIndex == index;
        String imagePath = (langCode == 'en')
            ? 'assets/images/categories_english/category_english${index + 1}.png'
            : 'assets/images/categories_turkish/category_turkish${index + 1}.png';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: GestureDetector(
            onTap: () {
              setState(() => _animatingIndex = index);
              widget.onCategoryTap(index);
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) setState(() => _animatingIndex = null);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: boxSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: isAnimating
                      ? const Color(0xFFD4352A)
                      : Colors.transparent,
                  width: isAnimating ? 3 : 0,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipOval(
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      _icons[index],
                      color: const Color(0xFFD4352A),
                      size: widget.isSmallScreen ? 22 : 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
