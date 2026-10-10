import 'package:adhisaat_health_care/shared/widgets/common/app_bar_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../data/shared_blocs/dropdown/dropdown_bloc.dart';
import '../../../../data/shared_blocs/dropdown/dropdown_state.dart';
import '../../../../shared/widgets/inputs/custom_drop_down.dart' show mapToDropdownItems;

import '../../../../core/theme/app_text_styles.dart';
import '../bloc/blood_request_bloc.dart';
import '../data/model/blood_request_model.dart';

class RequestBloodPage extends StatefulWidget {
  final String token;
  final BloodRequest? existingRequest;

  const RequestBloodPage({super.key, required this.token, this.existingRequest});

  @override
  State<RequestBloodPage> createState() => _RequestBloodPageState();
}

class _RequestBloodPageState extends State<RequestBloodPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  // Form controllers
  late TextEditingController _patientNameController;
  late TextEditingController _patientAgeController;
  late TextEditingController _unitsController;
  late TextEditingController _hospitalNameController;
  late TextEditingController _hospitalAddressController;
  late TextEditingController _hospitalCityController;
  late TextEditingController _hospitalStateController;
  late TextEditingController _hospitalContactController;
  late TextEditingController _diseaseConditionController;
  late TextEditingController _additionalNotesController;
  late TextEditingController _contactPersonNameController;
  late TextEditingController _contactPersonMobileController;
  late TextEditingController _contactPersonRelationController;

  String? _selectedBloodGroup;
  String? _selectedUrgency;
  DateTime? _requiredByDate;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  final List<String> _urgencyLevels = ['critical', 'urgent', 'normal'];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final request = widget.existingRequest;

    _patientNameController = TextEditingController(text: request?.patientName);
    _patientAgeController = TextEditingController(text: request?.patientAge);
    _unitsController = TextEditingController(text: request?.unitsRequired);
    _hospitalNameController = TextEditingController(text: request?.hospitalName);
    _hospitalAddressController = TextEditingController(text: request?.hospitalAddress);
    _hospitalCityController = TextEditingController(text: request?.hospitalCity);
    _hospitalStateController = TextEditingController(text: request?.hospitalState);
    _hospitalContactController = TextEditingController(text: request?.hospitalContact);
    _diseaseConditionController = TextEditingController(text: request?.diseaseCondition);
    _additionalNotesController = TextEditingController(text: request?.additionalNotes);
    _contactPersonNameController = TextEditingController(text: request?.contactPersonName);
    _contactPersonMobileController = TextEditingController(text: request?.contactPersonMobile);
    _contactPersonRelationController = TextEditingController(text: request?.contactPersonRelation);

    _selectedBloodGroup = request?.bloodGroupRequired;
    _selectedUrgency = request?.urgencyLevel;

    if (request?.requiredByDate != null) {
      try {
        _requiredByDate = DateTime.parse(request!.requiredByDate);
      } catch (e) {
        _requiredByDate = null;
      }
    }
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _patientAgeController.dispose();
    _unitsController.dispose();
    _hospitalNameController.dispose();
    _hospitalAddressController.dispose();
    _hospitalCityController.dispose();
    _hospitalStateController.dispose();
    _hospitalContactController.dispose();
    _diseaseConditionController.dispose();
    _additionalNotesController.dispose();
    _contactPersonNameController.dispose();
    _contactPersonMobileController.dispose();
    _contactPersonRelationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(title: widget.existingRequest != null ? 'Edit Request' : 'Request Blood'),
      body: BlocConsumer<BloodRequestBloc, BloodRequestState>(
        listener: (context, state) {
          if (state is BloodRequestSubmitSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
            Navigator.pop(context, true);
          }
          if (state is BloodRequestError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        builder: (context, state) {
          final isLoading = state is BloodRequestSubmitting;

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('Patient Information', [
                    _buildTextField(
                      controller: _patientNameController,
                      label: 'Patient Name',
                      icon: Icons.person,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _patientAgeController,
                      label: 'Patient Age',
                      icon: Icons.cake,
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildBloodGroupDropdown(),
                  ]),

                  const SizedBox(height: 16),
                  _buildSection('Request Details', [
                    _buildTextField(
                      controller: _unitsController,
                      label: 'Units Required',
                      icon: Icons.water_drop,
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildUrgencyDropdown(),
                    const SizedBox(height: 16),
                    _buildDatePicker(),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _diseaseConditionController,
                      label: 'Disease/Condition',
                      icon: Icons.medical_information,
                      maxLines: 2,
                    ),
                  ]),

                  const SizedBox(height: 16),
                  _buildSection('Hospital Information', [
                    _buildTextField(
                      controller: _hospitalNameController,
                      label: 'Hospital Name',
                      icon: Icons.local_hospital,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _hospitalAddressController,
                      label: 'Hospital Address',
                      icon: Icons.location_on,
                      maxLines: 2,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _hospitalCityController,
                            label: 'City',
                            icon: Icons.location_city,
                            validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _hospitalStateController,
                            label: 'State',
                            icon: Icons.map,
                            validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _hospitalContactController,
                      label: 'Hospital Contact',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (v.length != 10) return 'Invalid contact (10 digits required)';
                        return null;
                      },
                    ),
                  ]),

                  const SizedBox(height: 16),
                  _buildSection('Contact Person', [
                    _buildTextField(
                      controller: _contactPersonNameController,
                      label: 'Name',
                      icon: Icons.person_outline,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _contactPersonMobileController,
                      label: 'Mobile Number',
                      icon: Icons.phone_android,
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v?.isEmpty ?? true) return 'Required';
                        if (v!.length != 10) return 'Invalid mobile number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _contactPersonRelationController,
                      label: 'Relation with Patient',
                      icon: Icons.family_restroom,
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                  ]),

                  const SizedBox(height: 16),
                  _buildSection('Additional Information', [
                    _buildTextField(
                      controller: _additionalNotesController,
                      label: 'Additional Notes',
                      icon: Icons.note,
                      maxLines: 4,
                      hint: 'Any specific requirements or notes',
                    ),
                  ]),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(
                              widget.existingRequest != null ? 'Update Request' : 'Submit Request',
                              style: kTextSemiBold1().copyWith(color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(color: Colors.red[600], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Text(title, style: kTextSemiBold1()),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: validator,
    );
  }

  Widget _buildBloodGroupDropdown() {
    return BlocBuilder<DropdownBloc, DropdownState>(
      builder: (context, state) {
        final dropdownData = state is DropdownLoaded ? state.data : null;
        final items = dropdownData?.bloodGroups ?? { for (var e in _bloodGroups) e : e };
        
        return DropdownButtonFormField<String>(
          initialValue: _selectedBloodGroup,
          decoration: InputDecoration(
            labelText: 'Blood Group Required',
            prefixIcon: const Icon(Icons.bloodtype),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          items: mapToDropdownItems(items),
          onChanged: (value) {
            setState(() => _selectedBloodGroup = value);
          },
          validator: (value) => value == null ? 'Please select blood group' : null,
        );
      },
    );
  }

  Widget _buildUrgencyDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedUrgency,
      decoration: InputDecoration(
        labelText: 'Urgency Level',
        prefixIcon: const Icon(Icons.warning),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: _urgencyLevels.map((level) {
        return DropdownMenuItem(
          value: level,
          child: Row(
            children: [
              Icon(
                Icons.circle,
                size: 12,
                color: level == 'critical'
                    ? Colors.red
                    : level == 'urgent'
                    ? Colors.orange
                    : Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(level[0].toUpperCase() + level.substring(1)),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _selectedUrgency = value);
      },
      validator: (value) => value == null ? 'Please select urgency level' : null,
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _requiredByDate ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) {
          setState(() => _requiredByDate = date);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Required By Date',
          prefixIcon: const Icon(Icons.calendar_today),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        child: Text(
          _requiredByDate != null
              ? '${_requiredByDate!.day}/${_requiredByDate!.month}/${_requiredByDate!.year}'
              : 'Select Date',
          style: kTextNormal(),
        ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_requiredByDate == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select required by date')));
        return;
      }

      final request = BloodRequest(
        id: widget.existingRequest?.id,
        patientName: _patientNameController.text,
        patientAge: _patientAgeController.text,
        bloodGroupRequired: _selectedBloodGroup!,
        unitsRequired: _unitsController.text,
        urgencyLevel: _selectedUrgency!,
        requiredByDate: _requiredByDate!.toIso8601String().split('T')[0],
        hospitalName: _hospitalNameController.text,
        hospitalAddress: _hospitalAddressController.text,
        hospitalCity: _hospitalCityController.text,
        hospitalState: _hospitalStateController.text,
        hospitalContact: _hospitalContactController.text,
        diseaseCondition: _diseaseConditionController.text.isNotEmpty ? _diseaseConditionController.text : null,
        additionalNotes: _additionalNotesController.text.isNotEmpty ? _additionalNotesController.text : null,
        contactPersonName: _contactPersonNameController.text,
        contactPersonMobile: _contactPersonMobileController.text,
        contactPersonRelation: _contactPersonRelationController.text,
      );

      if (widget.existingRequest != null) {
        context.read<BloodRequestBloc>().add(UpdateBloodRequest(widget.token, request));
      } else {
        context.read<BloodRequestBloc>().add(AddBloodRequest(widget.token, request));
      }
    } else {
      // Scroll to first error
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }
}
