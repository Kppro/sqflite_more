import 'package:path/path.dart';
import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  for (var dir in [
    'sqflite_common_server',
    'sqflite_common_test_app',
  ]) {
    shell = shell.pushd(join('..', dir));
    await shell.run('''

pub get
dart tool/travis.dart

    ''');
    shell = shell.popd();
  }

  for (var dir in [
    'sqflite_porter',
    'sqflite_server',
    'sqflite_test',
    'sqflite_ffi_test',
    'sqflite_test_app',
    'sqflite_server_app',
    'alt/sqflite_github_test'
  ]) {
    shell = shell.pushd(join('..', dir));
    await shell.run('''

flutter packages get
dart tool/travis.dart

    ''');
    shell = shell.popd();
  }
}
