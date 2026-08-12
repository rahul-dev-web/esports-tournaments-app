const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000/api',
);

const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: '',
);

const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

const String oauthRedirectUrl = String.fromEnvironment(
  'OAUTH_REDIRECT_URL',
  defaultValue: 'com.arenahub.arenahub_mobile://login-callback/',
);

const String admobAndroidAppId = String.fromEnvironment(
  'ADMOB_ANDROID_APP_ID',
  defaultValue: '',
);

const String admobIosAppId = String.fromEnvironment(
  'ADMOB_IOS_APP_ID',
  defaultValue: '',
);

const String admobAndroidRewardedAdUnitId = String.fromEnvironment(
  'ADMOB_ANDROID_REWARDED_AD_UNIT_ID',
  defaultValue: '',
);

const String admobIosRewardedAdUnitId = String.fromEnvironment(
  'ADMOB_IOS_REWARDED_AD_UNIT_ID',
  defaultValue: '',
);
