import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver getAnalyticsObserver() =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  Future<void> logAppOpened() async {
    await _analytics.logAppOpen();
  }

  Future<void> logLocationPermissionGranted() async {
    await _analytics.logEvent(name: 'location_permission_granted');
  }

  Future<void> logLocationPermissionDenied() async {
    await _analytics.logEvent(name: 'location_permission_denied');
  }

  Future<void> logLocationServiceDisabled() async {
    await _analytics.logEvent(name: 'location_service_disabled');
  }

  Future<void> logUserLocation(double lat, double lon) async {
    await _analytics.logEvent(
      name: 'user_current_location',
      parameters: {'latitude': lat, 'longitude': lon},
    );
  }

  Future<void> logInitialLanguage(String langCode) async {
    await _analytics.logEvent(
      name: 'default_language_detected',
      parameters: {'language': langCode},
    );

    await setUserProperties(preferredLanguage: langCode);
  }

  Future<void> logRestaurantsFetched({
    required int count,
    required double radiusKm,
    required String source,
  }) async {
    await _analytics.logEvent(
      name: 'restaurants_loaded',
      parameters: {
        'restaurant_count': count,
        'search_radius_km': radiusKm,
        'trigger_source': source,
      },
    );
  }

  Future<void> logHomeScreenReached() async {
    await _analytics.logEvent(name: 'home_screen_reached');
  }

  Future<void> logSessionApiUsage(int totalRequests) async {
    await _analytics.logEvent(
      name: 'session_api_usage',
      parameters: {'request_count': totalRequests},
    );
  }

  Future<void> logSearchBox(String searchTerm, int resultCount) async {
    await _analytics.logEvent(
      name: 'search_box_performed',
      parameters: {'search_term': searchTerm, 'result_count': resultCount},
    );
  }

  Future<void> logSearchBoxCleared() async {
    await _analytics.logEvent(name: 'search_box_cleared');
  }

  Future<void> logCategorySelected(String categoryName) async {
    await _analytics.logEvent(
      name: 'category_selected',
      parameters: {'category': categoryName},
    );
  }

  Future<void> logCategoryDeselected(String categoryName) async {
    await _analytics.logEvent(
      name: 'category_deselected',
      parameters: {'category': categoryName},
    );
  }

  Future<void> logRestaurantToggled({
    required String restaurantName,
    required String category,
    required double distanceKm,
    required bool isAdded,
  }) async {
    await _analytics.logEvent(
      name: isAdded ? 'restaurant_added' : 'restaurant_removed',
      parameters: {
        'restaurant_name': restaurantName,
        'category': category,
        'distance_km': distanceKm,
      },
    );
  }

  Future<void> logDirectionsButtonFromList(String restaurantName) async {
    await _analytics.logEvent(
      name: 'directions_button_from_list',
      parameters: {'restaurant': restaurantName},
    );
  }

  Future<void> logChooseSelectionButtonClicked(int selectedCount) async {
    await _analytics.logEvent(
      name: 'selection_choose_button_clicked',
      parameters: {'selected_count': selectedCount},
    );
  }

  Future<void> logRouletteOpened(int restaurantCount) async {
    await _analytics.logEvent(
      name: 'roulette_opened',
      parameters: {'restaurant_count': restaurantCount},
    );
  }

  Future<void> logRouletteSpinStarted() async {
    await _analytics.logEvent(name: 'roulette_spin_started');
  }

  Future<void> logRouletteWinner({
    required String winnerName,
    required String category,
    required double distanceKm,
    required int totalRestaurants,
  }) async {
    await _analytics.logEvent(
      name: 'roulette_winner',
      parameters: {
        'winner_name': winnerName,
        'category': category,
        'distance_km': distanceKm,
        'total_options': totalRestaurants,
      },
    );
  }

  Future<void> logWinnerDialogShown(
    String restaurantName,
    String source,
  ) async {
    await _analytics.logEvent(
      name: 'winner_dialog_shown',
      parameters: {'restaurant': restaurantName, 'source_type': source},
    );
  }

  Future<void> logWinnerButtonAccepted(String restaurantName) async {
    await _analytics.logEvent(
      name: 'winner_button_accepted',
      parameters: {'restaurant': restaurantName},
    );
  }

  Future<void> logDirectionsFromWinnerPopUp(String restaurantName) async {
    await _analytics.logEvent(
      name: 'directions_from_winner_PopUp',
      parameters: {'restaurant': restaurantName},
    );
  }

  Future<void> logSettingsOpened() async {
    await _analytics.logEvent(name: 'settings_opened');
  }

  Future<void> logLanguageChanged(String fromLang, String toLang) async {
    await _analytics.logEvent(
      name: 'language_changed',
      parameters: {'from_language': fromLang, 'to_language': toLang},
    );
  }

  Future<void> logSettingsClosed() async {
    await _analytics.logEvent(name: 'settings_closed');
  }

  Future<void> logBannerAdLoaded() async {
    await _analytics.logEvent(name: 'banner_ad_loaded');
  }

  Future<void> logBannerAdFailed(String error) async {
    await _analytics.logEvent(
      name: 'banner_ad_failed',
      parameters: {'error': error},
    );
  }

  Future<void> logInterstitialAdShown() async {
    await _analytics.logEvent(name: 'interstitial_ad_shown');
  }

  Future<void> logLoadMoreClicked() async {
    await _analytics.logEvent(name: 'load_more_clicked');
  }

  Future<void> logInterstitialAdClosed() async {
    await _analytics.logEvent(name: 'interstitial_ad_closed');
  }

  Future<void> logInterstitialAdFailed(String error) async {
    await _analytics.logEvent(
      name: 'interstitial_ad_failed',
      parameters: {'error': error},
    );
  }

  Future<void> logApiError(String errorMessage) async {
    await _analytics.logEvent(
      name: 'api_error',
      parameters: {'error': errorMessage},
    );
  }

  Future<void> logLocationError(String errorMessage) async {
    await _analytics.logEvent(
      name: 'location_error',
      parameters: {'error': errorMessage},
    );
  }

  Future<void> logNoRestaurantsFound(double radiusKm) async {
    await _analytics.logEvent(
      name: 'no_restaurants_found',
      parameters: {'search_radius_km': radiusKm},
    );
  }

  Future<void> logAppResumed() async {
    await _analytics.logEvent(name: 'app_resumed');
  }

  Future<void> logBannerAdClicked() async {
    await _analytics.logEvent(name: 'banner_ad_clicked');
  }

  Future<void> logInterstitialAdClicked() async {
    await _analytics.logEvent(name: 'interstitial_ad_clicked');
  }

  Future<void> logRestaurantsRefreshed(int newCount, double radiusKm) async {
    await _analytics.logEvent(
      name: 'restaurants_refreshed',
      parameters: {'new_count': newCount, 'radius_km': radiusKm},
    );
  }

  Future<void> logRouletteCancelled() async {
    await _analytics.logEvent(name: 'roulette_cancelled');
  }

  Future<void> setUserLanguage(String languageCode) async {
    await _analytics.setUserProperty(
      name: 'preferred_language',
      value: languageCode,
    );
  }

  Future<void> setUserAverageRadius(double radiusKm) async {
    await _analytics.setUserProperty(
      name: 'avg_search_radius',
      value: radiusKm.toStringAsFixed(1),
    );
  }

  Future<void> setUserFavoriteCategory(String category) async {
    await _analytics.setUserProperty(
      name: 'favorite_category',
      value: category,
    );
  }

  Future<void> logAppBackgrounded({
    int? selectedCount,
    int? displayedCount,
  }) async {
    await _analytics.logEvent(
      name: 'app_backgrounded',
      parameters: {
        if (selectedCount != null) 'selected_restaurants': selectedCount,
        if (displayedCount != null) 'displayed_restaurants': displayedCount,
      },
    );
  }

  Future<void> setUserProperties({
    String? preferredLanguage,
    double? defaultSearchRadius,
    int? totalRestaurantsSelected,
  }) async {
    if (preferredLanguage != null) {
      await _analytics.setUserProperty(
        name: 'preferred_language',
        value: preferredLanguage,
      );
    }
    if (defaultSearchRadius != null) {
      await _analytics.setUserProperty(
        name: 'default_search_radius',
        value: defaultSearchRadius.toStringAsFixed(1),
      );
    }
    if (totalRestaurantsSelected != null) {
      await _analytics.setUserProperty(
        name: 'selection_behavior',
        value: totalRestaurantsSelected < 3 ? 'quick_picker' : 'explorer',
      );
    }
  }

  Future<void> logFunnelStep(String funnelName, int step) async {
    await _analytics.logEvent(
      name: 'funnel_${funnelName}_step_$step',
      parameters: {'funnel': funnelName, 'step': step},
    );
  }

  Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  Future<void> logSessionQuality({
    required int restaurantsViewed,
    required int categoriesUsed,
    required int searchesPerformed,
    required Duration sessionDuration,
  }) async {
    await _analytics.logEvent(
      name: 'session_quality',
      parameters: {
        'restaurants_viewed': restaurantsViewed,
        'categories_used': categoriesUsed,
        'searches_performed': searchesPerformed,
        'session_duration_seconds': sessionDuration.inSeconds,
        'engagement_score': _calculateEngagementScore(
          restaurantsViewed,
          categoriesUsed,
          searchesPerformed,
        ),
      },
    );
  }

  Future<void> logAdSkippedNotReady() async {
    await _analytics.logEvent(name: 'ad_skipped_not_ready');
  }

  Future<void> logMapLaunchFailed(String error, String platform) async {
    await _analytics.logEvent(
      name: 'map_launch_failed',
      parameters: {'error': error, 'platform': platform},
    );
  }

  Future<void> logPermissionDialogAction(String action) async {
    await _analytics.logEvent(
      name: 'permission_dialog_interaction',
      parameters: {'action': action},
    );
  }

  Future<void> logUnknownCategoryDetected(
    String rawCategory,
    String placeName,
  ) async {
    await _analytics.logEvent(
      name: 'unknown_category_detected',
      parameters: {'raw_category': rawCategory, 'place_name': placeName},
    );
  }

  int _calculateEngagementScore(int viewed, int cats, int searches) {
    return (viewed * 2) + (cats * 5) + (searches * 3);
  }

  Future<void> logRawApiResponse({
    required String provider,
    required int itemCount,
    required bool isSuccess,
    int? radius,
    String? errorDetails,
    List<String>? rawNames,
    List<String>? rawCategories,
  }) async {
    String namesPreview = "";
    String catsPreview = "";

    if (rawNames != null && rawNames.isNotEmpty) {
      String joined = rawNames.join(", ");
      namesPreview = joined.length > 99 ? joined.substring(0, 99) : joined;
    }

    if (rawCategories != null && rawCategories.isNotEmpty) {
      String joined = rawCategories.join(", ");
      catsPreview = joined.length > 99 ? joined.substring(0, 99) : joined;
    }

    await _analytics.logEvent(
      name: 'api_raw_response',
      parameters: {
        'provider': provider,
        'item_count': itemCount,
        'status': isSuccess ? 'success' : 'failure',
        if (radius != null) 'radius_requested': radius,
        if (errorDetails != null) 'error_msg': errorDetails,

        'preview_names': namesPreview,
        'preview_categories': catsPreview,
      },
    );
  }

  Future<void> logApiFailover({required String reason}) async {
    await _analytics.logEvent(
      name: 'api_failover_triggered',
      parameters: {'reason': reason},
    );
  }

  Future<void> logApiLatency({
    required String provider,
    required int durationMs,
  }) async {
    await _analytics.logEvent(
      name: 'api_latency_performance',
      parameters: {
        'provider': provider,
        'duration_ms': durationMs,

        'performance_bucket': durationMs < 1000
            ? 'fast'
            : (durationMs < 3000 ? 'medium' : 'slow'),
      },
    );
  }
}
