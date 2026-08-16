import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config.dart';

/// Presents a rewarded AdMob ad after the backend has issued a short-lived
/// verification session. Registration success is never decided by this
/// client callback; AdMob SSV remains the backend source of truth.
class RewardedAdService {
  String get _adUnitId {
    if (kIsWeb) return '';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return admobAndroidRewardedAdUnitId;
      case TargetPlatform.iOS:
        return admobIosRewardedAdUnitId;
      default:
        return '';
    }
  }

  Future<bool> show({
    required String registrationId,
    required String userId,
    required String sessionToken,
  }) async {
    final adUnitId = _adUnitId;
    if (adUnitId.isEmpty) {
      throw StateError('Rewarded ad unit is not configured for this platform.');
    }

    final completer = Completer<bool>();
    RewardedAd? rewardedAd;

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) async {
          rewardedAd = ad;
          await ad.setServerSideOptions(
            ServerSideVerificationOptions(
              customData: '{"registration_id":"$registrationId","user_id":"$userId","session_token":"$sessionToken"}',
            ),
          );

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              if (!completer.isCompleted) completer.complete(false);
            },
          );

          ad.show(
            onUserEarnedReward: (_, __) {
              if (!completer.isCompleted) completer.complete(true);
            },
          );
        },
        onAdFailedToLoad: (error) {
          rewardedAd?.dispose();
          if (!completer.isCompleted) {
            completer.completeError(StateError('Rewarded ad failed to load: ${error.message}'));
          }
        },
      ),
    );

    return completer.future;
  }
}
