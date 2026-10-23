# Médias et droits — première version complète (catalogue 2)

## Décisions (21 octobre 2026)

- Première version **texte seul** : aucune piste audio, aucune image dans les 37 unités.
- Le texte adapté du *Manuel de l'Apprenant v2* peut être publié dans ce dépôt public
  (accord de Carlo). Le fichier DOCX original n'est pas versé dans le dépôt.
- L'ancien MP3 d'exemple (`M02-U01/media/file_example_MP3_700KB.mp3`) et l'image
  d'exemple (`M02-U03/media/atelier.jpg`) sont retirés : ce n'étaient pas des contenus réels.

## Audio à produire

- Scripts de narration en français, un fichier par unité, un enregistrement par bloc :
  `docs/content-production/narration/<UNITÉ>-fr.md` (générés depuis les `unit.json` ;
  à régénérer après chaque modification de texte).
- Textes à traduire en haoussa (`ha`) et en zarma (`dje`) :
  `docs/content-production/traduction/textes_a_traduire.csv` (≈ 3 100 segments, ≈ 46 000 mots,
  colonnes vides pour les deux langues). Traduction et prononciation à faire relire par
  des personnes qualifiées ; aucune traduction automatique ne doit être présentée comme vérifiée.
- Format attendu : MP3 mono 32–48 kbit/s, 30–60 s par bloc, `media/<bloc>-<langue>.mp3`,
  déclaré dans `audio.tracks` du bloc concerné, uniquement quand l'enregistrement existe.
- Les élèves qui dépendent de l'audio (profil Boubacar) ne sont pas encore servis :
  cette version n'est **pas complète** pour eux.

## Images

- Aucune image reprise du manuel (droits non confirmés). Idées d'images utiles notées
  dans la matrice : portrait de l'entrepreneur (M02-U01), règle des 3R (M01-U05),
  solution des neuf points (M05-U02). Toute information importante est déjà dans le texte.

## Organisations réelles nommées dans le contenu

CMCAN, AIPCP, Zamany, Jagga, Le Concret, tannerie de Gamkalé (M01-U04, M06-U04),
CFE / Maison de l'Entreprise / Chambre de Commerce et d'Industrie du Niger (M06-U09).
Repris du manuel, sans ajout. Publication autorisée par Carlo avec le texte du manuel ;
le centre peut demander un retrait.
