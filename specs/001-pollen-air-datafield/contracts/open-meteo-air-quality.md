# Contrat : Consommation de l'API Open-Meteo Air Quality

**Feature**: `001-pollen-air-datafield` | **Date** : 2026-08-04

Ce contrat documente comment la fonctionnalité consomme le service externe Open-Meteo Air
Quality (cf. research.md §4). Il ne redéfinit pas l'API elle-même (propriété d'Open-Meteo), mais
fixe le sous-ensemble utilisé et les garanties attendues côté application.

## Requête sortante

- **Méthode** : `GET`
- **URL de base** : `https://air-quality-api.open-meteo.com/v1/air-quality`
- **Paramètres requis** :
  - `latitude`, `longitude` : issus de la Position Géographique courante (data-model.md)
  - `hourly` : `european_aqi,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen`
  - `timezone` : `auto` (pour aligner l'horodatage retourné sur la position interrogée, cf.
    exigence « à l'heure et à l'endroit exacte » de la description de la fonctionnalité)
- **Authentification** : aucune (usage non commercial, cf. research.md §4 et §8)
- **Transport** : HTTPS obligatoire (Principe II de la constitution)
- **Déclenchement** : uniquement depuis le Background Service (research.md §3), jamais depuis le
  cycle de rendu du champ de données. Ce client (barrel `EnvironmentalCore`) est exécuté
  indépendamment par chacune des deux applications (`air-quality-field`, `pollen-field`,
  research.md §9) ; chacune interroge l'intégralité des paramètres `hourly` ci-dessous mais
  n'exploite que le sous-ensemble de la réponse qui la concerne.

## Réponse attendue (sous-ensemble utilisé)

| Champ JSON source | Utilisation applicative |
|---|---|
| `hourly.time[]` | Sélection de l'entrée horaire la plus proche de l'horodatage courant |
| `hourly.european_aqi[]` | → `Relevé Environnemental.indice_qualite_air` |
| `hourly.alder_pollen[]`, `birch_pollen[]`, `grass_pollen[]`, `mugwort_pollen[]`, `olive_pollen[]`, `ragweed_pollen[]` | → `Relevé Environnemental.scores_pollen_par_type` (un Type de Pollen par variable) |

Toute valeur `null` renvoyée par l'API pour un type de pollen (hors couverture géographique ou
hors saison, cf. research.md §4) DOIT être traitée comme « absente » pour ce type précis
(data-model.md, Type de Pollen), sans invalider l'ensemble du relevé.

## Calcul dérivé applicatif

- **score_pollen_global** (FR-002) : agrégation applicative des scores par type disponibles
  (ex. valeur maximale des types renseignés). La formule exacte d'agrégation est un détail
  d'implémentation à définir lors de `/speckit-tasks`, mais DOIT satisfaire l'invariant de
  cohérence défini dans data-model.md.

## Conditions d'échec → état `INDISPONIBLE`

Le relevé passe à l'état `INDISPONIBLE` (FR-005) si l'une des conditions suivantes survient :

1. `makeWebRequest()` retourne un code d'erreur réseau (pas de connectivité téléphone, timeout).
2. La réponse HTTP a un statut différent de `200`.
3. Le corps de la réponse n'est pas un JSON valide ou ne contient pas la structure `hourly`
   attendue.
4. Aucune entrée horaire correspondant à l'heure courante n'est trouvée dans `hourly.time[]`.

Dans tous les cas, l'application NE DOIT PAS afficher de valeur numérique partielle ou
potentiellement incohérente : soit le relevé est complet et valide, soit il est marqué
`INDISPONIBLE` dans son ensemble pour les valeurs concernées.

## Fréquence d'appel

Au maximum un appel toutes les 15 minutes par position significativement différente (FR-003,
SC-002), déclenché par le Background Service — jamais à la demande de l'utilisateur, conformément
à User Story 3.
