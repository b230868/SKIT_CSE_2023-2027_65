import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/approval_repository.dart';
import '../repositories/mock_approval_repository.dart';
import '../repositories/supabase_approval_repository.dart';

class ApprovalRepositoryProvider {
  ApprovalRepositoryProvider._();

  static ApprovalRepository? _override;

  static void setRepository(ApprovalRepository repository) {
    _override = repository;
  }

  static void reset() {
    _override = null;
  }

  static ApprovalRepository get instance {
    if (_override != null) return _override!;
    try {
      Supabase.instance.client;
      return SupabaseApprovalRepository();
    } catch (_) {
      return MockApprovalRepository();
    }
  }
}