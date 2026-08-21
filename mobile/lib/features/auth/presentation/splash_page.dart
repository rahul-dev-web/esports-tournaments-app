import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: .86, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _timer = Timer(const Duration(milliseconds: 3000), _continue);
  }

  void _continue() {
    if (!mounted) return;
    final session = Supabase.instance.client.auth.currentSession;
    context.go(session == null ? '/login' : '/');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B18),
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -.18),
                radius: 1.05,
                colors: [const Color(0xFF20164A).withOpacity(.8), const Color(0xFF070B18), const Color(0xFF050711)],
                stops: const [0, .48, 1],
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: const LinearGradient(colors: [Color(0xFF8A5CFF), Color(0xFF39D0FF)]),
                        boxShadow: [BoxShadow(color: const Color(0xFF8A5CFF).withOpacity(.35), blurRadius: 34, spreadRadius: 2)],
                      ),
                      child: const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 42),
                    ),
                    const SizedBox(height: 22),
                    const Text('ArenaHub', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -.7)),
                    const SizedBox(height: 7),
                    const Text('COMPETE  •  REGISTER  •  WIN', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2.1)),
                    const SizedBox(height: 34),
                    SizedBox(width: 70, child: LinearProgressIndicator(minHeight: 2, borderRadius: BorderRadius.circular(2))),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(left: 0, right: 0, bottom: 30, child: Text('Free Fire Tournament Platform', textAlign: TextAlign.center, style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
