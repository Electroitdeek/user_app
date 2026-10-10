import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:adhisaat_health_care/core/theme/screen_dimensions.dart';
import '../../../../data/providers/system_settings_provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_edge_insets.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../di/locator.dart';
import '../../../../shared/widgets/buttons/custom_button.dart';
import '../../../../shared/widgets/common/app_bar_custom.dart';
import '../../../../shared/widgets/dialogs/custom_dialogs.dart';
import '../bloc/availability_bloc.dart';
import '../bloc/availability_event.dart';
import '../bloc/availability_state.dart';
import '../data/models/weekly_availability_model.dart';
import '../data/repositories/availability_repository.dart';

class ProviderAvailabilityPage extends StatelessWidget {
  const ProviderAvailabilityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AvailabilityBloc(locator<AvailabilityRepository>())..add(LoadAvailability()),
      child: const _AvailabilityView(),
    );
  }
}

class _AvailabilityView extends StatefulWidget {
  const _AvailabilityView();

  @override
  State<_AvailabilityView> createState() => _AvailabilityViewState();
}

class _AvailabilityViewState extends State<_AvailabilityView> {
  String selectedDay = 'Monday';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScaffoldColor,
      appBar: const CustomAppBar(title: 'Work Schedule', backgroundColor: kScaffoldColor),
      body: BlocConsumer<AvailabilityBloc, AvailabilityState>(
        listener: (context, state) {
          if (state is AvailabilityUpdateSuccess) {
            showDialog(
              context: context,
              builder: (context) => const SuccessDialog(
                title: 'Success',
                message: 'Schedule updated successfully',
                buttonText: 'Done',
              ),
            );
          } else if (state is AvailabilityLoaded && state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: kErrorColor,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AvailabilityInitial || state is AvailabilityLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is AvailabilityError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48.sp, color: kErrorColor),
                  SizedBox(height: 16.h),
                  Text(state.message, style: kTextNormal(color: kErrorColor)),
                  SizedBox(height: 24.h),
                  CustomButton(
                    width: 120.w,
                    onPressed: () => context.read<AvailabilityBloc>().add(LoadAvailability()),
                    title: 'Retry',
                  ),
                ],
              ),
            );
          }

          if (state is AvailabilityLoaded) {
            return _buildContent(context, state);
          }

          return const SizedBox.shrink();
        },
      ),
      bottomNavigationBar: BlocBuilder<AvailabilityBloc, AvailabilityState>(
        builder: (context, state) {
          if (state is AvailabilityLoaded) {
            final validationError = state.availability.validate();
            final hasError = validationError != null;
            return SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      offset: const Offset(0, -10),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: CustomButton(
                  onPressed: (state.isUpdating || hasError)
                      ? null
                      : () => context.read<AvailabilityBloc>().add(UpdateAvailability()),
                  title: 'Apply Changes',
                  isLoading: state.isUpdating,
                  backgroundColor: hasError ? kDisableButtonColor : kPrimaryColor,
                  textStyle: kTextSemiBold2(color: Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  height: 54.h,
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, AvailabilityLoaded state) {
    final activeCount = state.availability.availability.values
        .where((slots) => slots.any((s) => s.isActive))
        .length;

    final selectedDaySlots = state.availability.availability[selectedDay] ?? [];
    final selectedDayError = _getDayValidationError(selectedDay, selectedDaySlots, state.availability.availability);
    final globalError = state.availability.validate();
    
    // Check if the validation error is on a day other than the currently selected one
    final hasErrorOnOtherDays = globalError != null && selectedDayError == null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppPadding.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weekly Setup', style: kTextBold3()),
                      SizedBox(height: 4.h),
                      Text(
                        'Auto-scheduling $activeCount day${activeCount > 1 ? "s" : ""} this week',
                        style: kTextNormal(color: kTextSecondaryColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _showScheduleInfo(context),
                  child: Container(
                    padding: AppPadding.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.info_outline_rounded, color: kPrimaryColor, size: 22.sp),
                  ),
                ),
              ],
            ),
          ),
          
          Consumer(
            builder: (context, ref, child) {
              final settings = ref.watch(systemSettingsProvider).value?.data ?? [];
              String getSetting(String key, String fallback) {
                final match = settings.where((s) => s.settingKey == key).firstOrNull;
                return match?.settingValue ?? fallback;
              }
              
              final dayStart = getSetting('day_shift_start_time', '08:00:00');
              final nightStart = getSetting('night_shift_start_time', '20:00:00');
              
              final dayEnd = nightStart;
              final nightEnd = dayStart;

              void applyBulk(String label, String start, String end) {
                showDialog(
                  context: context,
                  builder: (dialogCtx) => ConfirmationDialog(
                    title: 'Overwrite Schedule?',
                    message: 'Are you sure you want to set the "$label" shift for all 7 days? This will overwrite your existing schedule slots.',
                    confirmText: 'Yes, Overwrite',
                    cancelText: 'Cancel',
                    isDangerous: true,
                    onConfirm: () {
                      Navigator.pop(dialogCtx);
                      context.read<AvailabilityBloc>().add(SetBulkAvailability(
                        startTime: start,
                        endTime: end,
                      ));
                    },
                  ),
                );
              }

              return Padding(
                padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 16.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ShortcutButton(
                      label: 'Day',
                      icon: Icons.wb_sunny_rounded,
                      onTap: () => applyBulk('Day', dayStart, dayEnd),
                    ),
                    SizedBox(width: 8.w),
                    _ShortcutButton(
                      label: 'Night',
                      icon: Icons.nightlight_round,
                      onTap: () => applyBulk('Night', nightStart, nightEnd),
                    ),
                    SizedBox(width: 8.w),
                    _ShortcutButton(
                      label: '24 Hours',
                      icon: Icons.access_time_filled_rounded,
                      onTap: () => applyBulk('24 Hours', '00:00:00', '23:59:00'),
                    ),
                  ],
                ),
              );
            },
          ),
          
          _WeekdaySelector(
            selectedDay: selectedDay,
            availability: state.availability.availability,
            onDaySelected: (day) => setState(() => selectedDay = day),
          ),
          
          _DayScheduleCard(
            dayName: selectedDay,
            slots: selectedDaySlots,
            availability: state.availability.availability,
            validationError: selectedDayError,
          ),
          
          if (hasErrorOnOtherDays)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: kErrorColor.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: kErrorColor.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: kErrorColor, size: 20.sp),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'You have scheduling conflicts on other days. Please select highlighted days to fix them.',
                        style: kTextMedium(color: kErrorColor).copyWith(fontSize: 13.sp),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  String? _getDayValidationError(String day, List<DayAvailability> slots, Map<String, List<DayAvailability>> availability) {
    final List<DayAvailability> allActiveSlots = [];
    availability.forEach((key, sList) {
      allActiveSlots.addAll(sList.where((s) => s.isActive));
    });
    
    final activeDaySlots = slots.where((s) => s.isActive).toList();
    for (final slotA in activeDaySlots) {
      for (final slotB in allActiveSlots) {
        if (slotA == slotB) continue;
        if (WeeklyAvailability.checkWeeklyOverlap(slotA, slotB)) {
          if (slotA.dayOfWeek == slotB.dayOfWeek) {
            return "Overlapping time slots are not allowed.";
          } else {
            return "Overlaps with slot on ${slotB.dayOfWeek}.";
          }
        }
      }
    }
    return null;
  }

  void _showScheduleInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 0.h),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                SizedBox(height: 24.h),
                Text('Auto Scheduling Guide', style: kTextBold3().copyWith(fontSize: 22.sp)),
                SizedBox(height: 12.h),
                Text(
                  'This system automatically toggles your online/offline status based on the schedule you set below.',
                  style: kTextNormal(color: kTextSecondaryColor),
                ),
                SizedBox(height: 24.h),
                _buildGuideItem(
                  Icons.bolt_rounded,
                  kPrimaryColor,
                  'Auto Online/Offline',
                  'The app will automatically mark you as "Available" during your set hours and "Offline" otherwise.',
                ),
                SizedBox(height: 16.h),
                _buildGuideItem(
                  Icons.access_time_filled_rounded,
                  const Color(0xFF10B981),
                  'Working Windows',
                  'Define your start and end times for each day. You will only be visible to customers during these hours.',
                ),
                SizedBox(height: 16.h),
                _buildGuideItem(
                  Icons.sync_rounded,
                  const Color(0xFFF59E0B),
                  'Updates & Changes',
                  'Changes are saved locally. Remember to tap "Apply Changes" at the bottom to publish your schedule.',
                ),
                SizedBox(height: 32.h),
                CustomButton(
                  onPressed: () => Navigator.pop(context),
                  title: 'Got it!',
                  height: 56.h,
                  width: double.infinity,
                  borderRadius: BorderRadius.circular(16.r),
                  textStyle: kTextBold2(color: Colors.white),
                ),
                AppSpacing.lVertical,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideItem(IconData icon, Color color, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: AppPadding.all(12),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 24.sp),
        ),
        SizedBox(width: 20.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: kTextBold1().copyWith(fontSize: 16.sp)),
              SizedBox(height: 6.h),
              Text(desc, style: kTextNormal(color: kTextSecondaryColor).copyWith(height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekdaySelector extends StatelessWidget {
  final String selectedDay;
  final Map<String, List<DayAvailability>> availability;
  final ValueChanged<String> onDaySelected;

  const _WeekdaySelector({
    required this.selectedDay,
    required this.availability,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (index) {
          final day = days[index];
          final label = labels[index];
          final isSelected = day == selectedDay;
          
          final slots = availability[day] ?? [];
          final bool isWorking = slots.any((s) => s.isActive);
          
          // Check if this day has a validation conflict
          final bool hasConflict = _hasDayConflict(day, availability);

          return GestureDetector(
            onTap: () => onDaySelected(day),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [kSecondaryColor, kPrimaryColor],
                          )
                        : null,
                    color: isSelected ? null : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : (hasConflict
                              ? kErrorColor.withValues(alpha: 0.5)
                              : (isWorking ? kPrimaryColor.withValues(alpha: 0.3) : Colors.grey.shade200)),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: kTextBold(
                        color: isSelected
                            ? Colors.white
                            : (hasConflict
                                ? kErrorColor
                                : (isWorking ? kPrimaryColor : kTextSecondaryColor)),
                      ).copyWith(fontSize: 14.sp),
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasConflict
                        ? kErrorColor
                        : (isWorking ? kSuccessColor : Colors.transparent),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  bool _hasDayConflict(String day, Map<String, List<DayAvailability>> availability) {
    final List<DayAvailability> allActiveSlots = [];
    availability.forEach((key, sList) {
      allActiveSlots.addAll(sList.where((s) => s.isActive));
    });
    
    final daySlots = availability[day]?.where((s) => s.isActive) ?? [];
    for (final slotA in daySlots) {
      for (final slotB in allActiveSlots) {
        if (slotA == slotB) continue;
        if (WeeklyAvailability.checkWeeklyOverlap(slotA, slotB)) {
          return true;
        }
      }
    }
    return false;
  }
}

class _DayScheduleCard extends StatelessWidget {
  final String dayName;
  final List<DayAvailability> slots;
  final Map<String, List<DayAvailability>> availability;
  final String? validationError;

  const _DayScheduleCard({
    required this.dayName,
    required this.slots,
    required this.availability,
    this.validationError,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = slots.any((s) => s.isActive);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      padding: AppPadding.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: validationError != null
              ? kErrorColor.withValues(alpha: 0.25)
              : (isActive ? kPrimaryColor.withValues(alpha: 0.1) : Colors.grey.shade100),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayName,
                    style: kTextBold3(color: kTextPrimaryColor).copyWith(fontSize: 22.sp),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    isActive ? 'Working status: Active' : 'Working status: Offline',
                    style: kTextMedium0(color: isActive ? kPrimaryColor : kTextSecondaryColor),
                  ),
                ],
              ),
              Switch.adaptive(
                value: isActive,
                activeThumbColor: kPrimaryColor,
                activeTrackColor: kPrimaryColor.withValues(alpha: 0.5),
                inactiveThumbColor: const Color(0xFF9CA3AF),
                onChanged: (val) {
                  context.read<AvailabilityBloc>().add(ToggleDayStatus(dayName, val));
                },
              ),
            ],
          ),
          
          SizedBox(height: 24.h),
          
          if (slots.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
              decoration: BoxDecoration(
                color: kScaffoldColor,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 32.sp,
                    color: kTextSecondaryColor.withValues(alpha: 0.5),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'No working hours scheduled.',
                    style: kTextMedium0(color: kTextSecondaryColor),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: slots.length,
              separatorBuilder: (context, index) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final slot = slots[index];
                final slotError = _getSlotError(context, slot, index, availability);
                return _TimeSlotRow(
                  slot: slot,
                  index: index,
                  dayName: dayName,
                  slotError: slotError,
                  onStartTap: () => _selectTime(context, true, index, slot),
                  onEndTap: () => _selectTime(context, false, index, slot),
                  onDelete: () {
                    context.read<AvailabilityBloc>().add(DeleteSlot(dayName, index));
                  },
                );
              },
            ),
          ],
          SizedBox(height: 16.h),
          Center(
            child: TextButton.icon(
              onPressed: () {
                context.read<AvailabilityBloc>().add(AddSlot(dayName));
              },
              icon: Icon(Icons.add_rounded, color: kPrimaryColor, size: 20.sp),
              label: Text(
                'Add Time Slot',
                style: kTextSemiBold(color: kPrimaryColor).copyWith(fontSize: 14.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _getSlotError(BuildContext context, DayAvailability slot, int index, Map<String, List<DayAvailability>> availability) {
    if (!slot.isActive) return null;
    
    final List<DayAvailability> allActiveSlots = [];
    availability.forEach((key, sList) {
      allActiveSlots.addAll(sList.where((s) => s.isActive));
    });
    
    for (final other in allActiveSlots) {
      if (other == slot) continue;
      
      if (WeeklyAvailability.checkWeeklyOverlap(slot, other)) {
        if (slot.dayOfWeek == other.dayOfWeek) {
          return "Time slot overlaps with another slot.";
        } else {
          final formattedOtherStart = _formatTime(context, other.startTime);
          final formattedOtherEnd = _formatTime(context, other.endTime);
          return "Overlaps with ${other.dayOfWeek}'s schedule ($formattedOtherStart - $formattedOtherEnd).";
        }
      }
    }
    
    return null;
  }

  Future<void> _selectTime(BuildContext context, bool isStart, int originalIndex, DayAvailability daySlot) async {
    final String currentStr = isStart ? daySlot.startTime : daySlot.endTime;
    final List<String> parts = currentStr.split(':');
    TimeOfDay initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    if (initialTime.hour == 23 && initialTime.minute == 59) {
      initialTime = const TimeOfDay(hour: 0, minute: 0);
    }

    final TimeOfDay? picked = await _MinimalCapsuleTimePicker.show(
      context,
      initialTime: initialTime,
      title: isStart ? "SET START TIME" : "SET END TIME",
      minTime: isStart ? null : _parseTime(daySlot.startTime),
      maxTime: isStart ? _parseTime(daySlot.endTime) : null,
    );

    if (picked != null && context.mounted) {
      String formattedTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';

      if (!isStart && picked.hour == 0 && picked.minute == 0) {
        formattedTime = '23:59:00';
      }

      final String startTime = isStart ? formattedTime : daySlot.startTime;
      final String endTime = isStart ? daySlot.endTime : formattedTime;

      context.read<AvailabilityBloc>().add(ChangeTime(
        dayName: dayName,
        slotIndex: originalIndex,
        startTime: startTime,
        endTime: endTime,
      ));
    }
  }

  TimeOfDay _parseTime(String timeStr) {
    if (timeStr == '23:59:00') return const TimeOfDay(hour: 0, minute: 0);
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
}

class _TimeSlotRow extends StatelessWidget {
  final DayAvailability slot;
  final int index;
  final String dayName;
  final String? slotError;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;
  final VoidCallback onDelete;

  const _TimeSlotRow({
    required this.slot,
    required this.index,
    required this.dayName,
    this.slotError,
    required this.onStartTap,
    required this.onEndTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSlotActive = slot.isActive;
    final startMin = WeeklyAvailability.timeToMinutes(slot.startTime);
    final endMin = WeeklyAvailability.timeToMinutes(slot.endTime);
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayIndex = days.indexOf(dayName);
    final nextDayName = dayIndex != -1 ? days[(dayIndex + 1) % 7] : '';

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: slotError != null
              ? kErrorColor.withValues(alpha: 0.4)
              : (isSlotActive ? kPrimaryColor.withValues(alpha: 0.15) : Colors.grey.shade200),
          width: slotError != null ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '#${index + 1}',
                    style: kTextBold(color: isSlotActive ? kPrimaryColor : kTextSecondaryColor)
                        .copyWith(fontSize: 14.sp),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: isSlotActive 
                          ? kSuccessColor.withValues(alpha: 0.1) 
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      isSlotActive ? 'Active' : 'Inactive',
                      style: kTextBold(
                        color: isSlotActive ? kSuccessColor : kTextSecondaryColor,
                      ).copyWith(fontSize: 10.sp),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Switch.adaptive(
                    value: isSlotActive,
                    activeThumbColor: kPrimaryColor,
                    activeTrackColor: kPrimaryColor.withValues(alpha: 0.5),
                    inactiveThumbColor: const Color(0xFF9CA3AF),
                    onChanged: (val) {
                      context.read<AvailabilityBloc>().add(ToggleSlotStatus(
                        dayName: dayName,
                        slotIndex: index,
                        isActive: val,
                      ));
                    },
                  ),
                  SizedBox(width: 8.w),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded, color: kErrorColor.withValues(alpha: 0.8), size: 20.sp),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Opacity(
            opacity: isSlotActive ? 1.0 : 0.5,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: isSlotActive ? onStartTap : null,
                    borderRadius: BorderRadius.circular(12.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 10.w),
                      decoration: BoxDecoration(
                        color: kScaffoldColor,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _formatTime(context, slot.startTime),
                              style: kTextSemiBold(color: isSlotActive ? kPrimaryColor : kTextSecondaryColor)
                                  .copyWith(fontSize: 13.sp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(Icons.access_time_rounded, size: 15.sp, color: isSlotActive ? kPrimaryColor : kTextSecondaryColor),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 14.sp,
                    color: kTextSecondaryColor.withValues(alpha: 0.5),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: isSlotActive ? onEndTap : null,
                    borderRadius: BorderRadius.circular(12.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 10.w),
                      decoration: BoxDecoration(
                        color: kScaffoldColor,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _formatTime(context, slot.endTime),
                              style: kTextSemiBold(color: isSlotActive ? kPrimaryColor : kTextSecondaryColor)
                                  .copyWith(fontSize: 13.sp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(Icons.access_time_rounded, size: 15.sp, color: isSlotActive ? kPrimaryColor : kTextSecondaryColor),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isSlotActive && startMin >= endMin) ...[
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 13.sp,
                  color: kPrimaryColor,
                ),
                SizedBox(width: 4.w),
                Text(
                  "Next day $nextDayName at ${_formatTime(context, slot.endTime)}",
                  style: kTextMedium(color: kPrimaryColor).copyWith(fontSize: 11.sp),
                ),
              ],
            ),
          ],
          if (slotError != null) ...[
            SizedBox(height: 10.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: kErrorColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: kErrorColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: kErrorColor, size: 14.sp),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      slotError!,
                      style: kTextMedium(color: kErrorColor).copyWith(fontSize: 11.sp),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

}

String _formatTime(BuildContext context, String timeStr) {
  final List<String> parts = timeStr.split(':');
  final TimeOfDay tod = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  return tod.format(context);
}

class _ShortcutButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ShortcutButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: kPrimaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: kPrimaryColor.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14.sp, color: kPrimaryColor),
            SizedBox(width: 4.w),
            Text(
              label,
              style: kTextSemiBold(color: kPrimaryColor).copyWith(fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinimalCapsuleTimePicker {
  static Future<TimeOfDay?> show(
    BuildContext context, {
    required TimeOfDay initialTime,
    required String title,
    TimeOfDay? minTime,
    TimeOfDay? maxTime,
  }) {
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        DateTime tempDateTime = DateTime(2026, 1, 1, initialTime.hour, initialTime.minute);
        
        return SafeArea(
          top: false,
          child: SizedBox(
            height: 320.h,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: kTextMedium(color: kTextSecondaryColor),
                        ),
                      ),
                      Text(
                        title,
                        style: kTextBold(color: kTextPrimaryColor).copyWith(fontSize: 16.sp),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(
                            context,
                            TimeOfDay(hour: tempDateTime.hour, minute: tempDateTime.minute),
                          );
                        },
                        child: Text(
                          'Confirm',
                          style: kTextBold(color: kPrimaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: kDividerColor),
                Expanded(
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      brightness: Brightness.light,
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: tempDateTime,
                      onDateTimeChanged: (DateTime newDateTime) {
                        tempDateTime = newDateTime;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
