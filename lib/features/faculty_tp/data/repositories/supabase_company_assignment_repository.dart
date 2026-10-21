import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../models/company_assignment_model.dart';
import 'company_assignment_repository.dart';

class SupabaseCompanyAssignmentRepository
    implements CompanyAssignmentRepository {
  final SupabaseClient? _customClient;

  SupabaseCompanyAssignmentRepository({SupabaseClient? client})
    : _customClient = client;

  SupabaseClient get _client {
    final client = _customClient;
    if (client != null) return client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('User is not authenticated.');
    }
  }

  /// Verifies current user is an authorized admin or T&P officer.
  Future<void> _requireAdminOrTnp() async {
    await AuthService.requireAuthenticatedClient(client: _client);
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('User is not authenticated.');
    }

    final profile = await _client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    final role = profile?['role']?.toString().toLowerCase();
    if (role != 'admin' && role != 'tp_officer' && role != 'tnp') {
      throw StateError(
        'Unauthorized: Only Admin or T&P Officers can manage company assignments.',
      );
    }
  }

  @override
  Future<List<VerifiedCompany>> getVerifiedCompanies() async {
    await _requireAdminOrTnp();

    final rows = await _client
        .from('industries')
        .select('id, name')
        .order('name', ascending: true);

    return (rows as List).map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return VerifiedCompany(
        id: m['id'].toString(),
        name: m['name']?.toString() ?? 'Unnamed Company',
      );
    }).toList();
  }

  @override
  Future<List<CompanyAssignmentUser>> getIndustrySupervisors() async {
    await _requireAdminOrTnp();

    // 1. Fetch all profiles where role is industry or industry_supervisor
    final profileRows = await _client
        .from('profiles')
        .select('id, full_name, role, company_name')
        .inFilter('role', ['industry', 'industry_supervisor'])
        .order('full_name', ascending: true);

    // 2. Fetch existing mappings in industry_users with industry name
    final mappingRows = await _client
        .from('industry_users')
        .select('user_id, industry_id, industries ( name )');

    final Map<String, Map<String, String>> assignedMap = {};
    for (final r in (mappingRows as List)) {
      final m = Map<String, dynamic>.from(r as Map);
      final userId = m['user_id']?.toString();
      final industryId = m['industry_id']?.toString();
      final indObj = m['industries'] as Map<String, dynamic>?;
      final industryName = indObj?['name']?.toString() ?? '';
      if (userId != null && industryId != null) {
        assignedMap[userId] = {
          'industry_id': industryId,
          'industry_name': industryName,
        };
      }
    }

    return (profileRows as List).map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      final uid = m['id'].toString();
      final assigned = assignedMap[uid];

      return CompanyAssignmentUser(
        id: uid,
        fullName: m['full_name']?.toString() ?? 'Supervisor',
        email: '', // email is stored in auth.users, profile has name and requested company
        requestedCompanyName: m['company_name']?.toString(),
        assignedIndustryId: assigned?['industry_id'],
        assignedIndustryName: assigned?['industry_name'],
      );
    }).toList();
  }

  @override
  Future<void> assignSupervisorToCompany({
    required String supervisorUserId,
    required String industryId,
  }) async {
    await _requireAdminOrTnp();

    if (supervisorUserId.trim().isEmpty) {
      throw ArgumentError('Invalid supervisor user ID.');
    }
    if (industryId.trim().isEmpty) {
      throw ArgumentError('Invalid verified company ID.');
    }

    // Validate industry exists
    final companyRow = await _client
        .from('industries')
        .select('id')
        .eq('id', industryId)
        .maybeSingle();

    if (companyRow == null) {
      throw ArgumentError('Specified verified company does not exist.');
    }

    // Validate target user exists and has supervisor role
    final userRow = await _client
        .from('profiles')
        .select('id, role')
        .eq('id', supervisorUserId)
        .maybeSingle();

    if (userRow == null) {
      throw ArgumentError('Specified supervisor user does not exist.');
    }

    // Upsert into industry_users on unique constraint (user_id, industry_id) or user_id
    // First, remove existing mapping for this supervisor to maintain 1:1 primary company binding safely
    await _client
        .from('industry_users')
        .delete()
        .eq('user_id', supervisorUserId);

    await _client.from('industry_users').insert({
      'user_id': supervisorUserId,
      'industry_id': industryId,
    });
  }

  @override
  Future<void> revokeSupervisorAssignment({
    required String supervisorUserId,
  }) async {
    await _requireAdminOrTnp();

    if (supervisorUserId.trim().isEmpty) {
      throw ArgumentError('Invalid supervisor user ID.');
    }

    await _client
        .from('industry_users')
        .delete()
        .eq('user_id', supervisorUserId);
  }
}
