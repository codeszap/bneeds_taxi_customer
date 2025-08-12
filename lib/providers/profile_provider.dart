import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile_model.dart';
import '../repositories/profile_repository.dart';

final profileRepositoryProvider = Provider((ref) => ProfileRepository());

/// Fetch Profile Provider
final fetchProfileProvider = FutureProvider.family<List<UserProfile>, Map<String, String>>((ref, creds) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.fetchUserProfile(
    mobileno: creds['mobileno']!,
  );
});

/// Insert Profile Provider
final insertProfileProvider = FutureProvider.family<String, UserProfile>((ref, profile) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.insertUserProfile(profile);
});
