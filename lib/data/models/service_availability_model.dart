import 'dropdown_response_model.dart';

class ServiceAvailabilityResponse {
  final bool status;
  final String message;
  final ServiceAvailabilityData? data;
  final ServerTime? serverTime;

  ServiceAvailabilityResponse({
    required this.status,
    required this.message,
    this.data,
    this.serverTime,
  });

  factory ServiceAvailabilityResponse.fromJson(Map<String, dynamic> json) {
    String parsedMessage = "";
    final rawMessage = json['message'];
    if (rawMessage is String) {
      parsedMessage = rawMessage;
    } else if (rawMessage is Map) {
      final messages = <String>[];
      rawMessage.forEach((key, value) {
        if (value is List) {
          messages.add(value.join(", "));
        } else {
          messages.add(value.toString());
        }
      });
      parsedMessage = messages.join("\n");
    } else if (rawMessage != null) {
      parsedMessage = rawMessage.toString();
    }

    return ServiceAvailabilityResponse(
      status: json['status'] ?? false,
      message: parsedMessage,
      data: json['data'] != null ? ServiceAvailabilityData.fromJson(json['data']) : null,
      serverTime: json['server_time'] != null ? ServerTime.fromJson(json['server_time']) : null,
    );
  }
}

class ServerTime {
  final String timezone;
  final String currentDateTime;

  ServerTime({required this.timezone, required this.currentDateTime});

  factory ServerTime.fromJson(Map<String, dynamic> json) {
    return ServerTime(
      timezone: json['timezone'] ?? "",
      currentDateTime: json['current_date_time'] ?? "",
    );
  }
}

class ServiceAvailabilityData {
  final CityAdmin? cityAdmin;
  final List<ServiceCategory> serviceCategories;

  ServiceAvailabilityData({
    this.cityAdmin,
    required this.serviceCategories,
  });

  factory ServiceAvailabilityData.fromJson(Map<String, dynamic> json) {
    return ServiceAvailabilityData(
      cityAdmin: json['city_admin'] != null ? CityAdmin.fromJson(json['city_admin']) : null,
      serviceCategories: (json['service_categories'] as List? ?? [])
          .map((i) => ServiceCategory.fromJson(i))
          .toList(),
    );
  }
}

class CityAdmin {
  final int id;
  final int cityId;
  final int ownerUserId;
  final String name;
  final String slug;
  final String code;
  final int lastInvoiceSerial;
  final int lastInvoiceSerialS;
  final int lastInvoiceSerialP;
  final int lastRequestSerial;
  final int lastBookingSerial;
  final String vendorType;
  final String commissionPercentage;
  final bool isDefault;
  final bool isActive;
  final int advanceBookingEnabled;
  final int advanceBookingPercentage;
  final int isEmergencyServiceEnabled;
  final String procCancelMinGt2hr;
  final dynamic procCancelMin30mTo2hr;
  final dynamic procCancelMinLt30m;
  final dynamic longCancelMinGt12hr;
  final dynamic longCancelMin2hrTo12hr;
  final dynamic longCancelMinLt2hr;
  final String? emergencyContactNumber1;
  final String? emergencyContactNumber2;
  final String createdAt;
  final String updatedAt;

  CityAdmin({
    required this.id,
    required this.cityId,
    required this.ownerUserId,
    required this.name,
    required this.slug,
    required this.code,
    required this.lastInvoiceSerial,
    required this.lastInvoiceSerialS,
    required this.lastInvoiceSerialP,
    required this.lastRequestSerial,
    required this.lastBookingSerial,
    required this.vendorType,
    required this.commissionPercentage,
    required this.isDefault,
    required this.isActive,
    required this.advanceBookingEnabled,
    required this.advanceBookingPercentage,
    required this.isEmergencyServiceEnabled,
    required this.procCancelMinGt2hr,
    required this.procCancelMin30mTo2hr,
    required this.procCancelMinLt30m,
    required this.longCancelMinGt12hr,
    required this.longCancelMin2hrTo12hr,
    required this.longCancelMinLt2hr,
    this.emergencyContactNumber1,
    this.emergencyContactNumber2,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CityAdmin.fromJson(Map<String, dynamic> json) {
    return CityAdmin(
      id: json['id'],
      cityId: json['city_id'],
      ownerUserId: json['owner_user_id'],
      name: json['name'] ?? "",
      slug: json['slug'] ?? "",
      code: json['code'] ?? "",
      lastInvoiceSerial: json['last_invoice_serial'] ?? 0,
      lastInvoiceSerialS: json['last_invoice_serial_s'] ?? 0,
      lastInvoiceSerialP: json['last_invoice_serial_p'] ?? 0,
      lastRequestSerial: json['last_request_serial'] ?? 0,
      lastBookingSerial: json['last_booking_serial'] ?? 0,
      vendorType: json['vendor_type'] ?? "",
      commissionPercentage: json['commission_percentage']?.toString() ?? "0.00",
      isDefault: json['is_default'] == true || json['is_default'] == 1,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      advanceBookingEnabled: json['advance_booking_enabled'] ?? 0,
      advanceBookingPercentage: json['advance_booking_percentage'] ?? 0,
      isEmergencyServiceEnabled: json['is_emergency_service_enabled'] ?? 0,
      procCancelMinGt2hr: json['proc_cancel_min_gt_2hr']?.toString() ?? "0.00",
      procCancelMin30mTo2hr: json['proc_cancel_min_30m_to_2hr'],
      procCancelMinLt30m: json['proc_cancel_min_lt_30m'],
      longCancelMinGt12hr: json['long_cancel_min_gt_12hr'],
      longCancelMin2hrTo12hr: json['long_cancel_min_2hr_to_12hr'],
      longCancelMinLt2hr: json['long_cancel_min_lt_2hr'],
      emergencyContactNumber1: json['emergency_contact_number_1']?.toString(),
      emergencyContactNumber2: json['emergency_contact_number_2']?.toString(),
      createdAt: json['created_at'] ?? "",
      updatedAt: json['updated_at'] ?? "",
    );
  }
}
