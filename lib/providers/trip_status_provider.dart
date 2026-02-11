import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/sharedPrefrencesHelper.dart';

final tripStatusProvider =
    StateNotifierProvider<TripStatusNotifier, TripStatusState>((ref) {
      return TripStatusNotifier();
    });

class TripStatusState {
  final bool isSearching;
  final bool tripAccepted;
  final bool tripStarted;
  final bool tripCompleted;

  TripStatusState({
    required this.isSearching,
    required this.tripAccepted,
    required this.tripStarted,
    required this.tripCompleted,
  });
}

class TripStatusNotifier extends StateNotifier<TripStatusState> {
  TripStatusNotifier()
    : super(
        TripStatusState(
          isSearching: false,
          tripAccepted: false,
          tripStarted: false,
          tripCompleted: false,
        ),
      ) {
    loadStatus();
  }

  Future<void> loadStatus() async {
    final searching = await SharedPrefsHelper.getIsSearching();
    final accepted = await SharedPrefsHelper.getTripAccepted();
    final started = await SharedPrefsHelper.getTripStarted();
    final completed = await SharedPrefsHelper.getTripCompleted();
    state = TripStatusState(
      isSearching: searching,
      tripAccepted: accepted,
      tripStarted: started,
      tripCompleted: completed,
    );
  }

  Future<void> updateSearching(bool value) async {
    await SharedPrefsHelper.setIsSearching(value);
    state = TripStatusState(
      isSearching: value,
      tripAccepted: state.tripAccepted,
      tripStarted: state.tripStarted,
      tripCompleted: state.tripCompleted,
    );
  }

  Future<void> updateAccepted(bool value) async {
    await SharedPrefsHelper.saveTripAccepted(value);
    state = TripStatusState(
      isSearching: state.isSearching,
      tripAccepted: value,
      tripStarted: state.tripStarted,
      tripCompleted: state.tripCompleted,
    );
  }

  Future<void> updateStarted(bool value) async {
    await SharedPrefsHelper.saveTripStarted(value);
    state = TripStatusState(
      isSearching: state.isSearching,
      tripAccepted: state.tripAccepted,
      tripStarted: value,
      tripCompleted: state.tripCompleted,
    );
  }

  Future<void> updateCompleted(bool value) async {
    await SharedPrefsHelper.setTripCompleted(value);
    state = TripStatusState(
      isSearching: state.isSearching,
      tripAccepted: state.tripAccepted,
      tripStarted: state.tripStarted,
      tripCompleted: value,
    );
  }

  Future<void> refresh() async {
    await loadStatus();
  }
}
