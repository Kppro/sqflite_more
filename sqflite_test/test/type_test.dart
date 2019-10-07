import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:sqflite/sqlite_api.dart';
import 'package:sqflite/utils/utils.dart' as utils;
import 'package:sqflite_test/sqflite_test.dart';
import 'package:test_api/test_api.dart';

class _Data {
  Database db;
}

final _Data data = _Data();

// Get the value field from a given
Future<dynamic> getValue(int id) async {
  return ((await data.db.query("Test", where: "_id = $id")).first)["value"];
}

// insert the value field and return the id
Future<int> insertValue(dynamic value) async {
  return await data.db.insert("Test", <String, dynamic>{"value": value});
}

// insert the value field and return the id
Future<int> updateValue(int id, dynamic value) async {
  return await data.db
      .update("Test", <String, dynamic>{"value": value}, where: "_id = $id");
}

Future main() {
  return testMain(run);
}

void run(SqfliteServerTestContext context) {
  var factory = context.databaseFactory;
  group('type', () {
    test("int", () async {
      //await Sqflite.devSetDebugModeOn(true);
      String path = await context.initDeleteDb("type_int.db");
      data.db = await factory.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (Database db, int version) async {
                await db.execute(
                    "CREATE TABLE Test (_id INTEGER PRIMARY KEY, value INTEGER)");
              }));

      // text
      int id = await insertValue('test');
      expect(await getValue(id), 'test');

      // null
      id = await insertValue(null);
      expect(await getValue(id), null);

      id = await insertValue(1);
      expect(await getValue(id), 1);

      id = await insertValue(-1);
      expect(await getValue(id), -1);

      // less than 32 bits
      id = await insertValue(pow(2, 31));
      expect(await getValue(id), pow(2, 31));

      // more than 32 bits
      id = await insertValue(pow(2, 33));
      //devPrint("2^33: ${await getValue(id)}");
      expect(await getValue(id), pow(2, 33));

      id = await insertValue(pow(2, 62));
      //devPrint("2^62: ${pow(2, 62)} ${await getValue(id)}");
      expect(await getValue(id), pow(2, 62),
          reason: "2^62: ${pow(2, 62)} ${await getValue(id)}");

      int value = pow(2, 63).round() - 1;
      id = await insertValue(value);
      //devPrint("${value} ${await getValue(id)}");
      expect(await getValue(id), value,
          reason: "${value} ${await getValue(id)}");

      value = -(pow(2, 63)).round();
      id = await insertValue(value);
      //devPrint("${value} ${await getValue(id)}");
      expect(await getValue(id), value,
          reason: "${value} ${await getValue(id)}");
      /*
      id = await insertValue(pow(2, 63));
      devPrint("2^63: ${pow(2, 63)} ${await getValue(id)}");
      assert(await getValue(id) == pow(2, 63), "2^63: ${pow(2, 63)} ${await getValue(id)}");

      // more then 64 bits
      id = await insertValue(pow(2, 65));
      assert(await getValue(id) == pow(2, 65));

      // more then 128 bits
      id = await insertValue(pow(2, 129));
      assert(await getValue(id) == pow(2, 129));
      */
      await data.db.close();
    });

    test("real", () async {
      //await Sqflite.devSetDebugModeOn(true);
      String path = await context.initDeleteDb("type_real.db");
      data.db = await factory.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (Database db, int version) async {
                await db.execute(
                    "CREATE TABLE Test (_id INTEGER PRIMARY KEY, value REAL)");
              }));
      // text
      int id = await insertValue('test');
      expect(await getValue(id), 'test');

      // null
      id = await insertValue(null);
      expect(await getValue(id), null);

      id = await insertValue(-1);
      expect(await getValue(id), -1);
      id = await insertValue(-1.1);
      expect(await getValue(id), -1.1);
      // big float
      id = await insertValue(1 / 3);
      expect(await getValue(id), 1 / 3);
      id = await insertValue(pow(2, 63) + .1);
      try {
        expect(await getValue(id), pow(2, 63) + 0.1);
      } on TestFailure catch (_) {
        // we might still get the positive value
        // This happens when use the server app
        expect(await getValue(id), -(pow(2, 63) + 0.1));
      }

      // integer?
      id = await insertValue(pow(2, 62));
      expect(await getValue(id), pow(2, 62));
      await data.db.close();
    });

    test("text", () async {
      //await Sqflite.devSetDebugModeOn(true);
      String path = await context.initDeleteDb("type_text.db");
      data.db = await factory.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (Database db, int version) async {
                await db.execute(
                    "CREATE TABLE Test (_id INTEGER PRIMARY KEY, value TEXT)");
              }));
      int id = await insertValue("simple text");
      expect(await getValue(id), "simple text");
      // null
      id = await insertValue(null);
      expect(await getValue(id), null);

      // utf-8
      id = await insertValue("àöé");
      expect(await getValue(id), "àöé");

      await data.db.close();
    });

    test("blob", () async {
      // await context.devSetDebugModeOn(true);
      String path = await context.initDeleteDb("type_blob.db");
      data.db = await factory.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (Database db, int version) async {
                await db.execute(
                    "CREATE TABLE Test (_id INTEGER PRIMARY KEY, value BLOB)");
              }));
      try {
        // insert text in blob
        int id = await insertValue("simple text");
        expect(await getValue(id), "simple text");

        // null
        id = await insertValue(null);
        expect(await getValue(id), null);

        // UInt8List - default
        ByteData byteData = ByteData(1);
        byteData.setInt8(0, 1);
        var blob = byteData.buffer.asUint8List();
        id = await insertValue(blob);
        //print(await getValue(id));
        var result = (await getValue(id)) as List;
        print(result.runtimeType);
        // this is not true when sqflite server
        expect(result is Uint8List, true);
        // expect(result is List, true);
        expect(result.length, 1);
        expect(result, [1]);

        // empty array not supported
        //id = await insertValue([]);
        //print(await getValue(id));
        //assert(eq.equals(await getValue(id), []));

        final blob1234 = [1, 2, 3, 4];
        id = await insertValue(blob1234);
        print(await getValue(id));
        print('${(await getValue(id)).length}');
        expect(await getValue(id), blob1234, reason: "${await getValue(id)}");

        // test hex feature on sqlite
        var hexResult = await data.db.rawQuery(
            'SELECT hex(value) FROM Test WHERE _id = ?', <dynamic>[id]);
        expect(hexResult[0].values.first, "01020304");

        // try blob lookup - does work
        var rows = await data.db.rawQuery(
            'SELECT * FROM Test WHERE value = ?', <dynamic>[blob1234]);
        if (Platform.isIOS || Platform.isAndroid) {
          print(Platform());
          expect(rows.length, 0);
        } else {
          // expect(rows.length, 1); // to iOS server
          // expect(rows.length, 0); // on Android server
        }

        // try blob lookup using hex
        rows = await data.db.rawQuery('SELECT * FROM Test WHERE hex(value) = ?',
            <dynamic>[utils.hex(blob1234)]);
        expect(rows.length, 1);
        expect(rows[0]['_id'], id);
      } finally {
        await data.db.close();
      }
    });

    test("null", () async {
      // await Sqflite.devSetDebugModeOn(true);
      String path = await context.initDeleteDb("type_null.db");
      data.db = await factory.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (Database db, int version) async {
                await db.execute(
                    "CREATE TABLE Test (_id INTEGER PRIMARY KEY, value TEXT)");
              }));
      try {
        int id = await insertValue(null);
        expect(await getValue(id), null);

        // Make a string
        expect(await updateValue(id, "dummy"), 1);
        expect(await getValue(id), "dummy");

        expect(await updateValue(id, null), 1);
        expect(await getValue(id), null);
      } finally {
        await data.db.close();
      }
    });

    test("date_time", () async {
      // await Sqflite.devSetDebugModeOn(true);
      String path = await context.initDeleteDb("type_date_time.db");
      data.db = await factory.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (Database db, int version) async {
                await db.execute(
                    "CREATE TABLE Test (_id INTEGER PRIMARY KEY, value TEXT)");
              }));
      try {
        bool failed = false;
        try {
          await insertValue(DateTime.fromMillisecondsSinceEpoch(1234567890));
        } catch (_) {
          // } on ArgumentError catch (_) { not throwing the same exception
          failed = true;
        }
        expect(failed, true);
      } finally {
        await data.db.close();
      }
    });

    test('sql timestamp', () async {
      // await Sqflite.devSetDebugModeOn(true);
      String path = await context.initDeleteDb("type_sql_timestamp.db");
      data.db = await factory.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (Database db, int version) async {
                await db.execute("CREATE TABLE Test (_id INTEGER PRIMARY KEY,"
                    " value TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL)");
              }));
      try {
        int id = await data.db.insert("Test", <String, dynamic>{"_id": 1});
        expect(DateTime.parse(await getValue(id) as String), isNotNull);
      } finally {
        await data.db.close();
      }

      data.db = await factory.openDatabase(inMemoryDatabasePath);
      try {
        var dateTimeText =
            (await data.db.rawQuery("SELECT datetime(1092941466, 'unixepoch')"))
                .first
                .values
                .first as String;
        expect(dateTimeText, '2004-08-19 18:51:06');
        expect(DateTime.parse(dateTimeText).toIso8601String(),
            '2004-08-19T18:51:06.000');
      } finally {
        await data.db.close();
      }
    });

    test('sql numeric', () async {
      // await Sqflite.devSetDebugModeOn(true);
      String path = await context.initDeleteDb("type_sql_numeric.db");
      data.db = await factory.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (Database db, int version) async {
                await db.execute("CREATE TABLE Test (_id INTEGER PRIMARY KEY,"
                    " value NUMERIC)");
              }));
      try {
        int id = await insertValue(1);
        expect(await getValue(id), 1);
        var value = await getValue(id);
        expect(value, const TypeMatcher<int>());

        id = await insertValue(-1);
        expect(await getValue(id), -1);
        id = await insertValue(-1.1);
        value = await getValue(id);
        expect(value, const TypeMatcher<double>());
        expect(value, -1.1);

        // big float
        id = await insertValue(1 / 3);
        expect(await getValue(id), 1 / 3);
        id = await insertValue(pow(2, 63) + .1);
        try {
          expect(await getValue(id), pow(2, 63) + 0.1);
        } on TestFailure catch (_) {
          // we might still get the positive value
          // This happens when use the server app
          expect(await getValue(id), -(pow(2, 63) + 0.1));
        }

        // integer?
        id = await insertValue(pow(2, 62));
        expect(await getValue(id), pow(2, 62));

        // text
        id = await insertValue('test');
        expect(await getValue(id), 'test');

        // int text
        id = await insertValue('18');
        expect(await getValue(id), 18);

        // double text
        id = await insertValue('18.1');
        expect(await getValue(id), 18.1);

        // empty text
        id = await insertValue('');
        expect(await getValue(id), '');

        // null
        id = await insertValue(null);
        expect(await getValue(id), null);
      } finally {
        await data.db.close();
      }
    });
    test("bool", () async {
      //await Sqflite.devSetDebugModeOn(true);
      String path = await context.initDeleteDb("type_bool.db");
      data.db = await factory.openDatabase(path,
          options: OpenDatabaseOptions(
              version: 1,
              onCreate: (Database db, int version) async {
                await db.execute(
                    "CREATE TABLE Test (_id INTEGER PRIMARY KEY, value BOOL)");
              }));

      // text
      int id = await insertValue('test');
      expect(await getValue(id), 'test');
    });
  });
}
