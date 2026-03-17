import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:pick_a_place/models/analytics_service.dart';

const String googleApiKey = "";
const String tomTomApiKey = "";

class Restaurant {
  final String id;
  final String name;
  final String category;
  final double lat;
  final double lon;
  double distanceKm;
  final String? address;

  Restaurant({
    this.id = '',
    required this.name,
    required this.category,
    required this.lat,
    required this.lon,
    this.distanceKm = 0.0,
    this.address,
  });
}

class PlacesResponse {
  final List<Restaurant> restaurants;
  final String? nextPageToken;
  final int? tomTomOffset;
  final String source;

  PlacesResponse({
    required this.restaurants,
    this.nextPageToken,
    this.tomTomOffset,
    required this.source,
  });
}

class CategoryFilterService {
  static final CategoryFilterService _instance =
      CategoryFilterService._internal();
  factory CategoryFilterService() => _instance;
  CategoryFilterService._internal();

  List<dynamic> _rules = [];
  String _defaultCategory = "Restaurant";
  bool _isLoaded = false;
  String _currentLang = "";

  Future<void> loadFilters(String languageCode) async {
    if (_isLoaded && _currentLang == languageCode) return;
    try {
      String fileName = (languageCode == 'tr')
          ? 'category_filters_tr.json'
          : 'category_filters_en.json';
      final String jsonString = await rootBundle.loadString(
        'assets/files/$fileName',
      );
      final Map<String, dynamic> data = json.decode(jsonString);
      _defaultCategory = data['default_category'] ?? "Restaurant";
      _rules = data['rules'] ?? [];
      _isLoaded = true;
      _currentLang = languageCode;
    } catch (e) {
      _isLoaded = true;
    }
  }

  String translate(String rawCategoryName, String placeName) {
    if (!_isLoaded) return _defaultCategory;
    String lowerRawCat = rawCategoryName.toLowerCase();
    String lowerName = placeName.toLowerCase();

    for (var rule in _rules) {
      String target = rule['target'];
      for (var keyword in (rule['check_name'] ?? [])) {
        if (lowerName.contains(keyword.toString().toLowerCase())) return target;
      }
      for (var keyword in (rule['check_category'] ?? [])) {
        if (lowerRawCat.contains(keyword.toString().toLowerCase())) {
          return target;
        }
      }
    }
    if (_isLoaded) {
      AnalyticsService().logUnknownCategoryDetected(rawCategoryName, placeName);
    }
    return _defaultCategory;
  }
}

Future<PlacesResponse> fetchRestaurantsSmart({
  required double lat,
  required double lon,
  required int radius,
  required String languageCode,
  String? googleToken,
  int? tomTomOffset,
}) async {
  if (tomTomOffset != null && googleToken == null) {
    return await _fetchTomTom(
      lat,
      lon,
      radius,
      languageCode,
      offset: tomTomOffset,
    );
  }

  try {
    return await _fetchGoogle(
      lat,
      lon,
      radius,
      languageCode,
      pageToken: googleToken,
    );
  } catch (e) {
    debugPrint("⚠️ Google API Patladı: $e. TomTom'a geçiliyor...");

    AnalyticsService().logApiFailover(reason: e.toString());
    FirebaseCrashlytics.instance.log("Failover to TomTom triggered. Error: $e");

    return await _fetchTomTom(lat, lon, radius, languageCode, offset: 0);
  }
}

Future<PlacesResponse> _fetchGoogle(
  double lat,
  double lon,
  int radius,
  String languageCode, {
  String? pageToken,
}) async {
  final stopwatch = Stopwatch()..start();
  await CategoryFilterService().loadFilters(languageCode);

  final url = Uri.parse('https://places.googleapis.com/v1/places:searchText');
  final headers = {
    'Content-Type': 'application/json',
    'X-Goog-Api-Key': googleApiKey,
    'X-Goog-FieldMask':
        'places.name,places.displayName,places.location,places.primaryTypeDisplayName,nextPageToken',
  };

  String queryText = "yemek, restaurant, fast food, cafe, chicken";

  final body = jsonEncode({
    "textQuery": queryText,
    "locationBias": {
      "circle": {
        "center": {"latitude": lat, "longitude": lon},
        "radius": 1000,
      },
    },

    "rankPreference": "DISTANCE",
    "pageSize": 20,
    "pageToken": pageToken,
  });

  final response = await http.post(url, headers: headers, body: body);

  if (response.statusCode == 200) {
    final jsonResponse = jsonDecode(response.body);
    List<dynamic> places = jsonResponse['places'] ?? [];

    List<String> debugNames = [];
    List<String> debugCategories = [];

    for (var p in places) {
      String n = p['displayName'] != null ? p['displayName']['text'] : "NoName";

      String c = p['primaryTypeDisplayName'] != null
          ? p['primaryTypeDisplayName']['text']
          : (p['primaryType'] ?? "unknown");

      debugNames.add(n);
      debugCategories.add(c);
    }

    AnalyticsService().logRawApiResponse(
      provider: 'google',
      itemCount: places.length,
      isSuccess: true,
      radius: radius,
      rawNames: debugNames,
      rawCategories: debugCategories,
    );

    List<Restaurant> restaurants = places.map((place) {
      String rawCat = place['primaryTypeDisplayName'] != null
          ? place['primaryTypeDisplayName']['text']
          : "";
      String name = place['displayName'] != null
          ? place['displayName']['text']
          : "Mekan";

      return Restaurant(
        id: place['name'] ?? '',
        name: name,
        category: CategoryFilterService().translate(rawCat, name),
        lat: place['location']['latitude'],
        lon: place['location']['longitude'],
        distanceKm: 0.0,
        address: "",
      );
    }).toList();

    stopwatch.stop();
    AnalyticsService().logApiLatency(
      provider: 'google',
      durationMs: stopwatch.elapsedMilliseconds,
    );

    return PlacesResponse(
      restaurants: restaurants,
      nextPageToken: jsonResponse['nextPageToken'],
      source: 'google',
    );
  } else {
    AnalyticsService().logRawApiResponse(
      provider: 'google',
      itemCount: 0,
      isSuccess: false,
      radius: radius,
      errorDetails: "${response.statusCode} - ${response.body}",
    );

    throw Exception("Google Error: ${response.statusCode} - ${response.body}");
  }
}

Future<PlacesResponse> _fetchTomTom(
  double lat,
  double lon,
  int radius,
  String languageCode, {
  int offset = 0,
}) async {
  final stopwatch = Stopwatch()..start();
  await CategoryFilterService().loadFilters(languageCode);

  String tomTomLang = (languageCode == 'tr') ? 'tr-TR' : 'en-US';

  String queryText = 'restaurant';

  final uri = Uri.https('api.tomtom.com', '/search/2/search/$queryText.json', {
    'key': tomTomApiKey,
    'lat': lat.toString(),
    'lon': lon.toString(),
    'radius': radius.toString(),
    'categorySet': '7315',
    'limit': '20',
    'ofs': offset.toString(),
    'language': tomTomLang,
  });

  debugPrint("🌍 TomTom Request: $uri");

  try {
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'] ?? [];

      List<String> debugNames = [];
      List<String> debugCategories = [];

      for (var r in results) {
        var poi = r['poi'];
        String n = poi['name'] ?? "NoName";

        var cats = poi['categories'] as List<dynamic>?;
        String c = (cats != null && cats.isNotEmpty)
            ? cats.first.toString()
            : "unknown";

        debugNames.add(n);
        debugCategories.add(c);
      }

      AnalyticsService().logRawApiResponse(
        provider: 'tomtom',
        itemCount: results.length,
        isSuccess: true,
        radius: radius,
        rawNames: debugNames,
        rawCategories: debugCategories,
      );

      List<Restaurant> restaurants = results.map((place) {
        var poi = place['poi'];
        var position = place['position'];
        var categories = poi['categories'] as List<dynamic>?;
        String rawCat = (categories != null && categories.isNotEmpty)
            ? categories.first
            : "";
        String name = poi['name'] ?? "Mekan";

        return Restaurant(
          id: place['id'] ?? '',
          name: name,
          category: CategoryFilterService().translate(rawCat, name),
          lat: position['lat'],
          lon: position['lon'],
          distanceKm: 0.0,
          address: place['address'] != null
              ? place['address']['freeformAddress']
              : "",
        );
      }).toList();

      int? nextOffset = (results.length >= 20) ? offset + 20 : null;

      stopwatch.stop();
      AnalyticsService().logApiLatency(
        provider: 'tomtom',
        durationMs: stopwatch.elapsedMilliseconds,
      );

      return PlacesResponse(
        restaurants: restaurants,
        tomTomOffset: nextOffset,
        source: 'tomtom',
      );
    } else {
      AnalyticsService().logRawApiResponse(
        provider: 'tomtom',
        itemCount: 0,
        isSuccess: false,
        radius: radius,
        errorDetails: "Status: ${response.statusCode} Body: ${response.body}",
      );

      throw Exception(
        "TomTom Error: ${response.statusCode} - ${response.body}",
      );
    }
  } catch (e) {
    AnalyticsService().logRawApiResponse(
      provider: 'tomtom',
      itemCount: 0,
      isSuccess: false,
      radius: radius,
      errorDetails: "Exception: $e",
    );
    debugPrint("TomTom da çalışmadı: $e");
    return PlacesResponse(restaurants: [], source: 'error');
  }
}
