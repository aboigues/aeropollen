# Politique de sécurité

## Versions supportées

Projet mono-branche (`main`), pas de versions maintenues en parallèle. Seule la dernière
version sur `main` reçoit des correctifs de sécurité.

## Signaler une vulnérabilité

Merci de **ne pas ouvrir d'issue publique** pour une vulnérabilité de sécurité. Contacter
directement : **a.boigues@gmail.com**, en décrivant :

- le composant concerné (application `aeropollen-air-quality-field`, `aeropollen-pollen-field`,
  barrel `AeroPollenCore`, scripts `.specify/`, ou workflow CI) ;
- les étapes de reproduction ou le code concerné ;
- l'impact estimé.

Un accusé de réception est visé sous 7 jours. Le correctif, une fois publié, est documenté dans
[`SECURITY_AUDIT.md`](SECURITY_AUDIT.md) et dans l'historique Git.

## Périmètre

Ce projet est une application Garmin Connect IQ à usage personnel/communautaire, sans compte
utilisateur, sans backend propre et sans donnée transmise à un tiers autre que l'API publique
[Open-Meteo](https://open-meteo.com/) (position GPS uniquement, sur HTTPS, sans clé
d'authentification). Voir [`SECURITY_AUDIT.md`](SECURITY_AUDIT.md) pour le détail de la surface
d'attaque considérée et les vérifications déjà effectuées.

## Vérifications automatisées

Le pipeline GitHub Actions (`.github/workflows/security.yml`) exécute à chaque Pull Request :
détection de secrets committés, analyse statique des scripts Shell (`shellcheck`), et
validation des manifestes Connect IQ. Voir ce workflow pour le détail exact et ses limites
(le SDK Garmin, propriétaire et nécessitant une connexion à un compte, n'est pas installable en
CI — la compilation n'y est donc pas vérifiée automatiquement, seulement en local).
