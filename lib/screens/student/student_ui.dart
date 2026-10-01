import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../core/widgets/status_chip.dart' as shared;

String formatDate(DateTime date) => fmtDate(date);

Widget statusChip(String status) => shared.StatusChip(status: status);

void toast(BuildContext context, String message, {bool error = false}) {
  showSnack(context, message, error: error);
}
