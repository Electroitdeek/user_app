import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../data/models/provider_models/bank_detail_model.dart';
import '../../../../data/repositories/provider_repository.dart';

abstract class ProviderBankDetailEvent {}

class FetchBankDetail extends ProviderBankDetailEvent {}

class SaveBankDetailEvent extends ProviderBankDetailEvent {
  final String? bankDetailId;
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String branchName;
  final String accountType;
  final bool isPrimary;

  SaveBankDetailEvent({
    this.bankDetailId,
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.bankName,
    required this.branchName,
    required this.accountType,
    required this.isPrimary,
  });
}

abstract class ProviderBankDetailState {}

class BankDetailInitial extends ProviderBankDetailState {}

class BankDetailLoading extends ProviderBankDetailState {}

class BankDetailLoaded extends ProviderBankDetailState {
  final BankDetail bankDetail;
  BankDetailLoaded(this.bankDetail);
}

class BankDetailSaving extends ProviderBankDetailState {}

class BankDetailSaved extends ProviderBankDetailState {}

class BankDetailEmpty extends ProviderBankDetailState {}

class BankDetailError extends ProviderBankDetailState {
  final String message;
  BankDetailError(this.message);
}

class ProviderBankDetailBloc
    extends Bloc<ProviderBankDetailEvent, ProviderBankDetailState> {
  final ProviderRepository _repository;
  ProviderBankDetailBloc(this._repository) : super(BankDetailInitial()) {
    on<FetchBankDetail>((event, emit) async {
      emit(BankDetailLoading());
      try {
        final data = await _repository.getBankDetail();
        if (data != null) {
          emit(BankDetailLoaded(data));
        } else {
          emit(BankDetailEmpty());
        }
      } catch (e) {
        emit(BankDetailError(e.toString()));
      }
    });

    on<SaveBankDetailEvent>((event, emit) async {
      emit(BankDetailSaving());
      try {
        final success = await _repository.saveBankDetail(
          bankDetailId: event.bankDetailId,
          accountHolderName: event.accountHolderName,
          accountNumber: event.accountNumber,
          ifscCode: event.ifscCode,
          bankName: event.bankName,
          branchName: event.branchName,
          accountType: event.accountType,
          isPrimary: event.isPrimary,
        );
        if (success) {
          emit(BankDetailSaved());
        } else {
          emit(BankDetailError('Failed to save bank details.'));
        }
      } catch (e) {
        emit(BankDetailError(e.toString()));
      }
    });
  }
}
