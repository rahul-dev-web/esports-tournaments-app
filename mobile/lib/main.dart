import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';

void main() => runApp(const ProviderScope(child: ArenaHubApp()));

class ArenaHubApp extends StatelessWidget {
  const ArenaHubApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'ArenaHub', debugShowCheckedModeBanner: false, routerConfig: appRouter,
    theme: ThemeData(colorSchemeSeed: const Color(0xff6750a4), useMaterial3: true),
  );
}
