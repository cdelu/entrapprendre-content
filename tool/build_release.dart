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
      if (!unitFile.existsSync()) {
        generatedUnits.add(summary);
        continue;
      }

      final unit = _readObject(unitFile);
      if (unit['id'] != unitId) {
        throw FormatException(
          '${p.relative(unitFile.path, from: root.path)} : '
          'id ${unit['id']} différent de $unitId.',
        );
      }
      // Keep the learner-facing catalogue honest even when an author forgets
      // to toggle the summary flag by hand. The unit JSON is authoritative.
      summary['hasAudio'] = _unitContainsAudio(unit);
      generatedUnits.add(summary);
      if (unit['status'] != 'published') continue;

      // Chaque fichier de `media/` part aussi comme asset de release
      // directement adressable, et le JSON publié voit ses chemins relatifs
      // réécrits en URL immuables.
      //
      // C'est ce qui rend `image` et `audio` utilisables : les widgets natifs
      // Image et AudioPlayer veulent une URL joignable, alors que l'archive
      // `media` ne sert qu'au téléchargement hors ligne différé. La source, elle,
      // garde des chemins relatifs — elle reste lisible et déplaçable.
      final mediaUrls = _publishMediaAssets(
        unitDirectory: unitDirectory,
        outputDirectory: outputDirectory,
        packageStem: packageStem,
        tag: tag,
        publishedAssets: publishedAssets,
      );
      final unitPublie = _rewriteMediaPaths(unit, mediaUrls, unitId);

      // FlutterFlow reads the lesson JSON directly. Keep this lightweight
      // asset alongside the ZIP packages, which remain useful for a later
      // explicit offline-download flow.
      final unitJsonName = '$packageStem-unit-v$contentVersion.json';
      final unitJsonFile = File(p.join(outputDirectory.path, unitJsonName));
      unitJsonFile.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(unitPublie)}\n',
      );
      publishedAssets.add(unitJsonName);

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
    final navigation = _buildNavigation(catalog, generatedUnits);
    catalog
      ..['navigationSummary'] =
          '${navigation.length} modules · ${generatedUnits.length} unités'
      ..['navigation'] = navigation
      ..['progressSegments'] = _buildProgressSegments(navigation);
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

List<Map<String, Object?>> _buildNavigation(
  Map<String, Object?> catalog,
  List<Map<String, Object?>> units,
) {
  final rawParts = catalog['parts'];
  final rawModules = catalog['modules'];
  if (rawParts is! List<Object?> || rawModules is! List<Object?>) {
    throw const FormatException(
      'catalog.parts et catalog.modules doivent être des listes.',
    );
  }

  final modulesById = <String, Map<String, Object?>>{
    for (final module in rawModules.whereType<Map<String, Object?>>())
      if (module['id'] is String) module['id']! as String: module,
  };
  final unitsById = <String, Map<String, Object?>>{
    for (final unit in units)
      if (unit['id'] is String) unit['id']! as String: unit,
  };
  final navigation = <Map<String, Object?>>[];

  for (final part in rawParts.whereType<Map<String, Object?>>()) {
    final moduleIds = (part['moduleIds'] as List<Object?>).cast<String>();
    var partUnitCount = 0;
    for (final moduleId in moduleIds) {
      final module = modulesById[moduleId];
      if (module == null) {
        throw FormatException(
            'Module introuvable pendant la génération : $moduleId');
      }
      partUnitCount += (module['unitIds'] as List<Object?>).length;
    }

    for (var moduleIndex = 0; moduleIndex < moduleIds.length; moduleIndex++) {
      final moduleId = moduleIds[moduleIndex];
      final module = modulesById[moduleId]!;
      final unitIds = (module['unitIds'] as List<Object?>).cast<String>();
      final moduleUnits = <Map<String, Object?>>[];

      for (final unitId in unitIds) {
        final unit = unitsById[unitId];
        if (unit == null) {
          throw FormatException(
            'Unité introuvable pendant la génération : $unitId',
          );
        }
        final estimatedMinutes = unit['estimatedMinutes'];
        final hasAudio = unit['hasAudio'] == true;
        moduleUnits.add({
          ...unit,
          'numberLabel': (unit['number']! as int).toString().padLeft(2, '0'),
          'statusLabel': unit['downloadable'] == true
              ? 'Prête à télécharger'
              : 'Contenu à venir',
          'detailLabel': estimatedMinutes is int
              ? '$estimatedMinutes min${hasAudio ? ' · audio' : ''}'
              : hasAudio
                  ? 'Audio disponible'
                  : 'Lecture et activité',
        });
      }

      navigation.add({
        'id': moduleId,
        'number': module['number'],
        'partId': part['id'],
        'partNumber': part['number'],
        'partTitle': part['title'],
        'showPartHeader': moduleIndex == 0,
        'partDetail': '${moduleIds.length} modules · $partUnitCount unités',
        'title': module['title'],
        'detail': '${unitIds.length} unités',
        'generatesCertificate': module['generatesCertificate'] == true,
        'units': moduleUnits,
      });
    }
  }

  return navigation;
}

bool _unitContainsAudio(Map<String, Object?> unit) {
  final blocks = unit['blocks'];
  if (blocks is! List) return false;
  return blocks.any(
    (block) => block is Map<String, Object?> && block['audio'] != null,
  );
}

List<Map<String, Object?>> _buildProgressSegments(
  List<Map<String, Object?>> navigation,
) {
  final segments = <Map<String, Object?>>[];
  for (var moduleIndex = 0; moduleIndex < navigation.length; moduleIndex++) {
    final module = navigation[moduleIndex];
    final units = (module['units'] as List<Object?>)
        .whereType<Map<String, Object?>>()
        .toList(growable: false);
    for (var unitIndex = 0; unitIndex < units.length; unitIndex++) {
      segments.add({
        'moduleNumber': module['number'],
        'showModuleDivider': moduleIndex > 0 && unitIndex == 0,
      });
    }
  }
  return segments;
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

/// Copie chaque fichier de `media/` comme asset de release et renvoie la table
/// « chemin relatif dans la source → URL immuable ».
///
/// Le nom d'asset est préfixé par le radical de l'unité, parce que les assets
/// d'une release partagent un espace de noms plat : deux unités avec un
/// `media/atelier.jpg` s'écraseraient l'une l'autre.
Map<String, String> _publishMediaAssets({
  required Directory unitDirectory,
  required Directory outputDirectory,
  required String packageStem,
  required String tag,
  required List<String> publishedAssets,
}) {
  final urls = <String, String>{};
  final mediaDirectory = Directory(p.join(unitDirectory.path, 'media'));
  if (!mediaDirectory.existsSync()) return urls;

  for (final file in _collectFiles(mediaDirectory)) {
    final relatif =
        p.relative(file.path, from: unitDirectory.path).replaceAll(r'\', '/');
    final assetName =
        '$packageStem-${relatif.substring('media/'.length).replaceAll('/', '-')}';
    file.copySync(p.join(outputDirectory.path, assetName));
    publishedAssets.add(assetName);
    urls[relatif] =
        'https://github.com/$_owner/$_repository/releases/download/$tag/$assetName';
  }
  return urls;
}

/// Réécrit `audio.path`, `audio.tracks.*.path` et `image.path` de chaque bloc
/// en URL de release.
///
/// Un chemin sans asset correspondant est une erreur franche : livrer un JSON
/// qui pointe vers un fichier absent donnerait une image cassée ou un lecteur
/// audio muet chez l'apprenant, sans rien dans les journaux.
Map<String, Object?> _rewriteMediaPaths(
  Map<String, Object?> unit,
  Map<String, String> mediaUrls,
  String unitId,
) {
  final copie = jsonDecode(jsonEncode(unit)) as Map<String, Object?>;
  final blocs = copie['blocks'];
  if (blocs is! List) return copie;

  for (final bloc in blocs) {
    if (bloc is! Map) continue;
    final image = bloc['image'];
    if (image is Map) {
      _rewriteOneMediaPath(
        image,
        mediaUrls,
        '$unitId, bloc ${bloc['id']} : image.path',
      );
    }

    final audio = bloc['audio'];
    if (audio is! Map) continue;
    final tracks = audio['tracks'];
    if (tracks is Map) {
      for (final entry in tracks.entries) {
        final track = entry.value;
        if (track is Map) {
          _rewriteOneMediaPath(
            track,
            mediaUrls,
            '$unitId, bloc ${bloc['id']} : audio.tracks.${entry.key}.path',
          );
        }
      }
    } else {
      _rewriteOneMediaPath(
        audio,
        mediaUrls,
        '$unitId, bloc ${bloc['id']} : audio.path',
      );
    }
  }
  return copie;
}

void _rewriteOneMediaPath(
  Map media,
  Map<String, String> mediaUrls,
  String label,
) {
  final chemin = media['path'];
  if (chemin is! String || chemin.isEmpty) return;
  final url = mediaUrls[chemin];
  if (url == null) {
    throw StateError(
        '$label « $chemin » ne correspond pas à un fichier de media/.');
  }
  media['path'] = url;
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
