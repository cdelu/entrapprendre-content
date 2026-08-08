import 'dart:convert';
import 'dart:io';

final class ValidationContext {
  ValidationContext({required this.releaseMode, required this.typesRendus});

  /// Vrai sous `--release` : la validation devient un contrôle de publication.
  final bool releaseMode;

  /// Types que le lecteur apprenant sait réellement afficher, lus dans
  /// `schema/support-manifest.json`. Un type absent d'ici produit une page
  /// blanche chez l'apprenant, pas une erreur.
  final Set<String> typesRendus;

  final errors = <String>[];

  void error(String path, String message) {
    errors.add('$path : $message');
  }
}

void main(List<String> arguments) {
  final releaseMode = arguments.contains('--release');
  final root = File.fromUri(Platform.script).parent.parent;

  // Le manifeste se lit avant tout le reste : sans lui, le mode release ne
  // peut pas garantir sa promesse. Le contexte d'amorçage ne sert qu'à
  // collecter une éventuelle erreur de lecture.
  final amorce = ValidationContext(releaseMode: releaseMode, typesRendus: {});
  final typesRendus = _lireTypesRendus(root, amorce);
  final context = ValidationContext(
    releaseMode: releaseMode,
    typesRendus: typesRendus,
  );
  context.errors.addAll(amorce.errors);

  _validerFixturesManifeste(root, context);

  final catalogFile = File(
    '${root.path}${Platform.pathSeparator}source'
    '${Platform.pathSeparator}catalog.source.json',
  );
  final catalog = _readObject(catalogFile, context);
  if (catalog != null) {
    _validateCatalog(catalog, context);
    _validateUnitFiles(root, catalog, context);
  }

  if (context.errors.isNotEmpty) {
    stderr.writeln(
      'Validation refusée : ${context.errors.length} problème(s) trouvé(s).',
    );
    for (final error in context.errors) {
      stderr.writeln('  - $error');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln(
    releaseMode
        ? 'Contenu valide. Les unités non publiées seront exclues de la release.'
        : 'Contenu valide. Les brouillons restent autorisés dans ce mode.',
  );
}

/// Types dont `learnerRendererStatus` vaut `implemented` dans le manifeste.
///
/// C'est ce qui rend le manifeste exécutable plutôt que documentaire :
/// promouvoir un type se fait en une ligne, et oublier de le faire empêche la
/// publication au lieu de livrer un bloc vide.
Set<String> _lireTypesRendus(Directory root, ValidationContext context) {
  final separator = Platform.pathSeparator;
  final file = File('${root.path}${separator}schema${separator}support-manifest.json');
  final manifeste = _readObject(file, context);
  if (manifeste == null) {
    return const {};
  }
  final blocs = manifeste['blocks'];
  if (blocs is! List) {
    context.error('${file.path}#/blocks', 'doit être une liste');
    return const {};
  }
  final types = <String>{};
  for (var index = 0; index < blocs.length; index++) {
    final bloc = blocs[index];
    if (bloc is! Map<String, Object?>) {
      context.error('${file.path}#/blocks[$index]', 'doit être un objet');
      continue;
    }
    final type = bloc['type'];
    if (type is! String) {
      context.error('${file.path}#/blocks[$index].type', 'doit être une chaîne');
      continue;
    }
    if (bloc['learnerRendererStatus'] == 'implemented') {
      types.add(type);
    }
  }
  if (types.isEmpty) {
    context.error(file.path, 'aucun type rendu déclaré : manifeste inutilisable');
  }
  return types;
}

/// Vérifie que chaque type déclaré rendu pointe vers un vrai bloc de ce type.
///
/// Le manifeste affirme deux choses qu'aucun outil ne contrôlait : qu'un type
/// est rendu par l'application apprenante, et qu'un bloc d'exemple le prouve.
/// La première ne se vérifie pas d'ici — les deux dépôts sont séparés. La
/// seconde, si : un `fixturePath` mort signale un manifeste qui a cessé de
/// décrire le contenu, et c'est le symptôme le plus probable d'une dérive.
///
/// Les tests de garde du dépôt applicatif, eux, rejouent une création
/// synthétique et ne peuvent pas rejouer les scripts de promotion, qui
/// dépendent de clés de nœuds vivantes. Ce contrôle-ci est donc le seul filet
/// automatique sur la parité contenu/manifeste.
void _validerFixturesManifeste(Directory root, ValidationContext context) {
  final separator = Platform.pathSeparator;
  final chemin = '${root.path}${separator}schema${separator}support-manifest.json';
  final manifeste = _readObject(File(chemin), context);
  final blocs = manifeste?['blocks'];
  if (blocs is! List) return;

  for (final bloc in blocs) {
    if (bloc is! Map<String, Object?>) continue;
    final type = bloc['type'];
    if (bloc['learnerRendererStatus'] != 'implemented') continue;
    final fixture = bloc['fixturePath'];
    if (fixture == null) continue; // audio n'a pas encore d'unité porteuse
    if (fixture is! String) {
      context.error('support-manifest.json#$type', 'fixturePath doit être une chaîne');
      continue;
    }

    final morceaux = fixture.split('#/blocks/');
    if (morceaux.length != 2) {
      context.error(
        'support-manifest.json#$type',
        'fixturePath attendu sous la forme <fichier>#/blocks/<index>',
      );
      continue;
    }
    final fichier = File(
      '${root.path}$separator${morceaux[0].replaceAll('/', separator)}',
    );
    final index = int.tryParse(morceaux[1]);
    if (index == null) {
      context.error('support-manifest.json#$type', 'index de bloc illisible');
      continue;
    }
    final unite = _readObject(fichier, context);
    if (unite == null) continue;
    final blocsUnite = unite['blocks'];
    if (blocsUnite is! List || index >= blocsUnite.length) {
      context.error(
        'support-manifest.json#$type',
        'fixturePath pointe au-delà des blocs de ${morceaux[0]}',
      );
      continue;
    }
    final cible = blocsUnite[index];
    final kindCible = cible is Map ? cible['kind'] : null;
    if (kindCible != type) {
      context.error(
        'support-manifest.json#$type',
        'fixturePath pointe sur un bloc « $kindCible », pas « $type »',
      );
    }
  }
}

Map<String, Object?>? _readObject(File file, ValidationContext context) {
  if (!file.existsSync()) {
    context.error(file.path, 'fichier introuvable');
    return null;
  }
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      context.error(file.path, 'la racine JSON doit être un objet');
      return null;
    }
    return decoded;
  } on FormatException catch (error) {
    context.error(file.path, 'JSON incorrect (${error.message})');
    return null;
  }
}

void _validateCatalog(Map<String, Object?> catalog, ValidationContext context) {
  const path = 'source/catalog.source.json';
  _expectInteger(catalog, 'schemaVersion', path, context, expected: 1);
  _expectInteger(catalog, 'catalogVersion', path, context, minimum: 1);
  final course = _expectObject(catalog, 'course', path, context);
  if (course != null) {
    _expectIdentifier(course, 'id', '$path.course', context);
    _expectText(course, 'title', '$path.course', context);
    _expectText(course, 'language', '$path.course', context);
    final variant = _expectText(
      course,
      'defaultVariant',
      '$path.course',
      context,
    );
    if (variant != null && variant != 'light' && variant != 'complete') {
      context.error(
        '$path.course.defaultVariant',
        'valeur attendue : light ou complete',
      );
    }
  }

  final parts = _expectObjectList(catalog, 'parts', path, context);
  final modules = _expectObjectList(catalog, 'modules', path, context);
  final units = _expectObjectList(catalog, 'units', path, context);
  final partIds = _uniqueIds(parts, '$path.parts', context);
  final moduleIds = _uniqueIds(modules, '$path.modules', context);
  final unitIds = _uniqueIds(units, '$path.units', context);

  for (var index = 0; index < parts.length; index++) {
    final part = parts[index];
    final itemPath = '$path.parts[$index]';
    _expectIdentifier(part, 'id', itemPath, context);
    _expectInteger(part, 'number', itemPath, context, minimum: 1);
    _expectText(part, 'title', itemPath, context);
    final references = _expectStringList(part, 'moduleIds', itemPath, context);
    _checkUniqueValues(references, '$itemPath.moduleIds', context);
    for (final id in references) {
      if (!moduleIds.contains(id)) {
        context.error('$itemPath.moduleIds', 'module inconnu : $id');
      }
    }
  }

  for (var index = 0; index < modules.length; index++) {
    final module = modules[index];
    final itemPath = '$path.modules[$index]';
    _expectIdentifier(module, 'id', itemPath, context);
    _expectInteger(module, 'number', itemPath, context, minimum: 1);
    _expectText(module, 'title', itemPath, context);
    final partId = _expectIdentifier(module, 'partId', itemPath, context);
    if (partId != null && !partIds.contains(partId)) {
      context.error('$itemPath.partId', 'partie inconnue : $partId');
    }
    final references = _expectStringList(module, 'unitIds', itemPath, context);
    _checkUniqueValues(references, '$itemPath.unitIds', context);
    for (final id in references) {
      if (!unitIds.contains(id)) {
        context.error('$itemPath.unitIds', 'unité inconnue : $id');
      }
    }
  }

  for (var index = 0; index < units.length; index++) {
    final unit = units[index];
    final itemPath = '$path.units[$index]';
    final id = _expectIdentifier(unit, 'id', itemPath, context);
    _expectInteger(unit, 'number', itemPath, context, minimum: 1);
    _expectText(unit, 'title', itemPath, context);
    _expectInteger(unit, 'contentVersion', itemPath, context, minimum: 1);
    _expectText(unit, 'packageStem', itemPath, context);
    final moduleId = _expectIdentifier(unit, 'moduleId', itemPath, context);
    if (moduleId != null && !moduleIds.contains(moduleId)) {
      context.error('$itemPath.moduleId', 'module inconnu : $moduleId');
    }
    if (id != null && moduleId != null && !id.startsWith('$moduleId-')) {
      context.error(itemPath, "$id n'appartient pas au module $moduleId");
    }
    final downloadable = _expectBoolean(
      unit,
      'downloadable',
      itemPath,
      context,
    );
    final packages = unit['packages'];
    if (downloadable == true && packages is! Map<String, Object?>) {
      context.error('$itemPath.packages', 'obligatoire si downloadable=true');
    }
    if (downloadable == false && packages != null) {
      context.error(
        '$itemPath.packages',
        'doit être absent tant que downloadable=false',
      );
    }
    if (packages is Map<String, Object?>) {
      _validatePackages(packages, '$itemPath.packages', context);
    }
  }

  final referencedModules = <String>{
    for (final part in parts) ..._stringList(part['moduleIds']),
  };
  for (final moduleId in moduleIds.difference(referencedModules)) {
    context.error(path, 'module non rattaché à une partie : $moduleId');
  }
  final referencedUnits = <String>{
    for (final module in modules) ..._stringList(module['unitIds']),
  };
  for (final unitId in unitIds.difference(referencedUnits)) {
    context.error(path, 'unité non rattachée à un module : $unitId');
  }
}

void _validatePackages(
  Map<String, Object?> packages,
  String path,
  ValidationContext context,
) {
  if (packages['light'] is! Map<String, Object?>) {
    context.error('$path.light', 'paquet léger obligatoire');
  }
  for (final entry in packages.entries) {
    if (entry.key != 'light' && entry.key != 'completeAddon') {
      context.error(path, 'type de paquet inconnu : ${entry.key}');
      continue;
    }
    if (entry.value is! Map<String, Object?>) continue;
    final package = entry.value! as Map<String, Object?>;
    final packagePath = '$path.${entry.key}';
    final url = _expectText(package, 'url', packagePath, context);
    if (url != null) {
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        context.error('$packagePath.url', 'URL HTTPS invalide');
      }
    }
    _expectInteger(package, 'sizeBytes', packagePath, context, minimum: 1);
    final hash = _expectText(package, 'sha256', packagePath, context);
    if (hash != null && !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      context.error('$packagePath.sha256', 'SHA-256 attendu sur 64 caractères');
    }
  }
}

void _validateUnitFiles(
  Directory root,
  Map<String, Object?> catalog,
  ValidationContext context,
) {
  final summaries = <String, Map<String, Object?>>{};
  for (final unit in _objectList(catalog['units'])) {
    final id = unit['id'];
    if (id is String) summaries[id] = unit;
  }

  final unitsDirectory = Directory(
    '${root.path}${Platform.pathSeparator}source'
    '${Platform.pathSeparator}units',
  );
  if (!unitsDirectory.existsSync()) {
    context.error('source/units', 'dossier introuvable');
    return;
  }

  final files = unitsDirectory
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (file) => file.path.endsWith('${Platform.pathSeparator}unit.json'),
      )
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final relativePath = file.path.substring(root.path.length + 1);
    final unit = _readObject(file, context);
    if (unit == null) continue;
    _validateUnit(unit, relativePath, summaries, context);
  }
}

void _validateUnit(
  Map<String, Object?> unit,
  String path,
  Map<String, Map<String, Object?>> summaries,
  ValidationContext context,
) {
  _expectInteger(unit, 'schemaVersion', path, context, expected: 1);
  final id = _expectIdentifier(unit, 'id', path, context);
  final moduleId = _expectIdentifier(unit, 'moduleId', path, context);
  final number = _expectInteger(unit, 'number', path, context, minimum: 1);
  final title = _expectText(unit, 'title', path, context);
  _expectInteger(unit, 'estimatedMinutes', path, context, minimum: 1);
  final status = _expectText(unit, 'status', path, context);
  if (status != null && !{'draft', 'review', 'published'}.contains(status)) {
    context.error('$path.status', 'valeur inconnue : $status');
  }
  final objectives = _expectStringList(unit, 'objectives', path, context);
  if (objectives.isEmpty) {
    context.error('$path.objectives', 'au moins un objectif est obligatoire');
  }
  final blocks = _expectObjectList(unit, 'blocks', path, context);
  if (blocks.isEmpty) {
    context.error('$path.blocks', 'au moins un bloc est obligatoire');
  }

  if (id != null) {
    final summary = summaries[id];
    if (summary == null) {
      context.error('$path.id', 'unité absente du catalogue : $id');
    } else {
      if (summary['moduleId'] != moduleId) {
        context.error('$path.moduleId', 'diffère du catalogue');
      }
      if (summary['number'] != number) {
        context.error('$path.number', 'diffère du catalogue');
      }
      if (summary['title'] != title) {
        context.error('$path.title', 'diffère du catalogue');
      }
    }
    final folderName = File(
      path,
    ).parent.path.split(Platform.pathSeparator).last;
    if (folderName != id) {
      context.error(path, 'le dossier doit porter le même ID que l\'unité');
    }
  }

  final blockIds = <String>{};
  for (var index = 0; index < blocks.length; index++) {
    final block = blocks[index];
    final blockPath = '$path.blocks[$index]';
    final blockId = _expectBlockIdentifier(block, 'id', blockPath, context);
    if (blockId != null && !blockIds.add(blockId)) {
      context.error('$blockPath.id', 'identifiant de bloc dupliqué : $blockId');
    }
    _validateBlock(block, blockPath, context, publiee: status == 'published',
        dossierUnite: File(path).parent);
  }

  _rejectScoreFields(unit, path, context);
}

/// `image: {path, alt}`.
///
/// `path` reste relatif au dossier de l'unité dans la source : c'est
/// `tool/build_release.dart` qui le réécrit en URL de release immuable. Une
/// URL absolue écrite à la main court-circuiterait cette réécriture et
/// pointerait hors des assets versionnés.
///
/// `alt` est obligatoire. Boubacar, le profil qui s'appuie sur l'audio, ne
/// reçoit rien d'une image sans texte de remplacement.
void _validateImage(
  Map<String, Object?> block,
  String path,
  Directory dossierUnite,
  ValidationContext context,
) {
  final image = block['image'];
  if (image is! Map<String, Object?>) {
    context.error('$path.image', 'objet {path, alt} obligatoire');
    return;
  }
  final chemin = image['path'];
  if (chemin is! String || chemin.trim().isEmpty) {
    context.error('$path.image.path', 'texte non vide obligatoire');
  } else if (chemin.startsWith('http://') || chemin.startsWith('https://')) {
    context.error(
      '$path.image.path',
      'chemin relatif attendu, pas une URL : la release réécrit ce champ',
    );
  } else if (!chemin.startsWith('media/')) {
    context.error(
      '$path.image.path',
      'les fichiers d\'une unité vivent dans media/',
    );
  } else {
    // Une coquille doit se voir maintenant, pas à la publication : le
    // constructeur de release refuse un chemin sans fichier, mais bien plus
    // tard et loin de l'auteur.
    final fichier = File(
      '${dossierUnite.path}${Platform.pathSeparator}'
      '${chemin.replaceAll('/', Platform.pathSeparator)}',
    );
    if (!fichier.existsSync()) {
      context.error('$path.image.path', 'fichier introuvable : $chemin');
    }
  }
  _expectText(image, 'alt', '$path.image', context);
}

void _validateBlock(
  Map<String, Object?> block,
  String path,
  ValidationContext context, {
  required bool publiee,
  required Directory dossierUnite,
}) {
  final kind = _expectText(block, 'kind', path, context);

  // Gel sur ce qui s'affiche. Le schéma décrit plus de types que le lecteur
  // n'en rend ; les autres produisent une page blanche, sans erreur ni trace.
  // Hors release on les laisse passer — un brouillon peut préparer un type
  // pas encore câblé — mais rien d'invisible ne part chez l'apprenant.
  if (context.releaseMode &&
      publiee &&
      kind != null &&
      !context.typesRendus.contains(kind)) {
    context.error(
      '$path.kind',
      'type « $kind » non pris en charge par le lecteur : il s\'afficherait '
          'vide. Voir schema/support-manifest.json.',
    );
  }

  switch (kind) {
    case 'text':
    case 'takeaway':
      _expectText(block, 'body', path, context);
    case 'accordion':
      final items = _expectObjectList(block, 'items', path, context);
      for (var i = 0; i < items.length; i++) {
        _expectText(items[i], 'title', '$path.items[$i]', context);
        _expectText(items[i], 'body', '$path.items[$i]', context);
      }
    // `flashcards` et `tabs` partagent la paire {title, body} de l'accordéon :
    // le lecteur reçoit les trois types dans la même liste `items` de
    // `BlocUnite`, et n'a pas de champ `front` / `back` / `label` où les
    // ranger. Une charge utile sous un autre nom serait perdue au parsing et
    // afficherait un bloc vide.
    case 'flashcards':
      final cartes = _expectObjectList(block, 'items', path, context);
      for (var i = 0; i < cartes.length; i++) {
        _expectText(cartes[i], 'title', '$path.items[$i]', context); // recto
        _expectText(cartes[i], 'body', '$path.items[$i]', context); // verso
      }
    case 'tabs':
      final onglets = _expectObjectList(block, 'items', path, context);
      if (onglets.length < 2) {
        context.error('$path.items', 'au moins deux onglets sont nécessaires');
      }
      // Le lecteur repère l'onglet actif par son libellé, faute de pouvoir
      // comparer un index de liste dans une condition FlutterFlow. Deux
      // onglets homonymes s'ouvriraient donc ensemble.
      final libelles = <String>{};
      for (var i = 0; i < onglets.length; i++) {
        _expectText(onglets[i], 'title', '$path.items[$i]', context);
        _expectText(onglets[i], 'body', '$path.items[$i]', context);
        final libelle = onglets[i]['title'];
        if (libelle is String && !libelles.add(libelle)) {
          context.error(
            '$path.items[$i].title',
            'libellé d\'onglet en double : « $libelle »',
          );
        }
      }
    // Les six types d'affichage. Aucun n'ajoute de champ au-delà de
    // `image` : `label` et `body` portent l'étiquette et l'énoncé d'une idée
    // forte, la citation et son auteur, la légende d'une image.
    case 'statement':
    case 'quote':
      _expectText(block, 'label', path, context);
      _expectText(block, 'body', path, context);
    case 'list':
      _expectText(block, 'title', path, context);
      final points = _expectObjectList(block, 'items', path, context);
      for (var i = 0; i < points.length; i++) {
        _expectText(points[i], 'body', '$path.items[$i]', context);
      }
    case 'image':
      _expectText(block, 'title', path, context);
      _validateImage(block, path, dossierUnite, context);
    case 'process':
      _expectText(block, 'title', path, context);
      final etapes = _expectObjectList(block, 'items', path, context);
      if (etapes.length < 2) {
        context.error('$path.items', 'au moins deux étapes sont nécessaires');
      }
      for (var i = 0; i < etapes.length; i++) {
        _expectText(etapes[i], 'title', '$path.items[$i]', context);
        _expectText(etapes[i], 'body', '$path.items[$i]', context);
      }
    case 'timeline':
      _expectText(block, 'title', path, context);
      final reperes = _expectObjectList(block, 'items', path, context);
      if (reperes.length < 2) {
        context.error('$path.items', 'au moins deux repères sont nécessaires');
      }
      for (var i = 0; i < reperes.length; i++) {
        _expectText(reperes[i], 'label', '$path.items[$i]', context);
        _expectText(reperes[i], 'title', '$path.items[$i]', context);
        _expectText(reperes[i], 'body', '$path.items[$i]', context);
      }
    case 'truefalse':
      _expectText(block, 'statement', path, context);
      _expectBoolean(block, 'answer', path, context);
      _expectText(block, 'feedbackTrue', path, context);
      _expectText(block, 'feedbackFalse', path, context);
    case 'choice':
      _validateChoice(block, path, context);
    case 'cloze':
      _validateCloze(block, path, context);
    case 'exercise':
      _expectText(block, 'title', path, context);
      final items = _expectObjectList(block, 'items', path, context);
      for (var i = 0; i < items.length; i++) {
        _validateExerciseItem(items[i], '$path.items[$i]', context);
      }
    case null:
      return;
    default:
      context.error('$path.kind', 'type de bloc inconnu : $kind');
  }
}

void _validateExerciseItem(
  Map<String, Object?> item,
  String path,
  ValidationContext context,
) {
  _expectBlockIdentifier(item, 'id', path, context);
  final kind = _expectText(item, 'kind', path, context);
  switch (kind) {
    case 'textarea':
      _expectText(item, 'prompt', path, context);
    case 'scale':
      _expectText(item, 'group', path, context);
      final options = _expectStringList(item, 'options', path, context);
      if (options.length < 2) {
        context.error('$path.options', 'au moins deux choix sont nécessaires');
      }
      final questions = _expectObjectList(item, 'questions', path, context);
      for (var i = 0; i < questions.length; i++) {
        _expectBlockIdentifier(
          questions[i],
          'id',
          '$path.questions[$i]',
          context,
        );
        _expectText(questions[i], 'text', '$path.questions[$i]', context);
      }
    case 'choice':
      _validateChoice(item, path, context);
    case 'cloze':
      _validateCloze(item, path, context);
    case 'table':
      final columns = _expectStringList(item, 'columns', path, context);
      if (columns.isEmpty) {
        context.error('$path.columns', 'au moins une colonne est obligatoire');
      }
      _expectBoolean(item, 'addRows', path, context);
      final rows = _expectObjectList(item, 'rows', path, context);
      for (var i = 0; i < rows.length; i++) {
        final cells =
            _expectStringList(rows[i], 'cells', '$path.rows[$i]', context);
        if (columns.isNotEmpty && cells.length != columns.length) {
          context.error(
            '$path.rows[$i].cells',
            'le nombre de cellules doit correspondre aux colonnes',
          );
        }
      }
    case 'journal':
      final moods = _expectStringList(item, 'moods', path, context);
      if (moods.length < 2) {
        context.error('$path.moods', 'au moins deux humeurs sont nécessaires');
      }
      _validateLabeledFields(item, path, context);
    case 'fieldwork':
      _expectText(item, 'title', path, context);
      _expectText(item, 'instructions', path, context);
      _validateLabeledFields(item, path, context);
    case null:
      return;
    default:
      context.error('$path.kind', "type d'exercice inconnu : $kind");
  }
}

void _validateChoice(
  Map<String, Object?> value,
  String path,
  ValidationContext context,
) {
  _expectText(value, 'prompt', path, context);
  final options = _expectObjectList(value, 'options', path, context);
  if (options.length < 2) {
    context.error('$path.options', 'au moins deux choix sont nécessaires');
  }
  final optionIds = <String>{};
  for (var i = 0; i < options.length; i++) {
    final optionPath = '$path.options[$i]';
    final id = _expectBlockIdentifier(options[i], 'id', optionPath, context);
    if (id != null && !optionIds.add(id)) {
      context.error('$optionPath.id', 'identifiant de choix dupliqué : $id');
    }
    _expectText(options[i], 'text', optionPath, context);
    _expectText(options[i], 'feedback', optionPath, context);
  }
  final expected = value['expectedOptionId'];
  if (expected != null &&
      (expected is! String || !optionIds.contains(expected))) {
    context.error(
      '$path.expectedOptionId',
      'doit désigner un choix existant',
    );
  }
}

void _validateCloze(
  Map<String, Object?> value,
  String path,
  ValidationContext context,
) {
  _expectText(value, 'text', path, context);
  final gaps = _expectObjectList(value, 'gaps', path, context);
  if (gaps.isEmpty) {
    context.error('$path.gaps', 'au moins un trou est obligatoire');
  }
  for (var i = 0; i < gaps.length; i++) {
    final gapPath = '$path.gaps[$i]';
    _expectBlockIdentifier(gaps[i], 'id', gapPath, context);
    final answers = _expectStringList(
      gaps[i],
      'acceptedAnswers',
      gapPath,
      context,
    );
    if (answers.isEmpty) {
      context.error(
        '$gapPath.acceptedAnswers',
        'au moins une réponse est obligatoire',
      );
    }
  }
}

void _validateLabeledFields(
  Map<String, Object?> value,
  String path,
  ValidationContext context,
) {
  final fields = _expectObjectList(value, 'fields', path, context);
  if (fields.isEmpty) {
    context.error('$path.fields', 'au moins un champ est obligatoire');
  }
  for (var i = 0; i < fields.length; i++) {
    _expectBlockIdentifier(fields[i], 'id', '$path.fields[$i]', context);
    _expectText(fields[i], 'label', '$path.fields[$i]', context);
  }
}

void _rejectScoreFields(Object? value, String path, ValidationContext context) {
  const forbidden = {
    'score',
    'scored',
    'points',
    'grade',
    'percentage',
    'correctCount',
    'totalScore',
  };
  if (value is Map<String, Object?>) {
    for (final entry in value.entries) {
      if (forbidden.contains(entry.key)) {
        context.error('$path.${entry.key}', 'champ de notation interdit');
      }
      _rejectScoreFields(entry.value, '$path.${entry.key}', context);
    }
  } else if (value is List<Object?>) {
    for (var i = 0; i < value.length; i++) {
      _rejectScoreFields(value[i], '$path[$i]', context);
    }
  }
}

Set<String> _uniqueIds(
  List<Map<String, Object?>> values,
  String path,
  ValidationContext context,
) {
  final ids = <String>{};
  for (var index = 0; index < values.length; index++) {
    final id = values[index]['id'];
    if (id is String && !ids.add(id)) {
      context.error('$path[$index].id', 'identifiant dupliqué : $id');
    }
  }
  return ids;
}

void _checkUniqueValues(
  List<String> values,
  String path,
  ValidationContext context,
) {
  final seen = <String>{};
  for (final value in values) {
    if (!seen.add(value)) context.error(path, 'valeur dupliquée : $value');
  }
}

Map<String, Object?>? _expectObject(
  Map<String, Object?> object,
  String key,
  String path,
  ValidationContext context,
) {
  final value = object[key];
  if (value is Map<String, Object?>) return value;
  context.error('$path.$key', 'objet obligatoire');
  return null;
}

List<Map<String, Object?>> _expectObjectList(
  Map<String, Object?> object,
  String key,
  String path,
  ValidationContext context,
) {
  final value = object[key];
  final result = _objectList(value);
  if (value is! List<Object?>) {
    context.error('$path.$key', 'liste obligatoire');
  }
  return result;
}

List<Map<String, Object?>> _objectList(Object? value) => value is List<Object?>
    ? value.whereType<Map<String, Object?>>().toList()
    : const [];

List<String> _expectStringList(
  Map<String, Object?> object,
  String key,
  String path,
  ValidationContext context,
) {
  final value = object[key];
  if (value is! List<Object?> || value.any((item) => item is! String)) {
    context.error('$path.$key', 'liste de textes obligatoire');
    return const [];
  }
  return value.cast<String>();
}

List<String> _stringList(Object? value) =>
    value is List<Object?> ? value.whereType<String>().toList() : const [];

String? _expectText(
  Map<String, Object?> object,
  String key,
  String path,
  ValidationContext context,
) {
  final value = object[key];
  if (value is String && value.trim().isNotEmpty) return value;
  context.error('$path.$key', 'texte non vide obligatoire');
  return null;
}

String? _expectIdentifier(
  Map<String, Object?> object,
  String key,
  String path,
  ValidationContext context,
) {
  final value = _expectText(object, key, path, context);
  if (value != null && !RegExp(r'^[A-Z0-9]+(?:-[A-Z0-9]+)*$').hasMatch(value)) {
    context.error('$path.$key', 'identifiant invalide : $value');
  }
  return value;
}

String? _expectBlockIdentifier(
  Map<String, Object?> object,
  String key,
  String path,
  ValidationContext context,
) {
  final value = _expectText(object, key, path, context);
  if (value != null && !RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$').hasMatch(value)) {
    context.error('$path.$key', 'identifiant de bloc invalide : $value');
  }
  return value;
}

int? _expectInteger(
  Map<String, Object?> object,
  String key,
  String path,
  ValidationContext context, {
  int? expected,
  int? minimum,
}) {
  final value = object[key];
  if (value is! int) {
    context.error('$path.$key', 'nombre entier obligatoire');
    return null;
  }
  if (expected != null && value != expected) {
    context.error('$path.$key', 'valeur attendue : $expected');
  }
  if (minimum != null && value < minimum) {
    context.error('$path.$key', 'doit être supérieur ou égal à $minimum');
  }
  return value;
}

bool? _expectBoolean(
  Map<String, Object?> object,
  String key,
  String path,
  ValidationContext context,
) {
  final value = object[key];
  if (value is bool) return value;
  context.error('$path.$key', 'booléen obligatoire');
  return null;
}
