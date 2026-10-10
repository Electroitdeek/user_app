import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/api/api_endpoints.dart';
import 'package:adhisaat_health_care/core/constants/app_constants.dart';
import 'package:adhisaat_health_care/core/storage/local_storage_service.dart';

import '../model/procedure_model.dart';
import '../model/service_category_model.dart';

class ServiceCategoryRepository {
  final ApiClient _apiClient;
  final LocalStorageService _storageService;

  ServiceCategoryRepository(this._apiClient, this._storageService);

  /// Searches the same services the admin turns on in the catalog.
  Future<List<ProcedureModel>> getProcedures({required String search}) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.catalogServices);
      final rows = _rowsOf(response, 'services');
      final needle = search.trim().toLowerCase();
      final matches = <ProcedureModel>[];
      for (final row in rows) {
        final title = row['title']?.toString() ?? '';
        final description = row['description']?.toString() ?? '';
        if (needle.isNotEmpty &&
            !title.toLowerCase().contains(needle) &&
            !description.toLowerCase().contains(needle)) {
          continue;
        }
        matches.add(_procedureFromCatalog(row));
      }
      return matches;
    } catch (e) {
      kPrintError('ServiceCategoryRepository.getProcedures: $e');
      rethrow;
    }
  }

  /// Categories created in the admin service manager.
  Future<List<ServiceCategoryModel>> getServiceCategories({bool? isEmergency, int? cityAdminId}) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.catalogServices);
      final mapped = _rowsOf(response, 'services').where((row) {
        if (isEmergency == null) return true;
        final emergency = row['bookingRequestType']?.toString() == 'EMERGENCY';
        return isEmergency == emergency;
      }).map(_serviceAsCategory).toList();
      await _storageService.saveServiceCategories(mapped.map((item) => item.toJson()).toList());
      return mapped;
    } catch (e) {
      kPrintError('ServiceCategoryRepository.getServiceCategories: $e');
      rethrow;
    }
  }

  Future<List<ServiceCategoryModel>?> getCachedCategories() async {
    try {
      final cachedData = await _storageService.getServiceCategories();
      if (cachedData != null) {
        final sorted = List<ServiceCategoryModel>.from(cachedData.map((e) => ServiceCategoryModel.fromJson(e)))
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        return sorted;
      }
    } catch (e) {
      kPrintError('ServiceCategoryRepository.getCachedCategories: $e');
    }
    return null;
  }

  /// Services in a category, from the same catalog the admin edits.
  Future<List<SubCategoryDataModel>> getSubCategoriesV2({required int serviceCategoryId}) async {
    try {
      final mongoId = await _mongoIdFor(serviceCategoryId);
      final response = await _apiClient.get(ApiEndpoints.catalogServices);
      final rows = _rowsOf(response, 'services');
      if (mongoId == null) return rows.map(_serviceFromCatalog).toList();
      final direct = rows.where((row) => row['id']?.toString() == mongoId).toList();
      final chosen = direct.isNotEmpty
          ? direct
          : rows.where((row) {
              final category = row['category'];
              return category is Map && category['id']?.toString() == mongoId;
            }).toList();
      return chosen.map(_serviceFromCatalog).toList();
    } catch (e) {
      kPrintError('ServiceCategoryRepository.getSubCategoriesV2: $e');
      rethrow;
    }
  }

  /// Fetches subcategories and their rate cards for a given parent ID.
  Future<List<ServiceCategoryModel>> getSubCategories({
    required int parentId,
    String? city,
    int? addressId,
    bool isEmergency = false,
  }) async {
    try {
      final formData = {
        'service_category_id': parentId.toString(),
        'is_emergency': isEmergency ? '1' : '0',
        if (city != null) 'city': city.toLowerCase(),
        if (addressId != null) 'address_id': addressId.toString(),
      };

      // Since ApiClient doesn't have a direct FormData post explicitly shown, we use a basic POST
      // Using postMultipart to match the --form requirement
      final response = await _apiClient.postMultipart(ApiEndpoints.get_service_categories_with_price, formData);
      final parsed = ServiceCategoriesResponse.fromJson(response as Map<String, dynamic>);
      if (!parsed.status) {
        throw Exception(parsed.message.isNotEmpty ? parsed.message : 'Failed to load subcategories');
      }
      final sorted = List<ServiceCategoryModel>.from(parsed.data)
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      return sorted;
    } catch (e) {
      kPrintError('ServiceCategoryRepository.getSubCategories: $e');
      rethrow;
    }
  }

  /// Re-fetches a single bookable service (with its rate cards) by its own
  /// category id via /get-sub-categories?service_category_id=X&with_ratecard=1.
  /// Used when rescheduling from booking detail, where only the service id is
  /// known. Flattens subcategories + nested services and returns the entry that
  /// actually carries rate cards (preferring an exact id match), or null.
  Future<ServiceItemModel?> getServiceWithRateCards({
    required int serviceCategoryId,
    required int serviceSubCategoryId,
  }) async {
    final list = await getSubCategoriesV2(serviceCategoryId: serviceCategoryId);
    if (list.isEmpty) return null;

    ServiceItemModel? fallback;
    for (final sub in list) {
      // Level-3 services nested under this subcategory.
      for (final svc in sub.services) {
        if (svc.rateCards.isEmpty) continue;
        if (svc.id == serviceSubCategoryId) return svc;
        fallback ??= svc;
      }
      // Subcategory that is itself a directly-bookable service.
      if (sub.rateCards.isNotEmpty) {
        final asItem = ServiceItemModel(
          id: sub.id,
          name: sub.name,
          description: sub.description,
          iconImageUrl: sub.iconImageUrl,
          rateCards: sub.rateCards,
          gstPercentage: sub.gstPercentage,
        );
        if (sub.id == serviceSubCategoryId) return asItem;
        fallback ??= asItem;
      }
    }
    return fallback;
  }

  Future<String?> _mongoIdFor(int id) async {
    final known = catalogMongoByInt[id];
    if (known != null) return known;
    await getServiceCategories();
    return catalogMongoByInt[id];
  }

  ServiceCategoryModel _serviceAsCategory(Map<String, dynamic> row) {
    final mongoId = row['id']?.toString() ?? '';
    final icon = row['hasIcon'] == true ? catalogIconUrl('services', mongoId) : null;
    return ServiceCategoryModel(
      id: rememberCatalogId(mongoId),
      categoryName: row['title']?.toString() ?? '',
      categorySlug: row['slug']?.toString() ?? '',
      description: row['description']?.toString(),
      iconUrl: icon,
      iconImageUrl: icon,
      isActive: row['isOn'] != false,
      displayOrder: 0,
      fullCategoryName: row['title']?.toString() ?? '',
    );
  }

  SubCategoryDataModel _serviceFromCatalog(Map<String, dynamic> row) {
    final mongoId = row['id']?.toString() ?? '';
    final id = rememberCatalogId(mongoId);
    final category = row['category'] is Map ? Map<String, dynamic>.from(row['category'] as Map) : null;
    final categoryId = rememberCatalogId(category?['id']?.toString() ?? mongoId);
    return SubCategoryDataModel(
      id: id,
      name: row['title']?.toString() ?? '',
      description: row['description']?.toString(),
      iconImageUrl: row['hasIcon'] == true ? catalogIconUrl('services', mongoId) : null,
      typeLabel: row['serviceType']?.toString(),
      rateCards: _rateCards(row, id, categoryId),
      gstPercentage: _gst(row),
    );
  }

  ProcedureModel _procedureFromCatalog(Map<String, dynamic> row) {
    final mongoId = row['id']?.toString() ?? '';
    final id = rememberCatalogId(mongoId);
    final category = row['category'] is Map ? Map<String, dynamic>.from(row['category'] as Map) : null;
    final categoryId = rememberCatalogId(category?['id']?.toString() ?? mongoId);
    return ProcedureModel(
      id: id,
      cityAdminId: 0,
      serviceCategoryId: categoryId,
      name: row['title']?.toString() ?? '',
      slug: row['slug']?.toString() ?? '',
      description: row['description']?.toString(),
      type: row['serviceType']?.toString() ?? '',
      genderPreference: row['genderPreference']?.toString() == 'YES',
      displayOrder: 0,
      isActive: row['isOn'] == true,
      isEmergency: row['bookingRequestType']?.toString() == 'EMERGENCY',
      gstPercentage: _gst(row),
      categoryName: category?['title']?.toString(),
      iconImageUrl: row['hasIcon'] == true ? catalogIconUrl('services', mongoId) : null,
      rateCards: _rateCards(row, id, categoryId),
    );
  }

  List<RateCardModel> _rateCards(Map<String, dynamic> row, int serviceId, int categoryId) {
    final places = row['places'] is List ? row['places'] as List : const [];
    final place = places.whereType<Map>().isEmpty ? null : Map<String, dynamic>.from(places.whereType<Map>().first);
    final procedural = place?['procedural'] is Map ? Map<String, dynamic>.from(place!['procedural'] as Map) : const <String, dynamic>{};
    final longDuration = place?['longDuration'] is Map ? Map<String, dynamic>.from(place!['longDuration'] as Map) : const <String, dynamic>{};
    final city = place?['cityName']?.toString() ?? '';
    final cards = <RateCardModel>[];

    if (row['procedural'] != false) {
      cards.add(RateCardModel(
        id: serviceId,
        serviceId: serviceId,
        serviceCategoryId: categoryId,
        city: city,
        bookingType: 'procedural',
        basePrice: _money(procedural['basePrice']),
        pricePerHour: _money(procedural['pricePerHour']),
        pricePerDay: 0,
        pricePerHourNight: 0,
        proceduralDiscountPercentage: _money(procedural['discountPercent']),
        pricePerNight: 0,
        pricePerFullDay: 0,
        pricePerKm: 0,
        unitType: procedural['unitType']?.toString(),
        qtyInMin: int.tryParse(procedural['qtyInMin']?.toString() ?? ''),
      ));
    }

    if (row['longDuration'] != false) {
      final perDay = _money(longDuration['pricePerDay']);
      final perNight = _money(longDuration['pricePerNight']);
      final perFull = _money(longDuration['pricePerFullDay']);
      cards.add(RateCardModel(
        id: serviceId + 1,
        serviceId: serviceId,
        serviceCategoryId: categoryId,
        city: city,
        bookingType: 'long_duration',
        basePrice: perDay,
        pricePerHour: 0,
        pricePerDay: perDay,
        pricePerHourNight: 0,
        proceduralDiscountPercentage: _money(longDuration['discountPercent']),
        pricePerNight: perNight,
        pricePerFullDay: perFull,
        pricePerKm: 0,
        packages: _packages(longDuration['packages'], serviceId, perDay, perNight, perFull),
      ));
    }
    return cards;
  }

  List<RateCardPackageModel> _packages(dynamic raw, int rateCardId, double perDay, double perNight, double perFull) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().toList().asMap().entries.map((entry) {
      final row = Map<String, dynamic>.from(entry.value);
      final shift = row['shift']?.toString() ?? 'DAY';
      final duration = int.tryParse(row['duration']?.toString() ?? '') ?? 0;
      final discount = _money(row['discountPercent']);
      final unit = shift == 'NIGHT' ? perNight : shift == 'FULL' ? perFull : perDay;
      final actual = unit * duration;
      return RateCardPackageModel(
        id: entry.key + 1,
        rateCardId: rateCardId,
        shiftType: shift == 'NIGHT' ? 'night_shift' : shift == 'FULL' ? '24_hours' : 'day_shift',
        durationType: 'days',
        duration: duration,
        actualPrice: actual,
        discountPercentage: discount,
        price: actual * (1 - discount / 100),
        description: row['description']?.toString(),
        sortOrder: entry.key,
      );
    }).toList();
  }
}

final Map<int, String> catalogMongoByInt = {};
final Map<String, int> catalogIntByMongo = {};

/// Resolves an app id back to the Mongo id used by the bookings API.
Future<String?> resolveCatalogMongoId(ApiClient client, int id) async {
  if (id == 0) return null;
  final known = catalogMongoByInt[id];
  if (known != null && known.isNotEmpty) return known;

  final services = await client.get(ApiEndpoints.catalogServices);
  for (final row in _rowsOf(services, 'services')) {
    rememberCatalogId(row['id']?.toString() ?? '');
  }
  final matchedService = catalogMongoByInt[id];
  if (matchedService != null && matchedService.isNotEmpty) return matchedService;

  final bookings = await client.get(ApiEndpoints.bookings);
  final data = bookings is Map ? bookings['data'] : null;
  final rows = data is Map && data['bookings'] is List ? data['bookings'] as List : const [];
  for (final row in rows.whereType<Map>()) {
    rememberCatalogId(Map<String, dynamic>.from(row)['id']?.toString() ?? '');
  }
  final matchedBooking = catalogMongoByInt[id];
  if (matchedBooking == null || matchedBooking.isEmpty) return null;
  return matchedBooking;
}

int rememberCatalogId(String mongoId) {
  if (mongoId.isEmpty) return 0;
  final existing = catalogIntByMongo[mongoId];
  if (existing != null) return existing;
  var id = 0;
  for (final code in mongoId.codeUnits) {
    id = (id * 31 + code) & 0x7fffffff;
  }
  if (id == 0) id = 1;
  while (catalogMongoByInt.containsKey(id) && catalogMongoByInt[id] != mongoId) {
    id = (id + 1) & 0x7fffffff;
    if (id == 0) id = 1;
  }
  catalogMongoByInt[id] = mongoId;
  catalogIntByMongo[mongoId] = id;
  return id;
}

List<Map<String, dynamic>> _rowsOf(dynamic response, String key) {
  final data = response is Map ? response['data'] : null;
  final rows = data is Map && data[key] is List ? data[key] as List : const [];
  return rows.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
}

String catalogIconUrl(String kind, String mongoId) => '${AppConstants.baseUrl}/api/$kind/$mongoId/icon';

double _money(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double _gst(Map<String, dynamic> row) {
  final gst = row['gst'];
  if (gst is Map) return _money(gst['rate']);
  return 0;
}
