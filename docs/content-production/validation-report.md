# Rapport de validation — contenus complets (catalogue 2)

Date : 21 octobre 2026. Branche locale `content/manuel-complet`, partie de `origin/main` (c62beae).
Source : *Manuel de l'Apprenant v2* (20 octobre) et, pour les corrigés et chiffres de référence,
annexes 1, 3 et 4 du *Manuel du Formateur v2*.

## Ce qui a été vérifié

| Vérification | Résultat |
| --- | --- |
| `tool/content_production/audit_content.py --require-all` (schéma JSON 2020-12, en-têtes = catalogue, types autorisés, ids uniques, fin d'unité, pas de note, pas d'id interne visible, médias) | 37 unités, 0 erreur, 0 avertissement |
| Catalogue contre `schema/catalog.schema.json` | conforme |
| Relecture complète par un second relecteur (cohérence entre unités, renvois, langue, ton, absence de notation) | corrections appliquées (voir plus bas) |
| Calculs (Fatoumata, cinq histoires du risque, durées de Ramatou, coût de revient, prix, argent de départ, seuil, trois mois, présentation) | recalculés, justes |
| Renvois entre unités | 36 renvois par titre, tous vers un titre existant ; aucun renvoi par numéro |

## Pas encore vérifié (à faire avant toute publication)

- `dart run tool/validate_content.dart` et `--release`, `dart format`, `dart analyze`,
  `smoke_audio_delivery.dart` : Dart n'est pas disponible dans l'espace de travail ;
  ils tourneront dans le workflow GitHub de publication (ou sur le poste de Carlo).
- Construction d'une version (`build_release.dart`) : non lancée.
- Aller-retour dans Studio (import → export sans perte) : à faire par Carlo.
- Test sur téléphone hors ligne (build Android) : à faire par Carlo.
- Relecture pédagogique par Carlo : en cours. Les 37 unités sont passées au statut `published`
  le 23 octobre, à la demande de Carlo, pour pouvoir les tester dans l'application via une préversion
  (prerelease). Les corrections issues de sa relecture feront l'objet d'une nouvelle version.

## Versions

- `catalogVersion` 1 → 2 (la version publiée stable a `catalogVersion` 1).
- `contentVersion` : M02-U01 3 → 4, M02-U02 1 → 2, M02-U03 1 → 2 (déjà publiées) ; les autres unités à 1.
- `hasAudio` retiré des résumés (dérivé par le builder) ; `estimatedMinutes` repris des unités.
- Titres des parties : « Devenir entreprenant », « Construire mon projet » (casse).

## Affirmations juridiques et administratives (M06-U09, M06-U01)

Vérifiées sur des sources publiques, sans montant, délai ni seuil chiffré dans le contenu :

- Le guichet unique pour les formalités de création est le Centre de Formalités des Entreprises (CFE),
  rattaché à la Maison de l'Entreprise, au sein de la Chambre de Commerce et d'Industrie du Niger (CCIN)
  — catalogue des services d'appui aux entreprises de la Délégation de l'UE au Niger (2021) ;
  guide Africarrières Niger. Le manuel écrit « Chambre de Commerce, d'Industrie et d'Artisanat du Niger » :
  l'application utilise le nom CCIN ; **corriger aussi le manuel et la fiche pays du guide**.
- Statut d'entreprenant (OHADA) : personne physique, activité civile, commerciale, artisanale ou agricole,
  déclaration au RCCM, tenue d'un livre des recettes et dépenses, plafond de chiffre d'affaires fixé par
  chaque État (ohada.com, journée de Niamey, 2016). La mise en œuvre au Niger est à confirmer auprès du CFE ;
  le contenu invite à se renseigner.
- Restent à confirmer localement : interdiction du travail des enfants en âge scolaire (M06-U08),
  « caution de plusieurs mois de loyer » (M06-U06), patente selon la commune (M06-U09).

## Écarts avec le manuel, à trancher par Carlo

1. **Saliou (M03-U04)** : emprunte 50 000 FCFA mais rembourse 15 000 × 4 = 60 000 dans le manuel.
   L'application dit 12 500 × 4 = 50 000. Garder, ou revenir à 15 000 en expliquant les intérêts.
2. **Argent de départ de Ramatou, version allégée (M07-U03)** : 20 000 FCFA de frais pour 2 mois et
   60 000 FCFA pour vivre sur 2 mois ne correspondent pas aux frais mensuels (18 800, dont 3 800 de
   remplacement) ni aux 60 000 FCFA par mois voulus. Montants du manuel conservés, non expliqués.
   La version complète est maintenant expliquée (15 000 FCFA de frais par mois sans le remplacement).
3. **Remplacement du matériel (M07-U01)** : 40 000 ÷ 4 ÷ 12 = 833 FCFA, arrondi à 800 dans le manuel ;
   conservé avec la mention « environ 800 ».
4. **Financement de Ramatou** : le manuel dit « avec ses économies » (Partie II, module 1) ; l'annexe 3 dit
   100 000 FCFA d'économies + 60 000 FCFA prêtés par la famille sans mensualité. L'application suit l'annexe 3.
5. **Ventes de Ramatou** : téléphone puis dépôt en boutique, échelonnés dans l'application ; porte-clés offert
   « avec un portefeuille » (le manuel dit « avec un sac »).
6. **Capacité de 40 articles par mois** : utilisée dans le module des chiffres mais absente de l'unité
   « Comment j'organise mon travail » du manuel ; ajoutée dans l'application (source : annexe 3).
7. **Renvoi erroné** « l'unité 10 » (Partie II, module 3, unité 4) : remplacé par le titre de l'unité.
8. **Réponses des cartes** : les versos des questions du jury (M07-U06) sont rédigés à partir des unités ;
   les corrigés vrai/faux viennent de l'annexe 1 du guide.
9. **« Et maintenant ? »** : intégré à la fin de M07-U06 (pas de nouvelle unité).
10. Coquilles du manuel corrigées dans l'application (« Meances », « deviner », « ne se ressemblent pas »,
    « à la date promise », « Qu'est-ce qu'une entreprise verte ? », etc.) : à reporter dans le manuel.

## Sources

- https://eeas.europa.eu/sites/default/files/catalogue_de_services_dappui_aux_entreprises_version_15dec_2021_0.pdf
- https://africarrieres.com/niger/fr/guide/employeur-entreprise/creer-entreprise
- https://www.ohada.com/actualite/3265/compte-rendu-journee-de-sensibilisation-dinformation-et-de-promotion-du-droit-ohada-tenue-a-niamey-le-19-novembre-2016-sur-le-theme-lentreprenant-ohada.html?langue=fr
