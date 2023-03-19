import 'package:dev_test/test.dart';
import 'package:sqflite_common_porter/src/sql_parser.dart';

String bookshelfSql = '''
CREATE TABLE book (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT);
INSERT INTO book(title) VALUES ('Le petit prince');
INSERT INTO book(title) VALUES ('Harry Potter');''';

void main() {
  group('src_utils', () {
    test('parseStatements', () {
      var statements = parseStatements(bookshelfSql);
      expect(statements, [
        'CREATE TABLE book (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT);',
        'INSERT INTO book(title) VALUES (\'Le petit prince\');',
        'INSERT INTO book(title) VALUES (\'Harry Potter\');'
      ]);
/*
      statements = parseStatements('SELECT;CREATE ;');
      expect(statements, ['SELECT;', 'CREATE ;']);
      */
    });
  });
}
