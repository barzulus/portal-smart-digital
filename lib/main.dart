import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/storage/offline_cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize offline cache database
  await OfflineCacheService.init();

  // Initialize locale data untuk DateFormat (Indonesia + default).
  // Tanpa ini, `DateFormat('d MMMM yyyy', 'id').format(...)` akan throw
  // LocaleDataException saat user buka date picker / format tanggal.
  await initializeDateFormatting('id_ID', null);
  await initializeDateFormatting('id', null);

  // TODO: Initialize Firebase when ready
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  runApp(
    const ProviderScope(
      child: SekolahApp(),
    ),
  );
}
