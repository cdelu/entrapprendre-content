# Entr'Apprendre — dépôt de contenu

Ce dossier est le futur dépôt GitHub public des contenus téléchargeables de
l'application. Le code FlutterFlow n'y vit pas.

## Principe

- `source/catalog.source.json` décrit les parties, modules et unités.
- `source/units/<ID>/unit.json` contient les blocs pédagogiques d'une unité.
- `schema/` fixe le contrat JSON versionné.
- `tool/validate_content.dart` refuse les contenus incohérents avant publication.
- `dist/` recevra les catalogues et archives générés. Son contenu ne se modifie
  pas à la main.

Les identifiants sont stables. Corriger un titre ne doit jamais changer `M02`,
`M02-U01` ou l'identifiant d'un bloc : la progression locale dépend de ces IDs.

## Validation

Depuis ce dossier :

```bash
dart run tool/validate_content.dart
```

Le mode de préparation d'une publication refusera les unités encore en
brouillon :

```bash
dart run tool/validate_content.dart --release
```

## Publication prévue

Le dépôt gardera les JSON éditables. Les archives contenant JSON, audio, images
et vidéos seront publiées comme assets d'une GitHub Release. Une nouvelle
correction crée une nouvelle version ; une archive publiée n'est jamais écrasée.

Le futur outil de publication générera :

- `<UNIT_ID>-core.zip` : JSON, audio et médias légers ;
- `<UNIT_ID>-media.zip` : supplément images/vidéos de la version complète ;
- `catalog.json` : URLs, tailles, versions et sommes SHA-256.

## État actuel

Le catalogue v1 contient les 37 titres du manuel. `M02-U01` est un brouillon
technique destiné à éprouver le schéma ; ce n'est pas encore la transcription
éditoriale complète de l'unité.
