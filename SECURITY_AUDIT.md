# Audit de sécurité

**Date** : 2026-08-05
**Périmètre** : l'intégralité du dépôt à l'état du commit `2bd4143` + renommage AeroPollen —
code Monkey C (`barrel/AeroPollenCore`, `aeropollen-air-quality-field`,
`aeropollen-pollen-field`), scripts Shell (`.specify/scripts/bash/`), manifestes Connect IQ,
gestion de la clé de signature, configuration Git.
**Méthode** : revue manuelle ligne à ligne du code applicatif, `grep`/`shellcheck` ciblés sur
les scripts, vérification de l'historique Git pour la clé de signature. Pas d'outillage SAST
automatisé à cette date (voir §CI plus bas — en cours de mise en place).

## Résumé

Aucune vulnérabilité exploitable identifiée. Le code applicatif suit déjà, de façon
systématique, les principes de sécurité définis dans
[`.specify/memory/constitution.md`](.specify/memory/constitution.md) (Principe II). Les points
ci-dessous sont soit des confirmations (✅), soit des observations mineures sans impact direct
(⚠️), soit des recommandations de posture pour la suite (💡).

## Communication réseau

- ✅ **HTTPS systématique** : `OpenMeteoAirQualityClient.BASE_URL` utilise exclusivement
  `https://air-quality-api.open-meteo.com/...` (`barrel/AeroPollenCore/source/OpenMeteoAirQualityClient.mc:14`).
  Aucun appel HTTP en clair identifié dans le code.
- ✅ **Aucune clé d'API ni secret transmis** : l'API Open-Meteo utilisée est publique et
  gratuite, aucun en-tête d'authentification n'est construit ni stocké.
- ✅ **Validation défensive de la réponse externe** : `parseResponse()`
  (`OpenMeteoAirQualityClient.mc:65-111`) vérifie le type de chaque champ (`instanceof
  Dictionary/Array/String/Number`) avant utilisation, à chaque niveau de la structure JSON
  reçue. Une réponse malformée, tronquée ou inattendue de l'API externe produit un relevé
  `INDISPONIBLE`, jamais un plantage ni un comportement indéfini — le code traite la réponse
  réseau comme une entrée non fiable, conformément à l'OWASP (validation aux frontières du
  système).
- ✅ **Aucune exception non gérée exposée à l'appelant** : `fetch()`/`onResponse()` sont
  documentées et implémentées pour ne jamais lever d'exception (commentaire FR-009), toute
  erreur se traduisant par un état `INDISPONIBLE` explicite plutôt qu'un crash ou une ancienne
  valeur silencieusement réutilisée.

## Position GPS et données personnelles

- ✅ **Minimisation** : la position GPS n'est utilisée que pour construire la requête vers
  Open-Meteo (`EnvironmentalBackgroundDelegate.onTemporalEvent()`) et n'est persistée que
  localement sur l'appareil, dans le cache applicatif propre à chaque application
  (`Application.Storage`, isolé par application — `EnvironmentalReadingStore.mc`).
- ✅ **Aucune télémétrie/analytics** : aucun SDK tiers, aucun appel réseau en dehors d'Open-Meteo
  n'a été identifié dans le code applicatif.
- ✅ **Aucun journal de données sensibles** : recherche de `System.println`/`Log.` dans les
  sources applicatives — aucune occurrence. Les coordonnées GPS ne sont jamais écrites en clair
  dans une sortie de log.
- 💡 **Recommandation (transparence, pas une faille)** : pour un projet destiné à être ouvert
  publiquement, documenter explicitement dans le README que la position GPS de l'utilisateur
  est transmise à Open-Meteo (tiers) à chaque rafraîchissement en arrière-plan — fait (voir
  section « Confidentialité » du README).

## Gestion de la clé de signature développeur

- ✅ **Jamais committée** : `git log --all -- developer_key.der` ne retourne aucun résultat ; le
  fichier n'a jamais été suivi par Git, sur aucune branche, dans aucun commit — vérifié
  directement dans l'historique, pas seulement dans l'état courant.
- ✅ **`.gitignore` correct dès l'origine** : `developer_key.der` et `developer_key.pem` sont
  exclus explicitement, avec un commentaire rappelant de ne jamais les partager.
- 💡 **Recommandation** : si ce dépôt est un jour rendu public, régénérer la clé par précaution
  avant publication (même en l'absence de toute fuite constatée), et documenter la procédure de
  génération dans le README (fait).

## Permissions Connect IQ (principe de moindre privilège)

- ✅ Les trois manifestes (`aeropollen-air-quality-field`, `aeropollen-pollen-field`,
  `barrel/AeroPollenCore`) ne déclarent que `Communications`, `Background` et `Positioning` —
  les trois strictement nécessaires à la fonctionnalité (appel réseau, rafraîchissement en
  arrière-plan, géolocalisation). Aucune permission superflue (pas d'accès aux contacts, au
  téléphone, aux capteurs physiologiques, etc.).

## Scripts Shell (`.specify/scripts/bash/`)

Ces scripts sont l'outillage Spec-Driven Development (speckit), pas le code applicatif livré
sur l'appareil, mais font partie de la surface exécutable du dépôt.

- ⚠️ **Usage d'`eval`** dans `check-prerequisites.sh:89`, `setup-plan.sh:32`,
  `setup-tasks.sh:27`, sur une variable `_paths_output` construite par
  `common.sh::get_feature_paths()`. **Revu et jugé sûr** : chaque valeur interpolée est passée
  par `printf '%q'` avant d'être assignée (`common.sh:216-227`), ce qui neutralise l'injection
  shell y compris via un nom de branche Git ou un chemin contenant des caractères spéciaux — le
  code source documente lui-même cette intention (« Use printf '%q' to safely quote values,
  preventing shell injection via crafted branch names or paths »). Aucune modification
  nécessaire.
- ✅ `shellcheck -S warning` sur l'ensemble des scripts : uniquement des avertissements de style
  mineurs (SC2155, SC2120, SC2221/2222 — masquage de valeur de retour, motif de `case`
  redondant), aucun avertissement de sécurité (injection, expansion non quotée dangereuse,
  etc.).

## Secrets committés

- ✅ Recherche de motifs `api[_-]?key|secret|password|token|BEGIN (RSA|EC|PRIVATE) KEY|AKIA...`
  sur l'ensemble des fichiers suivis par Git (`git ls-files`) : toutes les occurrences sont des
  mentions en prose dans la documentation (constitution, spec, recherche) expliquant l'absence
  volontaire de secret dans le projet — aucun secret réel trouvé.

## Dépendances

- ✅ Le projet n'a **aucune dépendance tierce** au sens gestionnaire de paquets — Monkey C/Connect
  IQ ne dispose pas d'écosystème de paquets tiers pour ce type de projet ; le seul « fournisseur
  externe » est l'API Open-Meteo elle-même (service HTTP, pas une dépendance de code). Le
  principe III de la constitution (dépendances récentes/stables) s'applique donc principalement
  à la version du SDK Connect IQ (9.2.0, vérifiée comme la plus récente au moment de
  l'implémentation — voir `research.md` §1).

## Intégration continue (CI)

Voir [`.github/workflows/security.yml`](.github/workflows/security.yml) : détection de secrets
(`gitleaks`), `shellcheck` sur les scripts, validation XML des manifestes Connect IQ, à chaque
Pull Request. **Limite assumée** : le SDK Connect IQ est propriétaire et nécessite une connexion
à un compte Garmin via une interface graphique (SDK Manager) — il n'est pas installable dans un
environnement CI sans compte de service dédié (hors périmètre de ce projet personnel). La
compilation n'est donc **pas** vérifiée automatiquement en CI, uniquement en local (voir
[`README.md`](README.md#compilation)) ; c'est une limite connue, pas un oubli.

## Constat global

Aucun correctif requis suite à cet audit. Les recommandations 💡 ci-dessus ont été appliquées
(documentation README/SECURITY.md) le jour même de l'audit.
