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
