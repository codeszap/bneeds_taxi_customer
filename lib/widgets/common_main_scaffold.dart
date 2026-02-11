import 'package:flutter/material.dart';
import '../widgets/common_appbar.dart';
import '../widgets/common_drawer.dart';

class MainScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool showSearch;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  const MainScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.showSearch = false,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CommonDrawer(),
      appBar: CommonAppBar(title: title, actions: actions),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
