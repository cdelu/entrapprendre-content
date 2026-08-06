# Contrat de publication GitHub

## Décisions acquises

- Le dépôt de contenu destiné à l'application doit être public.
- Les JSON sources restent versionnés dans Git.
- Les archives téléchargées par les apprenants sont des assets de GitHub
  Releases, pas des fichiers ordinaires du dépôt et pas des objets Git LFS.
- Une version publiée est immuable. Toute correction crée un nouveau tag.
- Le catalogue livré à l'application contient des URLs HTTPS exactes, la taille
  en octets et la somme SHA-256 de chaque archive.

## Informations encore nécessaires

Avant la première publication, définir :

- propriétaire GitHub : `OWNER` ;
- nom du dépôt public : `REPOSITORY` ;
- URL du petit catalogue courant ;
- premier tag, recommandé : `content-v0.1.0`.

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
https://github.com/OWNER/REPOSITORY/releases/download/content-v0.1.0/M02-U01-core-v1.zip
```

Le script de publication remplacera les métadonnées de travail
`downloadable: false` par les descripteurs de paquet complets uniquement après
création, mesure et hachage réussis des archives.

## Barrière de publication

La publication doit exécuter dans cet ordre :

1. `dart run tool/validate_content.dart --release` ;
2. construction des archives dans un répertoire temporaire ;
3. validation des JSON inclus ;
4. calcul des tailles et SHA-256 ;
5. génération de `dist/catalog.json` ;
6. création de la GitHub Release ;
7. envoi des assets ;
8. publication atomique du nouveau catalogue courant.

Une étape en échec ne doit jamais modifier le catalogue courant.
