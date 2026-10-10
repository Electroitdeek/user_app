import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../model/family_member_model.dart';

class FamilyRepository {
  final ApiClient _apiClient;

  FamilyRepository(this._apiClient);

  Future<List<FamilyMemberModel>> getFamilyMembers() async {
    try {
      final res = await _apiClient.get(ApiEndpoints.getCustomerFamilyMembers);
      if (res['status'] == true && res['data'] is List) {
        return (res['data'] as List)
            .map((e) => FamilyMemberModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      kPrintError('Error in getFamilyMembers(): $e');
      rethrow;
    }
  }

  Future<void> addOrUpdateFamilyMember(FamilyMemberModel member) async {
    try {
      final res = await _apiClient.postMultipart(
        ApiEndpoints.addUpdateCustomerFamilyMember,
        member.toFormMap(),
      );
      if (res['success'] != true) {
        throw Exception(res['message'] ?? 'Failed to save family member');
      }
    } catch (e) {
      kPrintError('Error in addOrUpdateFamilyMember(): $e');
      rethrow;
    }
  }

  Future<void> deleteFamilyMember(int id) async {
    try {
      final res = await _apiClient.post(
        '${ApiEndpoints.deleteCustomerFamilyMember}/$id',
        {},
      );
      if (res['success'] != true) {
        throw Exception(res['message'] ?? 'Failed to delete family member');
      }
    } catch (e) {
      kPrintError('Error in deleteFamilyMember(): $e');
      rethrow;
    }
  }
}
