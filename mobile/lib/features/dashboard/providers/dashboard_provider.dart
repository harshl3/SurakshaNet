import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_stats.dart';
import '../repositories/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.getStats();
});
