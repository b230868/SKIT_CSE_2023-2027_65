import 'package:flutter/material.dart';

import '../../../approval/domain/entities/approval_review_stage.dart';
import '../../../approval/presentation/screens/approval_list_screen.dart';
import 'tp_noc_management_screen.dart';

/// Unified T&P NOC & Internship Approvals hub preserving the existing
/// T&P final internship approval workflow alongside dedicated NOC management.
class TpNocAndApprovalsScreen extends StatelessWidget {
  final int initialTabIndex;

  const TpNocAndApprovalsScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('NOC & T&P Approvals'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.assignment_turned_in_outlined),
                text: 'NOC Requests',
              ),
              Tab(
                icon: Icon(Icons.fact_check_outlined),
                text: 'Internship Approvals',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TpNocManagementScreen(),
            ApprovalListScreen(
              title: 'T&P Final Approvals',
              stage: ApprovalReviewStage.tpAdmin,
            ),
          ],
        ),
      ),
    );
  }
}
