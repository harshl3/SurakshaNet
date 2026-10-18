import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/investigation_model.dart';
import '../repositories/investigation_repository.dart';

final investigationRepositoryProvider = Provider<InvestigationRepository>((ref) {
  return InvestigationRepository();
});

final investigationListProvider = FutureProvider.autoDispose<List<InvestigationCaseModel>>((ref) async {
  final repo = ref.watch(investigationRepositoryProvider);
  final res = await repo.getAllCases(size: 100);
  return res.items;
});

final singleInvestigationProvider =
    FutureProvider.family.autoDispose<InvestigationCaseModel, int>((ref, id) async {
  final repo = ref.watch(investigationRepositoryProvider);
  return repo.getCaseById(id);
});

class CreateInvestigationState {
  final bool isSubmitting;
  final String? errorMessage;
  final InvestigationCaseModel? createdCase;

  const CreateInvestigationState({
    this.isSubmitting = false,
    this.errorMessage,
    this.createdCase,
  });

  CreateInvestigationState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    InvestigationCaseModel? createdCase,
  }) {
    return CreateInvestigationState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      createdCase: createdCase ?? this.createdCase,
    );
  }
}

class CreateInvestigationNotifier extends StateNotifier<CreateInvestigationState> {
  final InvestigationRepository _repository;

  CreateInvestigationNotifier(this._repository)
      : super(const CreateInvestigationState());

  Future<InvestigationCaseModel?> submitCase(Map<String, dynamic> data) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final res = await _repository.createCase(data);
      state = state.copyWith(
        isSubmitting: false,
        createdCase: res,
      );
      return res;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  void reset() {
    state = const CreateInvestigationState();
  }
}

final createInvestigationProvider =
    StateNotifierProvider.autoDispose<CreateInvestigationNotifier, CreateInvestigationState>((ref) {
  final repo = ref.watch(investigationRepositoryProvider);
  return CreateInvestigationNotifier(repo);
});
