import 'package:flutter/material.dart';
import 'package:pick_a_place/models/ad_manager.dart';

class GoogleBannerAd extends StatelessWidget {
  const GoogleBannerAd({super.key});

  @override
  Widget build(BuildContext context) {
    if (AdManager.instance.isBannerLoaded) {
      return Container(
        alignment: Alignment.center,
        width: 320,
        height: 50,
        child: AdManager.instance.getBannerWidget(),
      );
    }

    return Container(
      height: 50,
      width: 320,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
        ),
      ),
    );
  }
}
