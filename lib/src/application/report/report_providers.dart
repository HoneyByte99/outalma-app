import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth/auth_providers.dart';
import '../../data/repositories/firestore_report_repository.dart';
import '../../domain/models/report.dart';
import '../../domain/repositories/report_repository.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return FirestoreReportRepository(ref.watch(firestoreProvider));
});

class CreateReportUseCase {
  const CreateReportUseCase(this._repo);

  final ReportRepository _repo;

  Future<void> call({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
  }) async {
    final report = Report(
      id: '',
      reporterId: reporterId,
      targetType: targetType,
      targetId: targetId,
      reason: reason,
      details: details,
      createdAt: DateTime.now(),
    );
    await _repo.create(report);
  }
}

final createReportUseCaseProvider = Provider<CreateReportUseCase>((ref) {
  return CreateReportUseCase(ref.watch(reportRepositoryProvider));
});
