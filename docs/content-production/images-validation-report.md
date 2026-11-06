# Illustrations des 37 unités — validation et approbation

Date : 6 novembre 2026. Branche : `content/images-v1`.
Base vérifiée : `58fce8292fd60b395ea11f0a0f8f035d5aba6810`. Dernière publication stable : `content-v0.5.0`, catalogue 2 ; miroir vérifié contre le SHA-256 de l’asset de release.

## Résultat

- 62 blocs image dans 37 unités : 61 images générées et 1 diagramme fourni.
- 8 fiches personnages dans `docs/content-production/images/characters/`, exclues des paquets unités.
- Catalogue 2 → 3 ; `contentVersion` augmenté de 1 pour chacune des 37 unités. Aucun autre champ du catalogue modifié.
- 3 912 002 octets (3,73 MiB) de WebP pour le cours ; poids par unité : 14 948 à 245 284 octets.
- 84 générations au total, dont 64 des 65 appels supplémentaires autorisés ; outil OpenAI intégré `image_gen.imagegen`, famille `gpt-image` selon C2PA, version exacte non exposée.
- Identifiants, ordre, texte et mise en forme des blocs existants préservés ; titres, légendes et alternatives du manifeste reproduits exactement.
- Chaque fichier image est référencé exactement une fois ; aucun média orphelin. Les octets copiés correspondent aux images approuvées.
- Originaux et page HTML de relecture conservés hors du dépôt ; `dist/` inchangé.

## Approbations

STOP 1 : Carlo a approuvé le style, les personnages et le plafond du lot. STOP 2 : « continue all approved », le 6 novembre 2026.
Aucune image ne reste `needs_review` après cette approbation. Les deux réserves présentées ont été acceptées :

- `m04u04-attelage` : meilleure version après quatre tentatives ; disposition du harnais acceptée par Carlo.
- `m05u02-neuf-points-solution` : diagramme fourni conservé à l’identique, avec les numéros 1–4 et ses dimensions 1200 × 900.
- Les variations de ton du style pilote ont également été approuvées. Les 61 images générées font 1080 × 810 et ne contiennent aucun texte lisible observé pendant la relecture.
- Six fichiers dépassent la cible de 80 KiB à la qualité minimale 55 ; le plus lourd fait 99 474 octets, sous la limite stricte de 120 KiB.

## Contrôles requis

| Commande | Résultat |
| --- | --- |
| `dart pub get --enforce-lockfile` | Réussi (code 0) |
| `dart format --output=none --set-exit-if-changed .` | Réussi (code 0) |
| `dart analyze` | Réussi (code 0) |
| `dart run tool/validate_content.dart` | Réussi (code 0) |
| `dart run tool/validate_content.dart --release` | Réussi (code 0) |
| `dart run tool/smoke_audio_delivery.dart` | Réussi (code 0) |
| `python tool/content_production/audit_content.py --require-all` | Réussi (code 0) |

Le contrôle de formatage a examiné 4 fichiers sans changement ; l’analyse Dart ne signale aucun problème.
L’audit Python utilise `jsonschema` dans un environnement local de validation et conclut : 37 unités, 0 erreur, 0 avertissement.
Le smoke test a validé le catalogue, les archives et les assets directs image/audio dans une copie temporaire, sans sortie dans le `dist/` du dépôt.
Un contrôle supplémentaire compare chaque unité à la base Git : seuls les 62 blocs attendus sont ajoutés, immédiatement après leurs ancres et dans l’ordre du manifeste.

## Poids des images par unité

| Unité | Images | Octets | KiB |
| --- | ---: | ---: | ---: |
| M01-U01 | 2 | 162752 | 158.9 |
| M01-U02 | 1 | 76554 | 74.8 |
| M01-U03 | 1 | 60104 | 58.7 |
| M01-U04 | 1 | 87616 | 85.6 |
| M01-U05 | 3 | 171540 | 167.5 |
| M02-U01 | 1 | 26324 | 25.7 |
| M02-U02 | 1 | 76332 | 74.5 |
| M02-U03 | 2 | 110990 | 108.4 |
| M03-U01 | 3 | 179940 | 175.7 |
| M03-U02 | 1 | 56212 | 54.9 |
| M03-U03 | 2 | 152808 | 149.2 |
| M03-U04 | 1 | 68054 | 66.5 |
| M04-U01 | 1 | 68654 | 67.0 |
| M04-U02 | 2 | 138944 | 135.7 |
| M04-U03 | 1 | 79318 | 77.5 |
| M04-U04 | 2 | 130666 | 127.6 |
| M05-U01 | 3 | 211896 | 206.9 |
| M05-U02 | 2 | 92520 | 90.4 |
| M05-U03 | 3 | 245284 | 239.5 |
| M05-U04 | 1 | 78476 | 76.6 |
| M05-U05 | 2 | 157840 | 154.1 |
| M05-U06 | 1 | 60894 | 59.5 |
| M06-U01 | 1 | 52898 | 51.7 |
| M06-U02 | 1 | 68272 | 66.7 |
| M06-U03 | 1 | 88210 | 86.1 |
| M06-U04 | 2 | 144176 | 140.8 |
| M06-U05 | 2 | 109810 | 107.2 |
| M06-U06 | 3 | 165448 | 161.6 |
| M06-U07 | 2 | 133888 | 130.8 |
| M06-U08 | 2 | 101000 | 98.6 |
| M06-U09 | 2 | 116694 | 114.0 |
| M07-U01 | 2 | 76768 | 75.0 |
| M07-U02 | 1 | 57360 | 56.0 |
| M07-U03 | 1 | 31522 | 30.8 |
| M07-U04 | 2 | 122824 | 119.9 |
| M07-U05 | 1 | 14948 | 14.6 |
| M07-U06 | 2 | 134466 | 131.3 |

Les IDs et les métadonnées complets sont dans [le manifeste](images/manifest.json). La provenance, les conditions de publication et la date de relecture de chaque fichier sont dans [le registre des droits](media-and-rights.md).
