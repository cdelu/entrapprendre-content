# Contrat de publication GitHub

## Décisions acquises

- Le dépôt de contenu destiné à l'application doit être public.
- Les JSON sources restent versionnés dans Git.
- Les archives téléchargées par les apprenants sont des assets de GitHub
  Releases, pas des fichiers ordinaires du dépôt et pas des objets Git LFS.
- Une version publiée est immuable. Toute correction crée un nouveau tag.
- Le catalogue livré à l'application contient des URLs HTTPS exactes, la taille
  en octets et la somme SHA-256 de chaque archive.

## Dépôt et catalogue courant

- propriétaire GitHub : `cdelu` ;
- dépôt public : `entrapprendre-content` ;
- premier tag recommandé : `content-v0.1.0` ;
- URL stable du catalogue courant :
  `https://github.com/cdelu/entrapprendre-content/releases/latest/download/catalog.json`.

## Nommage des assets

Pour l'unité `M02-U01` :

```text
M02-U01-core-v1.zip
M02-U01-media-v1.zip
```

Le paquet `core` contient le JSON, l'audio, les transcriptions et les médias
légers. Le paquet `media` est un supplément facultatif pour la version complète.

## URL finale attendue

```text
https://github.com/cdelu/entrapprendre-content/releases/download/content-v0.1.0/M02-U01-core-v1.zip
```

Le script de publication remplacera les métadonnées de travail
`downloadable: false` par les descripteurs de paquet complets uniquement après
création, mesure et hachage réussis des archives.

## Construction locale

Le générateur ne modifie jamais les sources. Il crée un dossier propre à chaque
tag sous `dist/` et refuse de remplacer une sortie existante :

```bash
dart run tool/build_release.dart --tag content-v0.1.0
```

Une unité n'est ajoutée aux téléchargements que si son `unit.json` porte
`status: published`. Les unités `draft` ou `review` restent dans le catalogue,
avec `downloadable: false`. Son paquet léger contient `unit.json` et tous les
autres fichiers du dossier de l'unité, sauf le sous-dossier `media/`. Si
`media/` contient des fichiers, ceux-ci forment le paquet complet facultatif.

## Publication automatisée

Le workflow GitHub Actions `Publish content release` se lance manuellement. Il
demande un tag et permet de choisir une prérelease. Une prérelease ne remplace
pas le catalogue stable résolu par l'URL `releases/latest/download/catalog.json`.
Le workflow valide et construit de nouveau tous les fichiers sur GitHub avant de
créer la release ; aucun fichier de `dist/` n'est versionné dans Git.

## Barrière de publication

La publication doit exécuter dans cet ordre :

1. `dart run tool/validate_content.dart --release` (les brouillons valides sont
   autorisés mais exclus des téléchargements) ;
2. construction des archives dans un répertoire temporaire ;
3. validation des JSON inclus ;
4. calcul des tailles et SHA-256 ;
5. génération de `dist/catalog.json` ;
6. création de la GitHub Release ;
7. envoi des assets ;
8. publication atomique du nouveau catalogue courant.

Une étape en échec ne doit jamais modifier le catalogue courant.
