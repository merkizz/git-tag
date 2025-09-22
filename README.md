# Git Tag Manager

Le script `create-tag.sh` permet de créer des tags Git avec des fonctionnalités avancées de gestion des versions.

## Fonctionnalités

- 🏷️ Création de tags de version (`vX.Y.Z`)
- 💡 Suggestions de versions incrémentales (majeure, mineure, correctif)
- 🔍 Validation du format des tags
- 🔄 Création de tags temporaires sur les branches de fonctionnalité (`vX.Y.Z_BRANCH.N`)
- 🧹 Nettoyage automatique des tags temporaires
- 🔄 Gestion de la synchronisation des tags entre les branches principales (main/master) et les branches de fonctionnalité

## Prérequis

- Bash 4.0 ou supérieur
- Git 2.0 ou supérieur

## Installation

1. Clonez ce dépôt ou téléchargez le script `create-tag.sh`
2. Copiez le script à la racine de votre dépôt Git et rendez-le exécutable :
   ```bash
   chmod +x create-tag.sh
   ```
3. Configurez un alias Git pour simplifier l'utilisation du script
   ```bash
    git config alias.create-tag '!./create-tag.sh'
   ```
## Utilisation

### Mode basique

```bash
git create-tag [NOM_DU_TAG] [HASH_DU_COMMIT]
```

- `NOM_DU_TAG` : Le nom du tag à créer (format `vX.Y.Z`)
- `HASH_DU_COMMIT` (optionnel) : Le hash du commit à tagger (par défaut : `HEAD`)

### Exemples

1. Créer un tag sur le commit actuel :
   ```bash
   git create-tag v1.2.3
   ```

2. Créer un tag sur un commit spécifique :
   ```bash
   git create-tag v1.2.3 a1b2c3d
   ```

### Mode interactif

Exécutez le script sans arguments pour lancer le mode interactif :

```bash
git create-tag
```

Le mode interactif vous guidera à travers la création du tag avec des fonctionnalités avancées.

## Fonctionnement

Le script utilise les commandes Git pour :
- créer le tag localement et le pousser sur le remote
- récupérer les derniers tags afin de proposer des suggestions pour les tags suivants
- supprimer les tags temporaires dont les branches ont été supprimées (uniquement lorsque le script est exécuté sur la branche principale)

## Convention de nommage des tags

- **Tags de version** : `vX.Y.Z` (ex: v1.0.0)
  - `X` : Version majeure (changements non rétrocompatibles)
  - `Y` : Version mineure (nouvelles fonctionnalités)
  - `Z` : Correctifs (corrections de bugs)
  - Alternativement, il est possible de saisir une version faisant référence à un ticket (ex: FRONT-123, FRONT-123.1) (non recommandé)

- **Tags temporaires** : `vX.Y.Z_BRANCHE.N` (ex: v1.0.0_feature-123.1)
  - Ces tags sont générés uniquement pour les branches de fonctionnalité et ont une syntaxe incrémentale fixe
  - Le dernier tag de version à partir duquel la branche a divergé est utilisé pour générer le tag temporaire 
  - Après merge ou rebase de la branche principale, le dernier tag de version est repris comme base pour le tag temporaire suivant

## Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.
