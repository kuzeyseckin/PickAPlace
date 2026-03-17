import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pick_a_place/models/analytics_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLanguageExpanded = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService().logSettingsOpened();
    AnalyticsService().logScreenView('settings_screen');
  }

  @override
  void dispose() {
    AnalyticsService().logSettingsClosed();
    super.dispose();
  }

  void _changeLanguage(Locale locale) {
    String fromLang = context.locale.languageCode;
    context.setLocale(locale);
    AnalyticsService().logLanguageChanged(fromLang, locale.languageCode);
    AnalyticsService().setUserProperties(
      preferredLanguage: locale.languageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    bool isSmallScreen = height < 700;

    double topPadding = MediaQuery.of(context).padding.top;
    double headerHeight =
        topPadding +
        (isSmallScreen ? 52.0 : (width * 0.14).clamp(26.0, 100.0)) +
        130;
    double cardTopPosition =
        topPadding +
        (isSmallScreen ? 52.0 : (width * 0.14).clamp(26.0, 100.0)) +
        30;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 8),
                  ),
                ],
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
            top: cardTopPosition,
            left: 20,
            right: 20,
            bottom: 80,
            child: Card(
              color: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 25,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "settings.title".tr(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Divider(height: 30),

                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: _isLanguageExpanded
                            ? const Color(0xFFF9F9F9)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(15),
                        border: _isLanguageExpanded
                            ? Border.all(color: Colors.grey.shade200)
                            : Border.all(color: Colors.transparent),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isLanguageExpanded = !_isLanguageExpanded;
                              });
                            },
                            borderRadius: BorderRadius.circular(15),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F1F1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.language,
                                      color: Color(0xFFD4352A),
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "settings.language".tr(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        Text(
                                          context.locale ==
                                                  const Locale('tr', 'TR')
                                              ? "settings.lang_tr".tr()
                                              : "settings.lang_en".tr(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFD4352A),
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    _isLanguageExpanded
                                        ? Icons.keyboard_arrow_up
                                        : Icons.keyboard_arrow_down,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isLanguageExpanded) ...[
                            const Divider(height: 1),
                            _buildLanguageOption(
                              labelKey: "settings.lang_tr",
                              locale: const Locale('tr', 'TR'),
                              flagCode: "🇹🇷",
                            ),
                            const Divider(height: 1, indent: 20, endIndent: 20),
                            _buildLanguageOption(
                              labelKey: "settings.lang_en",
                              locale: const Locale('en', 'US'),
                              flagCode: "🇺🇸",
                            ),
                            const SizedBox(height: 5),
                          ],
                        ],
                      ),
                    ),

                    const Spacer(),
                    Center(
                      child: Text(
                        "Pick A Place v1.0.0",
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption({
    required String labelKey,
    required Locale locale,
    required String flagCode,
  }) {
    bool isSelected = context.locale == locale;
    return InkWell(
      onTap: () => _changeLanguage(locale),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        color: isSelected ? const Color(0xFFFCEBEA) : Colors.transparent,
        child: Row(
          children: [
            Text(flagCode, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 15),
            Text(
              labelKey.tr(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFFD4352A) : Colors.black87,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFD4352A),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
