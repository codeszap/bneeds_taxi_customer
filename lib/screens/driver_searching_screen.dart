import 'package:bneeds_taxi_customer/repositories/profile_repository.dart';
import 'package:bneeds_taxi_customer/utils/sharedPrefrencesHelper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ------------------- ENUM + STATE + PROVIDER -------------------

enum DriverSearchStatus { idle, searching, found, error }

class DriverSearchState {
  final DriverSearchStatus status;
  const DriverSearchState({required this.status});
}

class DriverSearchNotifier extends StateNotifier<DriverSearchState> {
  DriverSearchNotifier(this.ref)
      : super(const DriverSearchState(status: DriverSearchStatus.idle));

  final Ref ref;

  void startSearch() {
    state = const DriverSearchState(status: DriverSearchStatus.searching);
  }

  void markDriverFound() {
    state = const DriverSearchState(status: DriverSearchStatus.found);
  }

  void setError() {
    state = const DriverSearchState(status: DriverSearchStatus.error);
  }

  void cancelSearch() {
    state = const DriverSearchState(status: DriverSearchStatus.idle);
  }
}

final driverSearchProvider =
StateNotifierProvider<DriverSearchNotifier, DriverSearchState>(
      (ref) => DriverSearchNotifier(ref),
);

// ------------------- MAIN SCREEN -------------------

class DriverSearchingScreen extends ConsumerStatefulWidget {
  const DriverSearchingScreen({super.key});

  @override
  ConsumerState<DriverSearchingScreen> createState() =>
      _DriverSearchingScreenState();
}

class _DriverSearchingScreenState extends ConsumerState<DriverSearchingScreen> {
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverSearchProvider);
    final notifier = ref.read(driverSearchProvider.notifier);

    // When driver found → navigate to tracking screen
    if (state.status == DriverSearchStatus.found) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/tracking');
      });
    }

    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: switch (state.status) {
            DriverSearchStatus.searching => _buildSearchingUI(context, notifier),
            DriverSearchStatus.error => _buildErrorUI(context, notifier),
            _ => _buildSearchingUI(context, notifier),
          },
        ),
      ),
    );
  }

  Widget _buildSearchingUI(BuildContext context, DriverSearchNotifier notifier) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 150,
          width: 150,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.deepPurple.shade100,
          ),
          child: const CircularProgressIndicator(
            strokeWidth: 6,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          "Searching for nearby drivers...",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        const Text(
          "Please wait while we find your best driver",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () {
            notifier.cancelSearch();
            context.go('/home');
          },
          icon: const Icon(Icons.close),
          label: const Text("Cancel Ride"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorUI(BuildContext context, DriverSearchNotifier notifier) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent, size: 80),
        const SizedBox(height: 20),
        const Text(
          "No drivers available nearby",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        const Text(
          "Please try again later or change your pickup location.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () {
            notifier.cancelSearch();
            context.go('/home');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text("Go Home"),
        ),
      ],
    );
  }
}
