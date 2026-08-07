import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Profile')), body: ListView(padding: const EdgeInsets.all(20), children: const [
    CircleAvatar(radius: 42, child: Icon(Icons.person, size: 42)), SizedBox(height: 16),
    TextField(decoration: InputDecoration(labelText: 'Name')), TextField(decoration: InputDecoration(labelText: 'Username')), TextField(decoration: InputDecoration(labelText: 'Preferred game')),
  ]));
}
