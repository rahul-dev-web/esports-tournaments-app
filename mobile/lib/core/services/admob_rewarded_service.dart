import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';

class AdmobRewardedService {
  RewardedAd? _rewardedAd;

  String get rewardedAdUnitId {
    if (kIsWeb) {
      return '';
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return admobIosRewardedAdUnitId;
    }
    return admobAndroidRewardedAdUnitId;
  }

  Future<void> load({
    required String sessionToken,
    required String registrationId,
    required String userId,
  }) async {
    if (kIsWeb) {
      return;
    }

    if (rewardedAdUnitId.isEmpty) {
      throw StateError('AdMob rewarded ad unit id is not configured');
    }

    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedAd!.setServerSideOptions(
            ServerSideVerificationOptions(
              customData: '$registrationId|$userId|$sessionToken',
            ),
          );
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
        },
      ),
    );
  }

  Future<void> show({
    required OnUserEarnedRewardCallback onUserEarnedReward,
  }) async {
    final ad = _rewardedAd;
    if (ad == null) {
      throw StateError('Rewarded ad is not loaded');
    }

    _rewardedAd = null;
    await ad.show(onUserEarnedReward: onUserEarnedReward);
  }

  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
