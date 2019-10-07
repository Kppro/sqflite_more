import 'dart:async';
import 'dart:convert';

import 'package:test_api/test_api.dart';
import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite_test/sqflite_test.dart';

final String tableTodo = "todo";
final String columnId = "_id";
final String columnTitle = "title";
final String columnDone = "done";

Future main() {
  return testMain(run);
}

void run(SqfliteServerTestContext context) {
  var factory = context.databaseFactory;

  group('doc', () {
    test("upgrade_add_table", () async {
      //await Sqflite.setDebugModeOn(true);

      // Our database path
      String path;
      // Our database once opened
      Database db;

      try {
        /// Let's use FOREIGN KEY CONSTRAIN
        Future onConfigure(Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        }

        Future openCloseV1() async
        // Open 1st version
        {
          /// Create tables
          void _createTableCompanyV1(Batch batch) {
            batch.execute('DROP TABLE IF EXISTS Company');
            batch.execute('''CREATE TABLE Company (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT
)''');
          }

// First version of the database
          db = await factory.openDatabase(path,
              options: OpenDatabaseOptions(
                  version: 1,
                  onCreate: (db, version) async {
                    var batch = db.batch();
                    _createTableCompanyV1(batch);
                    await batch.commit();
                  },
                  onConfigure: onConfigure,
                  onDowngrade: onDatabaseDowngradeDelete));

          await db.close();
          db = null;
        }

        // Open 2nd version
        Future openCloseV2() async {
          /// Let's use FOREIGN KEY constraints
          Future onConfigure(Database db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          }

          /// Create Company table V2
          void _createTableCompanyV2(Batch batch) {
            batch.execute('DROP TABLE IF EXISTS Company');
            batch.execute('''CREATE TABLE Company (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  description TEXT
)''');
          }

          /// Update Company table V1 to V2
          void _updateTableCompanyV1toV2(Batch batch) {
            batch.execute('ALTER TABLE Company ADD description TEXT');
          }

          /// Create Employee table V2
          void _createTableEmployeeV2(Batch batch) {
            batch.execute('DROP TABLE IF EXISTS Employee');
            batch.execute('''CREATE TABLE Employee (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  companyId INTEGER,
  FOREIGN KEY (companyId) REFERENCES Company(id) ON DELETE CASCADE
  
)''');
          }

// 2nd version of the database
          db = await factory.openDatabase(path,
              options: OpenDatabaseOptions(
                  version: 2,
                  onConfigure: onConfigure,
                  onCreate: (db, version) async {
                    var batch = db.batch();
                    // We create all the tables
                    _createTableCompanyV2(batch);
                    _createTableEmployeeV2(batch);
                    await batch.commit();
                  },
                  onUpgrade: (db, oldVersion, newVersion) async {
                    var batch = db.batch();
                    if (oldVersion == 1) {
                      // We update existing table and create the new tables
                      _updateTableCompanyV1toV2(batch);
                      _createTableEmployeeV2(batch);
                    }
                    await batch.commit();
                  },
                  onDowngrade: onDatabaseDowngradeDelete));

          await db.close();
          db = null;
        }

        Future _readTest() async {
          db ??= await factory.openDatabase(path);
          expect(await db.query('Company'), [
            {'name': 'Watch', 'description': 'Black Wristatch', 'id': 1}
          ]);
          expect(await db.query('Employee'), [
            {'name': '1st Employee', 'companyId': 1, 'id': 1}
          ]);
        }

        Future _test() async {
          db = await factory.openDatabase(path);
          try {
            var companyId = await db.insert('Company', <String, dynamic>{
              'name': 'Watch',
              'description': 'Black Wristatch'
            });
            await db.insert('Employee', <String, dynamic>{
              'name': '1st Employee',
              'companyId': companyId
            });
            await _readTest();
          } finally {
            await db?.close();
            db = null;
          }
        }

        {
          // Test1
          path =
              await context.initDeleteDb("upgrade_add_table_and_column_doc.db");
          await openCloseV1();
          await openCloseV2();
          await _test();
        }
        {
          // Test2
          path =
              await context.initDeleteDb("upgrade_add_table_and_column_doc.db");
          await openCloseV2();
          await _test();
        }

        {
          // Test3
          await _readTest();
          await openCloseV2();
          await _readTest();
        }
        {
          // Test4 - don't delete before
          await openCloseV1();
          await openCloseV2();
          await _readTest();
        }
      } finally {
        await db?.close();
      }
    });

    test('record map', () async {
      Map<String, dynamic> map = <String, dynamic>{
        "title": "Table",
        "size": <String, dynamic>{"width": 80, "height": 80}
      };

      map = <String, dynamic>{"title": "Table", "width": 80, "height": 80};

      map = <String, dynamic>{
        "title": "Table",
        "size": jsonEncode(<String, dynamic>{"width": 80, "height": 80})
      };
      final Map<String, dynamic> map2 = <String, dynamic>{
        'title': 'Table',
        'size': '{"width":80,"height":80}'
      };
      expect(map, map2);
    });

    test('data_types', () async {
      var path = inMemoryDatabasePath;

      {
        /// Create tables
        void _createTableCompanyV1(Batch batch) {
          batch.execute('''
CREATE TABLE Product (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT,
  width INTEGER,
  height INTEGER
)''');
        }

// First version of the database
        var db = await factory.openDatabase(path,
            options: OpenDatabaseOptions(
                version: 1,
                onCreate: (db, version) async {
                  var batch = db.batch();
                  _createTableCompanyV1(batch);
                  await batch.commit();
                },
                onDowngrade: onDatabaseDowngradeDelete));

        var map = <String, dynamic>{
          "title": "Table",
          "width": 80,
          "height": 80
        };
        await db.insert('Product', map);
        await db.close();
        db = null;
      }

      {
        /// Create tables
        void _createProductTable(Batch batch) {
          batch.execute('''
CREATE TABLE Product (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT,
  size TEXT
)''');
        }

// First version of the database
        var db = await factory.openDatabase(path,
            options: OpenDatabaseOptions(
                version: 1,
                onCreate: (db, version) async {
                  var batch = db.batch();
                  _createProductTable(batch);
                  await batch.commit();
                },
                onDowngrade: onDatabaseDowngradeDelete));

        var map = <String, dynamic>{
          'title': 'Table',
          'size': '{"width":80,"height":80}'
        };
        await db.insert('Product', map);
        await db.close();
        db = null;
      }
    });
  });
}
