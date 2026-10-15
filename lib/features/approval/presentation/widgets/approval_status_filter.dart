import 'package:flutter/material.dart';

import '../../domain/entities/approval_status.dart';

class ApprovalStatusFilter extends StatelessWidget {
  final ApprovalStatus? selectedStatus;
  final ValueChanged<ApprovalStatus?> onChanged;

  const ApprovalStatusFilter({
    super.key,
    required this.selectedStatus,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<ApprovalStatus?>(
      initialValue: selectedStatus,
      decoration: const InputDecoration(
        labelText: 'Filter by status',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<ApprovalStatus?>(
          value: null,
          child: Text('All statuses'),
        ),
        ...ApprovalStatus.values.map(
          (status) => DropdownMenuItem<ApprovalStatus?>(
            value: status,
            child: Text(status.displayName),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}