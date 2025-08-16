import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile_model.dart';
import '../repositories/profile_repository.dart';

final profileRepositoryProvider = Provider((ref) => ProfileRepository());

/// Fetch Profile Provider
final fetchProfileProvider = FutureProvider.family<List<UserProfile>, Map<String, String>>((ref, creds) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.fetchUserProfile(
    mobileno: creds['mobileno']!,
       // mobileno: "9874512036",
  );
});

/// Insert Profile Provider
final insertProfileProvider = FutureProvider.family
    .autoDispose<String, ({UserProfile profile, String action})>((ref, args) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.saveUserProfile(args.profile, args.action);
});

