import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// 24 Sep 2026
String fmtDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);

/// 2026-09-24 (what Postgres `date` columns expect)
String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
