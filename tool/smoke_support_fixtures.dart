/// Structural fixture regression checks; no changes to the working course.
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final root = Directory.fromUri(Platform.script).parent.parent;
  final manifest = _read(File('${root.path}/schema/support-manifest.json'));
  var checked = 0;
  for (final group in ['blocks', 'exerciseItems']) {
    for (final entry in (manifest[group] as List).cast<Map>()) {
      if (entry['learnerRendererStatus'] != 'implemented') continue;
      final pointer = entry['fixturePath'];
      if (pointer is! String ||
          !pointer.startsWith('schema/fixtures/') ||
          !pointer.contains('#/')) {
        throw StateError('Missing independent fixture for ${entry['type']}');
      }
      final parts = pointer.split('#/');
      dynamic target = _read(File('${root.path}/${parts[0]}'));
      for (final token in parts[1].split('/')) {
        target = target is List ? target[int.parse(token)] : target[token];
      }
      if (target is! Map || target['kind'] != entry['type']) {
        throw StateError('Wrong fixture for ${entry['type']}');
      }
      checked++;
    }
  }

  final temporary = await Directory.systemTemp.createTemp('ea-fixtures-');
  try {
    for (final directory in ['source', 'schema']) {
      _copy(Directory('${root.path}/$directory'),
          Directory('${temporary.path}/$directory'));
    }
    Directory('${temporary.path}/tool').createSync();
    File('${root.path}/tool/validate_content.dart')
        .copySync('${temporary.path}/tool/validate_content.dart');
    await _validate(temporary, succeeds: true);

    // Lesson edits must not redefine the renderer's test examples.
    final lesson = File('${temporary.path}/source/units/M02-U01/unit.json');
    final unit = _read(lesson);
    unit['blocks'] = (unit['blocks'] as List).reversed.toList();
    lesson.writeAsStringSync(jsonEncode(unit));
    await _validate(temporary, succeeds: true);

    final fixture =
        File('${temporary.path}/schema/fixtures/supported-blocks.json');
    final original = fixture.readAsStringSync();
    final changed = _read(fixture);
    (changed['blocks'] as List).first['kind'] = 'quote';
    fixture.writeAsStringSync(jsonEncode(changed));
    await _validate(temporary, succeeds: false, diagnostic: 'fixturePath');
    fixture.writeAsStringSync(original);

    // Missing file failure without deleting any user-owned file.
    final manifestFile = File('${temporary.path}/schema/support-manifest.json');
    final missing = _read(manifestFile);
    (missing['blocks'] as List).first['fixturePath'] =
        'schema/fixtures/missing.json#/blocks/0';
    manifestFile.writeAsStringSync(jsonEncode(missing));
    await _validate(temporary, succeeds: false, diagnostic: 'introuvable');
    stdout.writeln('Support fixtures passed: $checked pointers; baseline, '
        'lesson reorder, wrong-kind and missing-file regression checks.');
  } finally {
    // Only the fresh directory allocated by this test is removed.
    temporary.deleteSync(recursive: true);
  }
}

Map<String, dynamic> _read(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

Future<void> _validate(Directory root,
    {required bool succeeds, String? diagnostic}) async {
  final result = await Process.run(Platform.resolvedExecutable,
      ['${root.path}/tool/validate_content.dart', '--release'],
      workingDirectory: root.path);
  final output = '${result.stdout}${result.stderr}';
  if ((result.exitCode == 0) != succeeds ||
      (diagnostic != null && !output.contains(diagnostic))) {
    throw StateError('Unexpected validator result: $output');
  }
}

void _copy(Directory source, Directory destination) {
  destination.createSync(recursive: true);
  for (final entry in source.listSync(followLinks: false)) {
    final name = entry.path.split(Platform.pathSeparator).last;
    final target = '${destination.path}/$name';
    if (entry is Directory) {
      _copy(entry, Directory(target));
    } else if (entry is File) {
      entry.copySync(target);
    }
  }
}
