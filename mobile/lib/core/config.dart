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

const String firebaseApiKey = String.fromEnvironment(
  'FIREBASE_API_KEY',
  defaultValue: '',
);

const String firebaseAuthDomain = String.fromEnvironment(
  'FIREBASE_AUTH_DOMAIN',
  defaultValue: '',
);

const String firebaseProjectId = String.fromEnvironment(
  'FIREBASE_PROJECT_ID',
  defaultValue: '',
);

const String firebaseStorageBucket = String.fromEnvironment(
  'FIREBASE_STORAGE_BUCKET',
  defaultValue: '',
);

const String firebaseMessagingSenderId = String.fromEnvironment(
  'FIREBASE_MESSAGING_SENDER_ID',
  defaultValue: '',
);

const String firebaseAppId = String.fromEnvironment(
  'FIREBASE_APP_ID',
  defaultValue: '',
);

const String firebaseMeasurementId = String.fromEnvironment(
  'FIREBASE_MEASUREMENT_ID',
  defaultValue: '',
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
