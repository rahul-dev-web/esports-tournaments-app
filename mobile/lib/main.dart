import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config.dart';
import 'core/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }

  runApp(const ProviderScope(child: ArenaHubApp()));
}

class ArenaHubApp extends StatelessWidget {
  const ArenaHubApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'ArenaHub', debugShowCheckedModeBanner: false, routerConfig: appRouter,
    theme: ThemeData(colorSchemeSeed: const Color(0xff6750a4), useMaterial3: true),
  );
}
