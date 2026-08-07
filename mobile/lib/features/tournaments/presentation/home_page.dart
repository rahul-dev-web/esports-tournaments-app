import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ArenaHub'), actions: [IconButton(onPressed: () => context.push('/profile'), icon: const Icon(Icons.person_outline))]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Text('Compete. Team up. Win.', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 20),
      const TournamentCard(name: 'Nightfall Championship', game: 'BGMI • Squad', reward: '₹10,000', slots: '12/32 teams'),
      const TournamentCard(name: 'Valorant Rush', game: 'Valorant • 5v5', reward: '₹25,000', slots: '8/16 teams'),
    ]),
    floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/login'), icon: const Icon(Icons.login), label: const Text('Sign in')),
  );
}

class TournamentCard extends StatelessWidget {
  final String name, game, reward, slots;
  const TournamentCard({super.key, required this.name, required this.game, required this.reward, required this.slots});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(name, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8), Text(game), const SizedBox(height: 14),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Reward: $reward'), Text(slots)]), const SizedBox(height: 14),
    SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () {}, child: const Text('View tournament'))),
  ])));
}
