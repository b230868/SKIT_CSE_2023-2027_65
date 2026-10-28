import 'dart:async';
import 'dart:io' show SocketException;

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

bool isNetworkError(Object error) =>
    error is ClientException ||
    error is TimeoutException ||
    error is SocketException ||
    error is AuthRetryableFetchException;
