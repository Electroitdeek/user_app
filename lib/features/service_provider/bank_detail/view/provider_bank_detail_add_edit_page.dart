import 'package:adhisaat_health_care/core/theme/app_colors.dart';
import 'package:adhisaat_health_care/core/theme/app_text_styles.dart';
import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import 'package:adhisaat_health_care/core/utils/message_service.dart';
import 'package:adhisaat_health_care/data/models/provider_models/bank_detail_model.dart';
import 'package:adhisaat_health_care/data/repositories/provider_repository.dart';
import 'package:adhisaat_health_care/di/locator.dart';
import 'package:adhisaat_health_care/features/service_provider/bank_detail/bloc/provider_bank_detail_bloc.dart';
import 'package:adhisaat_health_care/shared/widgets/buttons/custom_button.dart';
import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:adhisaat_health_care/shared/widgets/dialogs/dialog_helpers.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_drop_down.dart';
import 'package:adhisaat_health_care/shared/widgets/inputs/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProviderBankDetailAddEditPage extends StatefulWidget {
  final BankDetail? bankDetail;

  const ProviderBankDetailAddEditPage({super.key, this.bankDetail});

  @override
  State<ProviderBankDetailAddEditPage> createState() => _ProviderBankDetailAddEditPageState();
}

class _ProviderBankDetailAddEditPageState extends State<ProviderBankDetailAddEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _holderNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _ifscController;
  late TextEditingController _bankNameController;
  late TextEditingController _branchNameController;
  String _accountType = 'Savings';
  bool _isPrimary = true;

  @override
  void initState() {
    super.initState();
    _holderNameController = TextEditingController(text: widget.bankDetail?.accountHolderName);
    _accountNumberController = TextEditingController(text: widget.bankDetail?.accountNumber);
    _ifscController = TextEditingController(text: widget.bankDetail?.ifscCode);
    _bankNameController = TextEditingController(text: widget.bankDetail?.bankName);
    _branchNameController = TextEditingController(text: widget.bankDetail?.branchName);
    _accountType = widget.bankDetail?.accountType != null && widget.bankDetail!.accountType.isNotEmpty
        ? widget.bankDetail!.accountType[0].toUpperCase() +
              widget.bankDetail!.accountType.substring(1).toLowerCase()
        : 'Savings';
    _isPrimary = widget.bankDetail?.isPrimary ?? true;
  }

  @override
  void dispose() {
    _holderNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    _branchNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProviderBankDetailBloc(locator<ProviderRepository>()),
      child: BlocListener<ProviderBankDetailBloc, ProviderBankDetailState>(
        listener: (context, state) {
          if (state is BankDetailSaving) {
            DialogHelper.showLoading(message: 'Saving bank details...');
          } else if (state is BankDetailSaved) {
            Navigator.pop(context); // Hide loading
            DialogHelper.showSuccess(
              title: 'Success',
              message: 'Bank details saved successfully',
              onConfirm: () {
                Navigator.pop(context); // Pop Success Dialog
                Navigator.pop(context, true); // Go back to details page and trigger refresh
              },
            );
          } else if (state is BankDetailError) {
            Navigator.pop(context); // Hide loading
            MessageService.showError(state.message);
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: CustomAppBar(title: widget.bankDetail == null ? 'Add Bank Details' : 'Edit Bank Details'),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    CustomTextField(
                      controller: _holderNameController,
                      labelText: 'Account Holder Name',
                      hintText: 'Enter account holder name',
                      keyboardType: TextInputType.name,
                      isRequired: true,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter account holder name';
                        if (v.trim().length < 3) return 'Name must be at least 3 characters';
                        return null;
                      },
                    ),
                    AppSpacing.mVertical,
                    CustomTextField(
                      controller: _accountNumberController,
                      labelText: 'Account Number',
                      hintText: 'Enter account number',
                      keyboardType: TextInputType.number,
                      isNumeric: true,
                      maxLength: 18,
                      isRequired: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter account number';
                        if (v.trim().length < 9) return 'Account number must be at least 9 digits';
                        if (v.trim().length > 18) return 'Account number cannot exceed 18 digits';
                        return null;
                      },
                    ),
                    AppSpacing.mVertical,
                    CustomTextField(
                      controller: _ifscController,
                      labelText: 'IFSC Code',
                      hintText: 'E.g. SBIN0001234',
                      capitalizeAll: true,
                      maxLength: 11,
                      isRequired: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter IFSC code';
                        // final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
                        // if (!ifscRegex.hasMatch(v.trim().toUpperCase())) {
                        //   return 'Enter a valid IFSC code (e.g. SBIN0001234)';
                        // }
                        return null;
                      },
                    ),
                    AppSpacing.mVertical,
                    CustomTextField(
                      controller: _bankNameController,
                      labelText: 'Bank Name',
                      hintText: 'Enter bank name',
                      keyboardType: TextInputType.name,
                      isRequired: true,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter bank name';
                        if (v.trim().length < 2) return 'Bank name must be at least 2 characters';
                        return null;
                      },
                    ),
                    // AppSpacing.mVertical,
                    // CustomTextField(
                    //   controller: _branchNameController,
                    //   labelText: 'Branch Name',
                    //   hintText: 'Enter branch name',
                    //   keyboardType: TextInputType.name,
                    //   isRequired: true,
                    //   validator: (v) {
                    //     if (v == null || v.trim().isEmpty) return 'Please enter branch name';
                    //     if (v.trim().length < 2) return 'Branch name must be at least 2 characters';
                    //     return null;
                    //   },
                    // ),
                    AppSpacing.mVertical,
                    CustomDropDown<String>(
                      labelText: 'Account Type',
                      value: _accountType,
                      items: stringToDropdownItems(['Savings', 'Current']),
                      onChanged: (v) => setState(() => _accountType = v!),
                    ),
                    AppSpacing.xlVertical,
                    Builder(
                      builder: (context) => CustomButton(
                        width: double.infinity,
                        title: 'Save Details',
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            context.read<ProviderBankDetailBloc>().add(
                              SaveBankDetailEvent(
                                bankDetailId: widget.bankDetail?.id.toString(),
                                accountHolderName: _holderNameController.text.trim(),
                                accountNumber: _accountNumberController.text.trim(),
                                ifscCode: _ifscController.text.trim().toUpperCase(),
                                bankName: _bankNameController.text.trim(),
                                branchName: _branchNameController.text.trim(),
                                accountType: _accountType.toLowerCase(),
                                isPrimary: _isPrimary,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    AppSpacing.mVertical,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimaryColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: kPrimaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Please ensure that the bank account details match your professional records to avoid payment delays.',
              style: kTextNormal0(color: kPrimaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
