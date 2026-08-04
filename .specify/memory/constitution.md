<!--
Sync Impact Report
- Version change: [TEMPLATE] → 1.0.0 (ratification initiale)
- Principes ajoutés :
  - I. Langue Française
  - II. Sécurité et Fiabilité (NON-NÉGOCIABLE)
  - III. Dépendances Récentes et Stables
  - IV. Test-First (NON-NÉGOCIABLE)
  - V. Tests d'Intégration Exhaustifs
- Sections ajoutées :
  - Gouvernance des Pull Requests
  - Qualité et Portes de Validation
  - Governance (procédure d'amendement, versionnage sémantique)
- Sections supprimées : aucune
- Templates dépendants : aucune modification effectuée par cette commande (hors périmètre) ;
  à vérifier lors de la prochaine exécution de /speckit-plan, /speckit-tasks, /speckit-checklist
  pour cohérence avec les nouveaux principes (portes de test, langue française, gel des PR).
- TODOs différés : aucun
-->

# Pollen Data Field Constitution

## Core Principles

### I. Langue Française
Toute la documentation du projet (spécifications, README, commentaires de prose, messages
de commit, tickets, rapports) DOIT être rédigée en français. Les identifiants techniques
(noms de variables, fonctions, classes, tables) PEUVENT rester en anglais lorsque requis par
des conventions du langage ou d'une bibliothèque externe, mais toute explication, tout
commentaire narratif et toute communication destinée à un lecteur humain DOIVENT être en
français correct, avec orthographe et accents complets.

**Rationale** : Le projet est piloté par une équipe francophone ; une documentation
cohérente en français réduit les erreurs d'interprétation et facilite la revue par toutes
les parties prenantes.

### II. Sécurité et Fiabilité (NON-NÉGOCIABLE)
Un niveau de sécurité et de fiabilité élevé est exigé à chaque étape du projet. Toute
fonctionnalité manipulant des données ou des entrées externes DOIT faire l'objet d'une revue
de sécurité avant fusion. Les vulnérabilités du OWASP Top 10 (injection, XSS, désérialisation
non sécurisée, exposition de données sensibles, etc.) DOIVENT être activement prévenues et non
simplement corrigées après coup. Les erreurs DOIVENT être gérées explicitement aux frontières
du système (entrées utilisateur, appels réseau, fichiers externes) sans jamais exposer
d'informations sensibles (secrets, traces internes) dans les réponses ou journaux accessibles.
Aucune fonctionnalité critique ne DOIT être livrée sans stratégie de reprise en cas de
défaillance (repli, nouvelle tentative, surveillance).

**Rationale** : Le coût d'un incident de sécurité ou d'une panne en production dépasse
largement le coût d'une vérification systématique en amont ; ce principe n'admet aucune
exception de confort ou de délai.

### III. Dépendances Récentes et Stables
Toute bibliothèque, tout framework et tout outil ajouté ou mis à jour DOIT utiliser la
version stable la plus récente disponible au moment de l'ajout, vérifiée activement (registre
du gestionnaire de paquets, documentation officielle) plutôt que déduite de connaissances
mémorisées pouvant être obsolètes. Les versions DOIVENT être épinglées explicitement dans les
fichiers de dépendances. Toute mise à jour majeure DOIT être documentée avec sa justification
et une évaluation des risques de rupture (breaking changes).

**Rationale** : Les versions figées dans les données d'entraînement d'un modèle ou dans des
habitudes anciennes sont une source fréquente de failles de sécurité corrigées en amont et
de dette technique évitable.

### IV. Test-First (NON-NÉGOCIABLE)
Le projet DOIT être testé de bout en bout avant toute implémentation en production. Le cycle
Red-Green-Refactor est obligatoire : les tests sont écrits en premier, validés comme échouant
pour la bonne raison, puis le code de production est écrit pour les faire passer. Aucune
fonctionnalité ne DOIT être considérée terminée sans une suite de tests de bout en bout
démontrant son bon fonctionnement dans des conditions proches de la production.

**Rationale** : Écrire les tests avant l'implémentation garantit que les exigences sont
comprises et vérifiables avant que le code ne soit produit, plutôt que rétro-ajustées.

### V. Tests d'Intégration Exhaustifs
Chaque partie du projet (API, stockage de données, intégrations externes, interfaces
utilisateur) DOIT disposer de tests d'intégration couvrant les scénarios réels d'utilisation,
en complément des tests unitaires isolés. Tout changement de contrat (API, schéma de données,
format d'échange) DOIT être accompagné de tests d'intégration mis à jour avant toute fusion.
Aucune partie du projet ne DOIT rester sans couverture d'intégration.

**Rationale** : Les tests unitaires seuls ne détectent pas les régressions d'interaction
entre composants ; l'exhaustivité des tests d'intégration est la garantie explicitement
exigée pour ce projet.

## Gouvernance des Pull Requests

Aucune pull request ne DOIT être fusionnée (mergée) par Claude ou par tout autre agent IA,
quel que soit le niveau d'autonomie qui lui est accordé pour les autres tâches (rédaction de
code, exécution de tests, revue automatisée). La fusion d'une pull request est une action
réservée à un·e contributeur·rice humain·e habilité·e, après revue et validation explicite.
Un agent IA PEUT préparer, ouvrir et documenter une pull request, mais DOIT toujours laisser
la décision et l'action de fusion à un humain.

## Qualité et Portes de Validation

Toute fonctionnalité DOIT franchir les portes suivantes avant fusion :
1. Tests de bout en bout passants (Principe IV).
2. Tests d'intégration passants sur toutes les parties concernées (Principe V).
3. Revue de sécurité pour tout code touchant à l'authentification, aux données sensibles,
   ou aux entrées externes (Principe II).
4. Vérification que les dépendances utilisées sont bien les versions stables les plus
   récentes disponibles (Principe III).
5. Documentation et prose du changement rédigées en français (Principe I).

Un échec à l'une de ces portes bloque la fusion, sans exception.

## Governance

Cette constitution prévaut sur toute autre pratique, préférence individuelle ou raccourci de
convenance. Toute modification DOIT être proposée via une mise à jour explicite de ce
document, accompagnée d'un rapport d'impact de synchronisation (Sync Impact Report) et d'une
justification du type de changement — majeur, mineur ou correctif — selon le versionnage
sémantique :
- **MAJEUR** : suppression ou redéfinition incompatible d'un principe ou d'une règle de
  gouvernance.
- **MINEUR** : ajout d'un principe ou d'une section, ou renforcement matériel d'une exigence
  existante.
- **CORRECTIF** : clarifications, corrections de formulation, ajustements non sémantiques.

Chaque pull request et chaque revue de code DOIT vérifier la conformité aux principes
ci-dessus avant toute fusion humaine (voir Gouvernance des Pull Requests). Toute complexité
ajoutée à l'architecture DOIT être justifiée explicitement au regard des principes de
sécurité, de fiabilité et de simplicité. Les agents IA, y compris Claude, opèrent sous ces
contraintes et ne DOIVENT jamais contourner les portes de qualité ni fusionner du code de
manière autonome.

**Version**: 1.0.0 | **Ratified**: 2026-08-04 | **Last Amended**: 2026-08-04
