# AdMob

Configured externally:

- Android and iOS apps are registered.
- Rewarded ad units exist for both platforms.

Implementation status:

- Backend exposes an AdMob SSV endpoint at `/api/ads/admob/ssv`.
- SSV signature verification uses the AdMob public key server and caches keys for up to 24 hours.
- Reward progress is tracked in `reward_ad_events` and `tournament_registrations`.

Environment variables:

- `ADMOB_ANDROID_APP_ID`
- `ADMOB_IOS_APP_ID`
- `ADMOB_ANDROID_REWARDED_AD_UNIT_ID`
- `ADMOB_IOS_REWARDED_AD_UNIT_ID`
- `ADMOB_SSV_PUBLIC_KEYS_URL`

Client action still required:

- Configure the final SSV callback URL after backend deployment.

