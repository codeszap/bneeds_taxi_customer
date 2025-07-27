import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/common_appbar.dart';
import '../../widgets/common_drawer.dart';


class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      
      drawer: CommonDrawer(onLogout: () {}),
  appBar: CommonAppBar(
    title: "Home",
    showSearch: true,
    onSearchChanged: (text) {
      print("User searched: $text");
    },
    actions: [
      IconButton(
        icon: Icon(Icons.notifications),
        onPressed: () {},
      ),
    ],
  ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('👋 Welcome, saf.dev!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            const Text('🔢 Counter:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Action
              },
              child: const Text('Increment Counter'),
            ),
          ],
        ),
      ),
    );
  }
}
