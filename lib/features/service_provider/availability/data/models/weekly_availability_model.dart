class WeeklyAvailability {
  final Map<String, List<DayAvailability>> availability;

  WeeklyAvailability({required this.availability});

  factory WeeklyAvailability.fromJson(Map<String, dynamic> json) {
    final Map<String, List<DayAvailability>> availabilityMap = {};
    
    final rawAvailability = json['availability'];
    if (rawAvailability is Map<String, dynamic>) {
      rawAvailability.forEach((key, value) {
        if (value is List) {
          availabilityMap[key] = value.map((i) => DayAvailability.fromJson(i)).toList();
        } else {
          availabilityMap[key] = [];
        }
      });
    } else if (rawAvailability is List) {
      // Legacy List format support
      for (var item in rawAvailability) {
        if (item is Map<String, dynamic>) {
          final dayAvailability = DayAvailability.fromJson(item);
          final day = dayAvailability.dayOfWeek;
          if (day.isNotEmpty) {
            availabilityMap.putIfAbsent(day, () => []).add(dayAvailability);
          }
        }
      }
    }
    
    // Ensure all 7 days are initialized
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    for (var day in days) {
      if (!availabilityMap.containsKey(day) || availabilityMap[day]!.isEmpty) {
        availabilityMap[day] = [
          DayAvailability(
            dayOfWeek: day,
            startTime: '09:00:00',
            endTime: '21:00:00',
            isActive: false,
          )
        ];
      }
    }
    
    return WeeklyAvailability(availability: availabilityMap);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = {};
    availability.forEach((key, value) {
      map[key] = value.map((i) => i.toJson()).toList();
    });
    return {
      'availability': map,
    };
  }

  static Map<String, List<DayAvailability>> defaultWeek() {
    final Map<String, List<DayAvailability>> map = {};
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    for (var day in days) {
      map[day] = [
        DayAvailability(
          dayOfWeek: day,
          startTime: '09:00:00',
          endTime: '21:00:00',
          isActive: false,
        )
      ];
    }
    return map;
  }

  static bool isSameTime(String startStr, String endStr) {
    return startStr == endStr;
  }

  static List<List<int>> getWeeklyIntervals(String dayOfWeek, String startStr, String endStr) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayIndex = days.indexOf(dayOfWeek);
    if (dayIndex == -1) return [];
    
    final dayOffset = dayIndex * 1440;
    final start = timeToMinutes(startStr);
    final end = timeToMinutes(endStr);
    
    if (start == end) {
      return [[dayOffset, dayOffset + 1440]];
    } else if (start < end) {
      return [[dayOffset + start, dayOffset + end]];
    } else {
      // Crosses midnight
      final nextDayOffset = ((dayIndex + 1) % 7) * 1440;
      
      if (dayIndex == 6) {
        return [
          [dayOffset + start, 10080],
          [0, end]
        ];
      } else {
        return [
          [dayOffset + start, dayOffset + 1440],
          [nextDayOffset, nextDayOffset + end]
        ];
      }
    }
  }

  static bool checkWeeklyOverlap(DayAvailability slotA, DayAvailability slotB) {
    final intervalsA = getWeeklyIntervals(slotA.dayOfWeek, slotA.startTime, slotA.endTime);
    final intervalsB = getWeeklyIntervals(slotB.dayOfWeek, slotB.startTime, slotB.endTime);
    
    for (final intA in intervalsA) {
      for (final intB in intervalsB) {
        final startMax = intA[0] > intB[0] ? intA[0] : intB[0];
        final endMin = intA[1] < intB[1] ? intA[1] : intB[1];
        if (startMax < endMin) {
          return true;
        }
      }
    }
    return false;
  }

  static bool checkOverlap(String startAStr, String endAStr, String startBStr, String endBStr) {
    final sA = timeToMinutes(startAStr);
    final eA = timeToMinutes(endAStr);
    final sB = timeToMinutes(startBStr);
    final eB = timeToMinutes(endBStr);
    
    List<List<int>> getIntervals(int s, int e) {
      if (s == e) {
        return [[0, 1440]];
      } else if (s < e) {
        return [[s, e]];
      } else {
        return [[s, 1440], [0, e]];
      }
    }
    
    final listA = getIntervals(sA, eA);
    final listB = getIntervals(sB, eB);
    
    for (final intA in listA) {
      for (final intB in listB) {
        final startMax = intA[0] > intB[0] ? intA[0] : intB[0];
        final endMin = intA[1] < intB[1] ? intA[1] : intB[1];
        if (startMax < endMin) {
          return true; // Overlap found!
        }
      }
    }
    return false;
  }

  String? validate() {
    final List<DayAvailability> allActiveSlots = [];
    for (var entry in availability.entries) {
      final slots = entry.value;
      allActiveSlots.addAll(slots.where((s) => s.isActive));
    }
    
    for (int i = 0; i < allActiveSlots.length; i++) {
      final slotA = allActiveSlots[i];
      for (int j = i + 1; j < allActiveSlots.length; j++) {
        final slotB = allActiveSlots[j];
        if (checkWeeklyOverlap(slotA, slotB)) {
          if (slotA.dayOfWeek == slotB.dayOfWeek) {
            return "In ${slotA.dayOfWeek}: Overlapping time slots are not allowed.";
          } else {
            return "Overlapping schedule between ${slotA.dayOfWeek} and ${slotB.dayOfWeek}.";
          }
        }
      }
    }
    return null;
  }

  static int timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.isEmpty) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return hour * 60 + minute;
  }
}

class DayAvailability {
  final int? id;
  final int? serviceProviderId;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final bool isActive;

  DayAvailability({
    this.id,
    this.serviceProviderId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.isActive,
  });

  factory DayAvailability.fromJson(Map<String, dynamic> json) {
    return DayAvailability(
      id: json['id'],
      serviceProviderId: json['service_provider_id'],
      dayOfWeek: json['day_of_week'] ?? '',
      startTime: json['start_time'] ?? '09:00:00',
      endTime: json['end_time'] ?? '21:00:00',
      isActive: json['is_active'] is bool
          ? json['is_active']
          : (json['is_active'] == 1 || json['is_active'] == '1' || json['is_active'] == 'true'),
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'is_active': isActive,
    };
    if (id != null) {
      data['id'] = id;
    }
    if (serviceProviderId != null) {
      data['service_provider_id'] = serviceProviderId;
    }
    return data;
  }

  DayAvailability copyWith({
    int? id,
    int? serviceProviderId,
    String? dayOfWeek,
    String? startTime,
    String? endTime,
    bool? isActive,
  }) {
    return DayAvailability(
      id: id ?? this.id,
      serviceProviderId: serviceProviderId ?? this.serviceProviderId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
    );
  }
}
