# Modèle de Données (Phase 1) : Champ de Données Environnementales Garmin

**Feature**: `001-pollen-air-datafield` | **Date** : 2026-08-04

Ce document décrit les entités logiques manipulées par la fonctionnalité, dérivées de la section
« Key Entities » de `spec.md`. Il reste indépendant de toute implémentation Monkey C précise ;
les structures de code correspondantes seront produites lors de `/speckit-tasks` et de
l'implémentation.

## Position Géographique

Représente les coordonnées de l'utilisateur à un instant donné, utilisées comme entrée pour
interroger la source de données externe.

| Champ | Type | Règle de validation |
|---|---|---|
| latitude | nombre décimal | Doit être comprise entre -90 et 90 ; absente tant que le GPS n'a pas acquis de position (cf. Edge Case) |
| longitude | nombre décimal | Doit être comprise entre -180 et 180 ; absente tant que le GPS n'a pas acquis de position |
| horodatage | date/heure | Doit correspondre à l'instant de la mesure GPS, jamais dans le futur |

**Relations** : une Position Géographique est associée à exactement un Relevé Environnemental
au moment de son acquisition.

## Relevé Environnemental

Ensemble de valeurs associé à une position géographique et à un horodatage précis, avec un état
de disponibilité. C'est l'entité centrale mise en cache localement et lue par les deux champs de
données.

| Champ | Type | Règle de validation |
|---|---|---|
| position | Position Géographique | Doit être présente pour tout relevé à l'état « à jour » |
| horodatage_releve | date/heure | Horodatage de la réponse de la source externe |
| indice_qualite_air | entier ou absent | Valeur de l'European AQI ; absent si état = indisponible |
| score_pollen_global | entier ou absent | Agrégation des scores par type de pollen (FR-002) ; absent si état = indisponible |
| scores_pollen_par_type | liste de (Type de Pollen, score) | Peut être vide si aucune donnée pour la zone/saison (Edge Case), sans que cela ne rende le relevé invalide |
| etat | énumération : `A_JOUR` \| `INDISPONIBLE` | `INDISPONIBLE` dès que les données ne peuvent pas être actualisées (FR-005) ; jamais d'état intermédiaire « obsolète » affiché |

**Transitions d'état** :
- `A_JOUR` → `INDISPONIBLE` : lorsque l'actualisation périodique échoue (perte de connectivité,
  erreur de la source externe, absence de donnée pour la zone/saison).
- `INDISPONIBLE` → `A_JOUR` : dès qu'une actualisation réussit (connectivité rétablie — User
  Story 3, scénario 2).
- Aucune transition automatique vers un état « obsolète » intermédiaire : conformément à FR-005,
  le passage à `INDISPONIBLE` est immédiat dès l'échec confirmé de l'actualisation.

**Relations** : un Relevé Environnemental référence zéro, une ou plusieurs entrées de Type de
Pollen (via `scores_pollen_par_type`) et provient d'exactement une Source de Données Externe.

## Type de Pollen

Catégorie de pollen suivie, possédant son propre score dans le relevé environnemental.

| Champ | Type | Règle de validation |
|---|---|---|
| identifiant | énumération : aulne, bouleau, graminées, armoise, olivier, ambroisie | Limité aux types fournis par la source de données externe (cf. research.md §4) |
| score | entier ou absent | Absent si la source externe ne fournit pas de valeur pour ce type à cette position/saison |

**Relations** : appartient à un Relevé Environnemental ; n'existe pas indépendamment de celui-ci.

## Source de Données Externe

Service tiers fournissant les données de qualité de l'air et de pollens en fonction d'une
position géographique et d'un horodatage.

| Champ | Type | Règle de validation |
|---|---|---|
| identifiant | chaîne (constante) | `open-meteo-air-quality` pour la première version (research.md §4) |
| url_base | chaîne (URL HTTPS) | Doit être en HTTPS (Principe II de la constitution) |
| derniere_interrogation | date/heure ou absent | Utilisée pour respecter l'intervalle minimal d'actualisation (FR-003) |

**Relations** : produit zéro ou plusieurs Relevés Environnementaux au fil du temps ; une seule
Source de Données Externe est active à la fois dans cette version de la fonctionnalité.

## Résumé des invariants transverses

- Un Relevé Environnemental à l'état `A_JOUR` DOIT toujours avoir une Position Géographique et
  un `indice_qualite_air` et/ou un `score_pollen_global` renseignés (au moins une des deux
  valeurs, cf. FR-001/FR-002).
- Un Relevé Environnemental à l'état `INDISPONIBLE` NE DOIT PAS être présenté à l'utilisateur
  comme une valeur numérique fiable (FR-005, SC-005).
- Le score global de pollen (FR-002) est dérivé des scores par type (FR-002a) ; les deux valeurs
  DOIVENT rester cohérentes entre elles au sein d'un même Relevé Environnemental.
