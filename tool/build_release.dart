import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

const _owner = 'cdelu';
const _repository = 'entrapprendre-content';
final _tagPattern = RegExp(
  r'^content-v\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$',
);
final _fixedZipTimestamp = DateTime.utc(1980, 1, 1);

Future<void> main(List<String> arguments) async {
  try {
    final tag = _readTag(arguments);
    final root = File.fromUri(Platform.script).parent.parent;
    final sourceFile = File(p.join(root.path, 'source', 'catalog.source.json'));
    final outputDirectory = Directory(p.join(root.path, 'dist', tag));

    if (outputDirectory.existsSync() && outputDirectory.listSync().isNotEmpty) {
      throw StateError(
        '${p.relative(outputDirectory.path, from: root.path)} existe déjà. '
        'Une publication est immuable : utilisez un nouveau tag.',
      );
    }
    outputDirectory.createSync(recursive: true);

    final catalog = _readObject(sourceFile);
    final rawUnits = catalog['units'];
    if (rawUnits is! List<Object?>) {
      throw const FormatException('catalog.units doit être une liste.');
    }

    var packagedUnitCount = 0;
    final publishedAssets = <String>[];
    final generatedUnits = <Map<String, Object?>>[];

    for (final rawUnit in rawUnits) {
      if (rawUnit is! Map<String, Object?>) {
        throw const FormatException(
            'Chaque résumé d’unité doit être un objet.');
      }
      final summary = Map<String, Object?>.from(rawUnit)
        ..['downloadable'] = false
        ..remove('packages');
      generatedUnits.add(summary);

      final unitId = summary['id'];
      final contentVersion = summary['contentVersion'];
      final packageStem = summary['packageStem'];
      if (unitId is! String ||
          contentVersion is! int ||
          packageStem is! String) {
        throw FormatException('Résumé d’unité incomplet : $summary');
      }

      final unitDirectory = Directory(
        p.join(root.path, 'source', 'units', unitId),
      );
      final unitFile = File(p.join(unitDirectory.path, 'unit.json'));
      if (!unitFile.existsSync()) continue;

      final unit = _readObject(unitFile);
      if (unit['id'] != unitId) {
        throw FormatException(
          '${p.relative(unitFile.path, from: root.path)} : '
          'id ${unit['id']} différent de $unitId.',
        );
      }
      if (unit['status'] != 'published') continue;

      final coreFiles = _collectFiles(
        unitDirectory,
        excludeTopLevelDirectory: 'media',
      );
      if (!coreFiles.any((file) => p.basename(file.path) == 'unit.json')) {
        throw StateError('$unitId : unit.json manque au paquet léger.');
      }

      final coreName = '$packageStem-core-v$contentVersion.zip';
      final coreFile = File(p.join(outputDirectory.path, coreName));
      _writeZip(coreFile, unitDirectory, coreFiles);

      final packages = <String, Object?>{
        'light': _packageDescriptor(tag, coreFile),
      };
      publishedAssets.add(coreName);

      final mediaDirectory = Directory(p.join(unitDirectory.path, 'media'));
      if (mediaDirectory.existsSync()) {
        final mediaFiles = _collectFiles(mediaDirectory);
        if (mediaFiles.isNotEmpty) {
          final mediaName = '$packageStem-media-v$contentVersion.zip';
          final mediaFile = File(p.join(outputDirectory.path, mediaName));
          _writeZip(mediaFile, unitDirectory, mediaFiles);
          packages['completeAddon'] = _packageDescriptor(tag, mediaFile);
          publishedAssets.add(mediaName);
        }
      }

      summary
        ..['downloadable'] = true
        ..['packages'] = packages;
      packagedUnitCount++;
    }

    catalog['units'] = generatedUnits;
    final catalogFile = File(p.join(outputDirectory.path, 'catalog.json'));
    catalogFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(catalog)}\n',
      flush: true,
    );
    publishedAssets.insert(0, 'catalog.json');

    stdout.writeln(
      'Catalogue généré : '
      '${p.relative(catalogFile.path, from: root.path)}',
    );
    stdout.writeln('Unités téléchargeables : $packagedUnitCount');
    stdout.writeln('Assets de release : ${publishedAssets.join(', ')}');
  } on Object catch (error) {
    stderr.writeln('Génération refusée : $error');
    exitCode = 1;
  }
}

String _readTag(List<String> arguments) {
  if (arguments.length != 2 || arguments.first != '--tag') {
    throw const FormatException(
      'Usage : dart run tool/build_release.dart --tag content-v0.1.0',
    );
  }
  final tag = arguments[1];
  if (!_tagPattern.hasMatch(tag)) {
    throw FormatException(
      'Tag invalide : $tag. Format attendu : content-v1.2.3.',
    );
  }
  return tag;
}

Map<String, Object?> _readObject(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw FormatException('${file.path} doit contenir un objet JSON.');
  }
  return decoded;
}

List<File> _collectFiles(
  Directory directory, {
  String? excludeTopLevelDirectory,
}) {
  final files = directory
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) {
    final relative = p.relative(file.path, from: directory.path);
    final segments = p.split(relative);
    return excludeTopLevelDirectory == null ||
        segments.first != excludeTopLevelDirectory;
  }).toList()
    ..sort((left, right) => left.path.compareTo(right.path));
  return files;
}

void _writeZip(File destination, Directory unitDirectory, List<File> files) {
  final archive = Archive();
  for (final file in files) {
    final archivePath = p
        .relative(file.path, from: unitDirectory.path)
        .split(p.separator)
        .join('/');
    final entry = ArchiveFile.bytes(archivePath, file.readAsBytesSync())
      ..creationTime = 0
      ..lastModTime = 0;
    archive.addFile(entry);
  }
  final bytes = ZipEncoder().encodeBytes(
    archive,
    modified: _fixedZipTimestamp,
  );
  destination.writeAsBytesSync(bytes, flush: true);
}

Map<String, Object?> _packageDescriptor(String tag, File file) {
  final bytes = file.readAsBytesSync();
  final name = p.basename(file.path);
  return {
    'url':
        'https://github.com/$_owner/$_repository/releases/download/$tag/$name',
    'sizeBytes': bytes.length,
    'sha256': sha256.convert(bytes).toString(),
  };
}
