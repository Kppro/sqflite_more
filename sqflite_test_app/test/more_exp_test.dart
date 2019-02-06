import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_test/sqflite_test.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';

class TestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    //if (key == 'resources/test')
    return ByteData.view(
        Uint8List.fromList(await File(key).readAsBytes()).buffer);
    // return null;
  }
}

Future main() async {
  var context = await SqfliteServerTestContext.connect();
  if (context != null) {
    var factory = context.databaseFactory;

    test("Issue#144", () async {
      /*

      initDb() async {
        String databases_path = await getDatabasesPath();
        String path = join(databases_path, 'example.db');

        print(FileSystemEntity.typeSync(path) ==
            FileSystemEntityType.notFound); // false
        Database oldDB = await openDatabase(path);
        List count = await oldDB.rawQuery(
            "select 'name' from sqlite_master where name = 'example_table'");
        print(count.length); // 0

        print('copy from asset');
        await deleteDatabase(path);
        print(FileSystemEntity.typeSync(path) ==
            FileSystemEntityType.notFound); // true
        ByteData data =
            await rootBundle.load(join("assets", 'example.db')); // 6,9 MB

        List<int> bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes);
        Database db = await openDatabase(path);
        print(FileSystemEntity.typeSync(path) ==
            FileSystemEntityType.notFound); // false
        List count2 = await db.rawQuery(
            "select 'name' from sqlite_master where name = 'example_table'");
        print(count2.length); // 0 should 1

        return db; // should
      }

       */
      // Sqflite.devSetDebugModeOn(true);
      // Try to insert string with quote
      String path = await context.initDeleteDb("exp_issue_144.db");
      var rootBundle = TestAssetBundle();
      Database db;
      print('current dir: ${absolute(Directory.current.path)}');
      print('path: $path');
      try {
        Future<Database> initDb() async {
          Database oldDB = await factory.openDatabase(path);
          List count = await oldDB
              .rawQuery("select 'name' from sqlite_master where name = 'Test'");
          print(count.length); // 0

          // IMPORTANT! Close the database before deleting it
          await oldDB.close();

          print('copy from asset');
          await factory.deleteDatabase(path);
          ByteData data = await rootBundle.load(join("assets", 'example.db'));

          List<int> bytes =
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          //print(bytes);
          expect(bytes.length, greaterThan(1000));
          // Writing the database
          await context.writeFile(path, bytes);
          Database db = await factory.openDatabase(path,
              options: OpenDatabaseOptions(readOnly: true));
          List count2 = await db
              .rawQuery("select 'name' from sqlite_master where name = 'Test'");
          print(count2);

          // Our database as a single table with a single element
          List<Map<String, dynamic>> list =
              await db.rawQuery("SELECT * FROM Test");
          print("list $list");
          // list [{id: 1, name: simple value}]
          expect(list.first["name"], "simple value");

          return db; // should
        }

        db = await initDb();
      } finally {
        await db?.close();
      }
    });

    test('Issue#146', () => issue146(context));

    test('Issue#159', () async {
      var db = DbHelper(context);
      User user1 = User("User1");
      int insertResult = await db.saveUser(user1);
      print("insert result is " + insertResult.toString());
      User searchResult = await db.retrieveUser(insertResult);
      print(searchResult.toString());
    });
    test('primary key', () async {
      String path = await context.initDeleteDb("primary_key.db");
      Database db = await factory.openDatabase(path);
      try {
        String table = "test";
        await db
            .execute("CREATE TABLE $table (id INTEGER PRIMARY KEY, name TEXT)");
        var id = await db.insert(table, <String, dynamic>{'name': 'test'});
        var id2 = await db.insert(table, <String, dynamic>{'name': 'test'});

        print('inserted $id, $id2');
        // inserted in a wrong order to check ASC/DESC

        print(await db.query(table));
        //await db
      } finally {
        db.close();
      }
    });
  }
}

/// Issue 146

/* original
class ClassroomProvider {
  Future<Classroom> insert(Classroom room) async {
    return database.transaction((txn) async {
      room.id = await db.insert(tableClassroom, room.toMap());
      await _teacherProvider.insert(room.getTeacher());
      await _studentProvider.bulkInsert(
          room.getStudents()); // nest transaction here
      return room;
    }
        }

  );
}}

class TeacherProvider {
  Future<Teacher> insert(Teacher teacher) async {
    teacher.id = await db.insert(tableTeacher, teacher.toMap());
    return teacher;
  }
}

class StudentProvider {
  Future<List<Student>> bulkInsert(List<Student> students) async {
    // use database object in a transaction here !!!
    return database.transaction((txn) async {
      for (var s in students) {
        s.id = await db.insert(tableStudent, student.toMap());
      }
      return students;
    });
  }
}
*/

String tableItem = 'Test';
String tableClassroom = tableItem;
String tableTeacher = tableItem;
String tableStudent = tableItem;

class Item {
  int id;
  String name;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'name': name};
  }
}

class Classroom extends Item {
  Teacher _teacher;
  List<Student> _students;

  Teacher getTeacher() => _teacher;

  List<Student> getStudents() => _students;
}

class Teacher extends Item {}

class Student extends Item {}

TeacherProvider _teacherProvider;
StudentProvider _studentProvider;

Future issue146(SqfliteServerTestContext context) async {
  //context.devSetDebugModeOn(true);
  try {
    String path = await context.initDeleteDb("exp_issue_146.db");
    database = await context.databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (Database db, int version) {
              db.execute(
                  'CREATE TABLE Test (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)');
            }));

    _teacherProvider = TeacherProvider();
    _studentProvider = StudentProvider();
    var _classroomProvider = ClassroomProvider();
    var room = Classroom()..name = 'room1';
    room._teacher = Teacher()..name = 'teacher1';
    room._students = [Student()..name = 'student1'];
    await _classroomProvider.insert(room);
  } finally {
    database?.close();
    database = null;
  }
}

Database database;

class ClassroomProvider {
  Future<Classroom> insert(Classroom room) async {
    return database.transaction((txn) async {
      await _teacherProvider.txnInsert(txn, room.getTeacher());
      await _studentProvider.txnBulkInsert(
          txn, room.getStudents()); // nest transaction here
      // Insert room last to save the teacher and students ids
      room.id = await txn.insert(tableClassroom, room.toMap());
      return room;
    });
  }
}

class TeacherProvider {
  Future<Teacher> insert(Teacher teacher) =>
      database.transaction((txn) => txnInsert(txn, teacher));

  Future<Teacher> txnInsert(Transaction txn, Teacher teacher) async {
    teacher.id = await txn.insert(tableTeacher, teacher.toMap());
    return teacher;
  }
}

class StudentProvider {
  Future<List<Student>> bulkInsert(List<Student> students) =>
      database.transaction((txn) => txnBulkInsert(txn, students));

  Future<List<Student>> txnBulkInsert(
      Transaction txn, List<Student> students) async {
    for (var student in students) {
      student.id = await txn.insert(tableStudent, student.toMap());
    }
    return students;
  }
}

// Issue 159

class DbHelper {
  final SqfliteServerTestContext context;
  static Database _db;

  DbHelper(this.context);

  void _onCreate(Database _db, int newVersion) async {
    await _db.execute(
        "CREATE TABLE MYTABLE(ID INTEGER PRIMARY KEY, userName TEXT NOT NULL)");
  }

  Future<Database> initDB() async {
    //Directory documentDirectory = await contextgetApplicationDocumentsDirectory();
    // String path = join(documentDirectory.path, "appdb.db");
    String path = await context.initDeleteDb('issue159.db');
    Database newDB = await context.databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(version: 1, onCreate: _onCreate));
    return newDB;
  }

  Future<Database> get db async {
    if (_db != null) {
      return _db;
    } else {
      _db = await initDB();
      return _db;
    }
  }

  Future<int> saveUser(User user) async {
    var dbClient = await db;
    int result;
    var userMap = user.toMap();
    result = await dbClient.insert("MYTABLE", userMap);
    return result;
  }

  Future<User> retrieveUser(int id) async {
    var dbClient = await db;
    if (id == null) {
      print("The ID is null, cannot find user with Id null");
      var nullResult =
          await dbClient.rawQuery("SELECT * FROM MYTABLE WHERE ID is null");
      return User.fromMap(nullResult.first);
    }
    String sql = "SELECT * FROM MYTABLE WHERE ID = $id";
    var result = await dbClient.rawQuery(sql);
    print(result);
    if (result.length != 0) {
      return User.fromMap(result.first);
    } else {
      return null;
    }
  }
}

class User {
  String _userName;
  int _id;

  String get userName => _userName;

  int get id => _id;

  User(this._userName, [this._id]);

  User.map(dynamic obj) {
    this._userName = obj['userName'] as String;
    this._id = obj['id'] as int;
  }

  User.fromMap(Map<String, dynamic> map) {
    this._userName = map["userName"] as String;
    if (map["id"] != null) {
      this._id = map["id"] as int;
    } else {
      print("in fromMap, Id is null");
    }
  }

  Map<String, dynamic> toMap() {
    var map = Map<String, dynamic>();
    map["userName"] = this._userName;
    if (_id != null) {
      map["id"] = _id;
    } else {
      print("in toMap, id is null");
    }
    return map;
  }

  @override
  String toString() {
    return "ID is ${this._id} , Username is ${this._userName} }";
  }
}
