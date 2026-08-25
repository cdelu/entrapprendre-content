/// Exercises the source -> release JSON -> direct audio asset contract.
///
/// The temporary audio bytes are deliberately opaque: this is a packaging
/// smoke test, not a codec/player test. A real MP3 from Studio is still needed
/// for the final FlutterFlow playback check.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const _tag = 'content-v0.0.0-audio-smoke';

Future<void> main() async {
  final sourceRoot = Directory.fromUri(Platform.script).parent.parent;
  final temporaryRoot = await Directory.systemTemp.createTemp(
    'entrapprendre-audio-smoke-',
  );
  try {
    _copyDirectory(
      Directory('${sourceRoot.path}${Platform.pathSeparator}source'),
      Directory('${temporaryRoot.path}${Platform.pathSeparator}source'),
    );
    _copyDirectory(
      Directory('${sourceRoot.path}${Platform.pathSeparator}schema'),
      Directory('${temporaryRoot.path}${Platform.pathSeparator}schema'),
    );
    _copyDirectory(
      Directory('${sourceRoot.path}${Platform.pathSeparator}tool'),
      Directory('${temporaryRoot.path}${Platform.pathSeparator}tool'),
      skipFileName: 'smoke_audio_delivery.dart',
    );
    for (final fileName in ['pubspec.yaml', 'pubspec.lock']) {
      File('${sourceRoot.path}${Platform.pathSeparator}$fileName').copySync(
        '${temporaryRoot.path}${Platform.pathSeparator}$fileName',
      );
    }
    _copyDirectory(
      Directory('${sourceRoot.path}${Platform.pathSeparator}.dart_tool'),
      Directory('${temporaryRoot.path}${Platform.pathSeparator}.dart_tool'),
    );

    final unitFile = File(
      '${temporaryRoot.path}${Platform.pathSeparator}source'
      '${Platform.pathSeparator}units${Platform.pathSeparator}M02-U01'
      '${Platform.pathSeparator}unit.json',
    );
    final unit =
        jsonDecode(unitFile.readAsStringSync()) as Map<String, Object?>;
    final blocks = unit['blocks'] as List<Object?>;
    (blocks.first as Map<String, Object?>)['audio'] = {
      'tracks': {
        'fr': {'path': 'media/smoke-fr.mp3', 'transcript': 'Audio français.'},
        'ha': {'path': 'media/smoke-ha.mp3', 'transcript': 'Audio hausa.'},
        'dje': {'path': 'media/smoke-dje.mp3', 'transcript': 'Audio zarma.'},
      },
    };
    unitFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(unit)}\n',
    );

    final catalogFile = File(
      '${temporaryRoot.path}${Platform.pathSeparator}source'
      '${Platform.pathSeparator}catalog.source.json',
    );
    final catalog =
        jsonDecode(catalogFile.readAsStringSync()) as Map<String, Object?>;
    final summaries = catalog['units'] as List<Object?>;
    final summary = summaries.firstWhere(
      (item) => (item as Map<String, Object?>)['id'] == 'M02-U01',
    ) as Map<String, Object?>;
    final contentVersion = summary['contentVersion'] as int;
    summary.remove('hasAudio'); // Builder must derive this as true.
    catalogFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(catalog)}\n',
    );

    final mediaDirectory = Directory(
      '${temporaryRoot.path}${Platform.pathSeparator}source'
      '${Platform.pathSeparator}units${Platform.pathSeparator}M02-U01'
      '${Platform.pathSeparator}media',
    )..createSync(recursive: true);
    for (final language in ['fr', 'ha', 'dje']) {
      File('${mediaDirectory.path}${Platform.pathSeparator}smoke-$language.mp3')
          .writeAsBytesSync(List<int>.generate(64, (index) => index));
    }
    File('${mediaDirectory.path}${Platform.pathSeparator}smoke.mp3')
        .writeAsBytesSync(List<int>.generate(64, (index) => index));

    await _run(temporaryRoot, 'tool/validate_content.dart', ['--release']);
    await _run(temporaryRoot, 'tool/build_release.dart', ['--tag', _tag]);

    final output = Directory(
      '${temporaryRoot.path}${Platform.pathSeparator}dist'
      '${Platform.pathSeparator}$_tag',
    );
    final generatedUnit = jsonDecode(
      File(
        '${output.path}${Platform.pathSeparator}M02-U01-unit-v$contentVersion.json',
      ).readAsStringSync(),
    ) as Map<String, Object?>;
    final generatedBlocks = generatedUnit['blocks'] as List<Object?>;
    final audio = (generatedBlocks.first as Map<String, Object?>)['audio']
        as Map<String, Object?>;
    final tracks = audio['tracks'] as Map<String, Object?>;
    for (final language in ['fr', 'ha', 'dje']) {
      final track = tracks[language] as Map<String, Object?>;
      final expectedUrl =
          'https://github.com/cdelu/entrapprendre-content/releases/download/'
          '$_tag/M02-U01-smoke-$language.mp3';
      if (track['path'] != expectedUrl) {
        throw StateError(
          'URL audio inattendue pour $language : ${track['path']}',
        );
      }
      if (!File(
        '${output.path}${Platform.pathSeparator}M02-U01-smoke-$language.mp3',
      ).existsSync()) {
        throw StateError('Asset audio manquant pour $language.');
      }
    }
    final generatedCatalog = jsonDecode(
      File('${output.path}${Platform.pathSeparator}catalog.json')
          .readAsStringSync(),
    ) as Map<String, Object?>;
    final generatedSummary = (generatedCatalog['units'] as List<Object?>)
        .cast<Map<String, Object?>>()
        .firstWhere((item) => item['id'] == 'M02-U01');
    if (generatedSummary['hasAudio'] != true) {
      throw StateError('hasAudio n’a pas été dérivé du unit.json.');
    }
    if (!File('${output.path}${Platform.pathSeparator}M02-U01-smoke.mp3')
        .existsSync()) {
      throw StateError(
          'L’asset audio direct n’a pas été copié dans la release.');
    }
    stdout.writeln('Audio delivery smoke test passed.');
  } finally {
    temporaryRoot.deleteSync(recursive: true);
  }
}

Future<void> _run(
  Directory workingDirectory,
  String script,
  List<String> arguments,
) async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    ['run', script, ...arguments],
    workingDirectory: workingDirectory.path,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw ProcessException(
      Platform.resolvedExecutable,
      ['run', script, ...arguments],
      'Command failed with exit code ${result.exitCode}',
      result.exitCode,
    );
  }
}

void _copyDirectory(
  Directory source,
  Directory destination, {
  String? skipFileName,
}) {
  destination.createSync(recursive: true);
  for (final entity in source.listSync()) {
    if (entity is Directory) {
      _copyDirectory(
        entity,
        Directory(
          '${destination.path}${Platform.pathSeparator}${p.basename(entity.path)}',
        ),
        skipFileName: skipFileName,
      );
    } else if (entity is File && entity.uri.pathSegments.last != skipFileName) {
      entity.copySync(
        '${destination.path}${Platform.pathSeparator}${entity.uri.pathSegments.last}',
      );
    }
  }
}
