import 'dart:io';

import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future main() async {
  sqfliteFfiInit();

  var databaseFactory = databaseFactoryFfi;
  var db = await databaseFactory.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1));
  print('inMemory version: ${await db.getVersion()}');
  await db.close();

  db = await databaseFactory.openDatabase('simple_version_1.db',
      options: OpenDatabaseOptions(version: 1));
  print('io file version: ${await db.getVersion()}');
  await db.close();
  exit(0);
}
