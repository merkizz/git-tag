#!/bin/bash

# Script intelligent de création de tags avec nettoyage automatique intégré
# Usage: ./create-tag.sh [tag-name] [commit-hash]

set -e

# Couleurs pour l'affichage
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[1;36m'
readonly COLOR_NONE='\033[0m'

echo -e "${COLOR_CYAN}🏷️  Script intelligent de création de tags${COLOR_NONE}"
echo -e "${COLOR_CYAN}==========================================${COLOR_NONE}"

# Vérification que nous sommes dans un dépôt Git
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${COLOR_RED}❌ Erreur: Ce script doit être exécuté dans un dépôt Git${COLOR_NONE}"
    exit 1
fi

# Fonction pour obtenir le dernier tag sémantique
get_latest_semantic_tag() {
    git tag -l | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+$" | sort -V | tail -1
}

# Fonction pour obtenir la branche courante
get_current_branch() {
    git branch --show-current
}

# Fonction pour obtenir le prochain suffixe disponible pour un tag temporaire
get_next_temp_suffix() {
    local base_tag="$1"
    local branch="$2"
    local suffix=1

    # Chercher les tags existants avec ce pattern
    while git tag -l | grep -q "^${base_tag}_${branch}\.${suffix}$"; do
        ((suffix++))
    done

    echo "$suffix"
}

# Fonction pour trouver le tag de base de la branche courante
get_branch_base_tag() {
    local current_branch=$(get_current_branch)
    local main_branch="master"

    # Vérifier si master existe, sinon utiliser main
    if ! git show-ref --verify --quiet refs/heads/master; then
        if git show-ref --verify --quiet refs/heads/main; then
            main_branch="main"
        else
            # Fallback sur le dernier tag sémantique si pas de branche principale trouvée
            get_latest_semantic_tag
            return
        fi
    fi

    # Trouver le commit de base (merge-base) entre la branche courante et master/main
    local base_commit=$(git merge-base "$current_branch" "$main_branch" 2>/dev/null || echo "")

    if [ -z "$base_commit" ]; then
        # Si pas de merge-base trouvé, utiliser le dernier tag sémantique
        get_latest_semantic_tag
        return
    fi

    # Trouver le tag sémantique le plus récent qui contient ce commit de base
    local base_tag=$(git tag -l --merged "$base_commit" | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+$" | sort -V | tail -1)

    if [ -z "$base_tag" ]; then
        # Si aucun tag trouvé au point de base, utiliser le dernier tag sémantique
        get_latest_semantic_tag
    else
        echo "$base_tag"
    fi
}

# Fonction pour vérifier si on est sur une branche principale
is_main_branch() {
    local branch=$(get_current_branch)
    [[ "$branch" == "master" || "$branch" == "main" || "$branch" == "develop" ]]
}

# Fonction pour suggérer les prochaines versions
suggest_next_versions() {
    local latest_tag=$(get_latest_semantic_tag)
    local interactive_mode=${1:-false}
    local current_branch=$(get_current_branch)
    
    echo -e "${COLOR_YELLOW}💡 Branche courante: ${COLOR_BLUE}$current_branch${COLOR_NONE}"
    
    if [ -z "$latest_tag" ]; then
        echo -e "${COLOR_YELLOW}💡 Aucun tag sémantique trouvé${COLOR_NONE}"
        echo -e "${COLOR_YELLOW}💡 Version à créer:${COLOR_NONE}"
        if [ "$interactive_mode" = true ]; then
            echo -e "   ${COLOR_GREEN}1)${COLOR_NONE} ${COLOR_CYAN}v1.0.0${COLOR_NONE} - Première version"
            echo -e "   ${COLOR_GREEN}2)${COLOR_NONE} ${COLOR_CYAN}v0.1.0${COLOR_NONE} - Version de développement"
            echo -e "   ${COLOR_GREEN}3)${COLOR_NONE} Saisir manuellement"
            echo -e "   ${COLOR_GREEN}4)${COLOR_NONE} Annuler"
        else
            echo "   - v1.0.0 (première version)"
            echo "   - v0.1.0 (version de développement)"
        fi
        return 0
    fi
    
    # Extraire les numéros de version
    local version_numbers=$(echo "$latest_tag" | sed 's/^v//' | tr '.' ' ')
    local major=$(echo $version_numbers | awk '{print $1}')
    local minor=$(echo $version_numbers | awk '{print $2}')
    local patch=$(echo $version_numbers | awk '{print $3}')
    
    echo -e "${COLOR_YELLOW}💡 Dernier tag: ${COLOR_BLUE}$latest_tag${COLOR_NONE}"
    echo -e "${COLOR_YELLOW}💡 Version à créer:${COLOR_NONE}"
    
    if [ "$interactive_mode" = true ]; then
        if is_main_branch; then
            # Branche principale : tags sémantiques seulement
            local next_patch="v$major.$minor.$((patch + 1))"
            local next_minor="v$major.$((minor + 1)).0"
            local next_major="v$((major + 1)).0.0"
            
            echo -e "   ${COLOR_GREEN}1)${COLOR_NONE} ${COLOR_CYAN}$next_patch${COLOR_NONE} - Correctif (patch) - Corrections de bugs"
            echo -e "   ${COLOR_GREEN}2)${COLOR_NONE} ${COLOR_CYAN}$next_minor${COLOR_NONE} - Fonctionnalité (minor) - Nouvelles fonctionnalités"
            echo -e "   ${COLOR_GREEN}3)${COLOR_NONE} ${COLOR_CYAN}$next_major${COLOR_NONE} - Majeure (major) - Changements non rétrocompatibles"
            echo -e "   ${COLOR_GREEN}4)${COLOR_NONE} Saisir manuellement"
            echo -e "   ${COLOR_GREEN}5)${COLOR_NONE} Annuler"
        else
            # Branche secondaire : uniquement des tags temporaires basés sur le tag de base de branche
            local base_tag=$(get_branch_base_tag)
            local next_suffix=$(get_next_temp_suffix "$base_tag" "$current_branch")
            local temp_tag="${base_tag}_${current_branch}.${next_suffix}"
            
            echo -e "   ${COLOR_GREEN}1)${COLOR_NONE} ${COLOR_CYAN}$temp_tag${COLOR_NONE} - Tag temporaire (basé sur $base_tag)"
            echo -e "   ${COLOR_GREEN}2)${COLOR_NONE} Annuler"
            echo ""
            echo -e "   ${COLOR_CYAN}ℹ️  Sur une branche secondaire, seuls les tags temporaires sont autorisés${COLOR_NONE}"
            echo -e "   ${COLOR_CYAN}💡 Les tags finaux doivent être créés sur la branche principale après merge${COLOR_NONE}"
        fi
    else
        local next_patch="v$major.$minor.$((patch + 1))"
        local next_minor="v$major.$((minor + 1)).0"
        local next_major="v$((major + 1)).0.0"
        
        echo -e "   ${COLOR_CYAN}$next_patch${COLOR_NONE} - Correctif (patch) - Corrections de bugs"
        echo -e "   ${COLOR_CYAN}$next_minor${COLOR_NONE} - Fonctionnalité (minor) - Nouvelles fonctionnalités"
        echo -e "   ${COLOR_CYAN}$next_major${COLOR_NONE} - Majeure (major) - Changements incompatibles"
        
        if ! is_main_branch; then
            local temp_patch="${next_patch}_${current_branch}.1"
            echo -e "   ${COLOR_YELLOW}$temp_patch${COLOR_NONE} - Tag temporaire (sera nettoyé automatiquement)"
        fi
    fi
}

# Fonction pour le mode interactif
interactive_tag_creation() {
    echo ""

    suggest_next_versions true

    local current_branch=$(get_current_branch)
    local latest_tag=$(get_latest_semantic_tag)
    local selected_tag=""

    echo ""

    local initial_branch=$(get_current_branch)
    local initial_is_main=$(is_main_branch && echo "true" || echo "false")

    if [ -z "$latest_tag" ]; then
        read -p "Choisissez une option (1-4): " choice
        if [ "$choice" = "4" ]; then
            echo -e "${COLOR_YELLOW}🚫 Création de tag annulée.${COLOR_NONE}"
            return 1
        fi
    else
        if is_main_branch; then
            read -p "Choisissez une option (1-5): " choice
        else
            read -p "Choisissez une option (1-2): " choice
        fi
    fi

    # Vérification de sécurité : s'assurer que la branche n'a pas changé pendant la saisie
    local current_branch_after=$(get_current_branch)
    local current_is_main_after=$(is_main_branch && echo "true" || echo "false")

    if [ "$initial_branch" != "$current_branch_after" ] || [ "$initial_is_main" != "$current_is_main_after" ]; then
        echo -e "${COLOR_RED}❌ ERREUR : La branche a changé pendant l'exécution du script !${COLOR_NONE}"
        echo -e "${COLOR_RED}   Branche initiale: $initial_branch (main: $initial_is_main)${COLOR_NONE}"
        echo -e "${COLOR_RED}   Branche actuelle: $current_branch_after (main: $current_is_main_after)${COLOR_NONE}"
        echo -e "${COLOR_YELLOW}⚠️  Pour éviter les incohérences, veuillez relancer le script sur la branche souhaitée.${COLOR_NONE}"
        exit 1
    fi

    if [ ! -z "$latest_tag" ]; then
        # Extraire les numéros de version
        local version_numbers=$(echo "$latest_tag" | sed 's/^v//' | tr '.' ' ')
        local major=$(echo $version_numbers | awk '{print $1}')
        local minor=$(echo $version_numbers | awk '{print $2}')
        local patch=$(echo $version_numbers | awk '{print $3}')

        # Calculer les suggestions
        local next_patch="v$major.$minor.$((patch + 1))"
        local next_minor="v$major.$((minor + 1)).0"
        local next_major="v$((major + 1)).0.0"
        local temp_patch="${next_patch}_${current_branch}.1"

        if is_main_branch; then
            # Logique pour branche principale
            case $choice in
                1)
                    selected_tag="$next_patch"
                    echo -e "${COLOR_GREEN}✅ Sélectionné: $selected_tag (correctif)${COLOR_NONE}"
                    ;;
                2)
                    selected_tag="$next_minor"
                    echo -e "${COLOR_GREEN}✅ Sélectionné: $selected_tag (fonctionnalité)${COLOR_NONE}"
                    ;;
                3)
                    selected_tag="$next_major"
                    echo -e "${COLOR_GREEN}✅ Sélectionné: $selected_tag (majeure)${COLOR_NONE}"
                    ;;
                4)
                    echo ""
                    read -p "Saisissez le tag manuellement: " selected_tag
                    if [ -z "$selected_tag" ]; then
                        echo -e "${COLOR_RED}❌ Tag vide, opération annulée${COLOR_NONE}"
                        exit 1
                    fi
                    ;;
                5)
                    echo -e "${COLOR_YELLOW}🚫 Création de tag annulée.${COLOR_NONE}"
                    exit 0
                    ;;
                *)
                    echo -e "${COLOR_RED}❌ Choix invalide, opération annulée${COLOR_NONE}"
                    exit 1
                    ;;
            esac
        else
            # Logique pour branche secondaire - uniquement tags temporaires basés sur le tag de base
            local base_tag=$(get_branch_base_tag)
            local next_suffix=$(get_next_temp_suffix "$base_tag" "$current_branch")
            local temp_tag="${base_tag}_${current_branch}.${next_suffix}"

            case $choice in
                1)
                    selected_tag="$temp_tag"
                    echo -e "${COLOR_YELLOW}✅ Sélectionné: $selected_tag${COLOR_NONE}"
                    ;;
                2)
                    echo -e "${COLOR_YELLOW}🚫 Création de tag annulée.${COLOR_NONE}"
                    exit 0
                    ;;
                *)
                    echo -e "${COLOR_RED}❌ Choix invalide, opération annulée${COLOR_NONE}"
                    exit 1
                    ;;
            esac
        fi
    else
        # Cas où il n'y a pas de tag sémantique existant
        case $choice in
            1)
                selected_tag="v1.0.0"
                echo -e "${COLOR_GREEN}✅ Sélectionné: $selected_tag (première version)${COLOR_NONE}"
                ;;
            2)
                selected_tag="v0.1.0"
                echo -e "${COLOR_GREEN}✅ Sélectionné: $selected_tag (version de développement)${COLOR_NONE}"
                ;;
            3)
                echo ""
                read -p "Saisissez le tag manuellement: " selected_tag
                if [ -z "$selected_tag" ]; then
                    echo -e "${COLOR_RED}❌ Tag vide, opération annulée${COLOR_NONE}"
                    exit 1
                fi
                ;;
            *)
                echo -e "${COLOR_RED}❌ Choix invalide, opération annulée${COLOR_NONE}"
                exit 1
                ;;
        esac
    fi

    # Appliquer le tag sélectionné
    if is_main_branch; then
        echo -e "\n${COLOR_BLUE}🚀 Application du tag sélectionné: $selected_tag${COLOR_NONE}"
    fi
    TAG_NAME="$selected_tag"
}

# Valider les arguments - rejeter toute option inconnue
FILTERED_ARGS=()
for arg in "$@"; do
    if [[ "$arg" =~ ^-- ]]; then
        echo -e "${COLOR_RED}❌ Option inconnue: $arg${COLOR_NONE}"
        echo -e "${COLOR_BLUE}Ce script n'accepte aucune option.${COLOR_NONE}"
        echo -e "${COLOR_BLUE}Usage:${COLOR_NONE}"
        echo "  $0                # Mode interactif"
        echo "  $0 <tag-name>     # Création directe"
        echo "  $0 <tag-name> <commit-hash>"
        exit 1
    else
        FILTERED_ARGS+=("$arg")
    fi
done

# Mode interactif par défaut si aucun tag fourni
if [ ${#FILTERED_ARGS[@]} -lt 1 ]; then
    # Lancer le mode interactif par défaut
    interactive_tag_creation
fi

# Si on arrive ici, on a soit un tag fourni, soit on vient du mode interactif
if [ -z "$TAG_NAME" ]; then
    TAG_NAME="${FILTERED_ARGS[0]}"
    
    # Vérifier si on essaie de créer un tag final sur une branche secondaire
    if [ ! -z "$TAG_NAME" ] && ! is_main_branch; then
        # Vérifier si c'est un tag sémantique (final)
        if [[ "$TAG_NAME" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ "$TAG_NAME" =~ ^(BACK|FRONT|CMP|CNS|PRTL)-[0-9]+\.[0-9]+$ ]]; then
            echo -e "${COLOR_RED}❌ Impossible de créer un tag final sur une branche secondaire${COLOR_NONE}"
            echo -e "${COLOR_BLUE}💡 Les tags finaux doivent être créés sur la branche principale (master/main)${COLOR_NONE}"
            echo -e "${COLOR_YELLOW}💡 Utilisez le mode interactif pour créer des tags temporaires: ./create-tag.sh${COLOR_NONE}"
            exit 1
        fi
    fi
fi

COMMIT_HASH="${FILTERED_ARGS[1]:-HEAD}"

# Fonction pour valider le format du tag
validate_tag_format() {
    local tag="$1"
    
    # Patterns acceptés pour les tags sémantiques
    if [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${COLOR_GREEN}✅ Tag de version sémantique valide: $tag${COLOR_NONE}"
        return 0
    elif [[ "$tag" =~ ^(BACK|FRONT|CMP|CNS|PRTL)-[0-9]+\.[0-9]+$ ]]; then
        echo -e "${COLOR_GREEN}✅ Tag de ticket valide: $tag${COLOR_NONE}"
        return 0
    elif [[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-[a-z]+$ ]]; then
        echo -e "${COLOR_YELLOW}⚠️  Tag de pré-release: $tag${COLOR_NONE}"
        echo -e "${COLOR_YELLOW}   Assurez-vous que c'est intentionnel.${COLOR_NONE}"
        return 0
    elif [[ "$tag" =~ _.*\. ]]; then
        # Tags temporaires - autorisés uniquement sur les branches secondaires
        if ! is_main_branch; then
            echo -e "${COLOR_YELLOW}✅ Tag temporaire valide: $tag${COLOR_NONE}"
            return 0
        else
            echo -e "${COLOR_RED}❌ Les tags temporaires ne sont pas autorisés sur les branches principales${COLOR_NONE}"
            echo -e "${COLOR_BLUE}💡 Utilisez un tag sémantique (v1.2.3) ou de ticket (BACK-123.1)${COLOR_NONE}"
            return 1
        fi
    else
        echo -e "${COLOR_RED}❌ Format de tag non valide: $tag${COLOR_NONE}"
        echo -e "${COLOR_BLUE}Formats acceptés:${COLOR_NONE}"
        if is_main_branch; then
            echo "  - Versions sémantiques: v1.2.3"
            echo "  - Tags de tickets: BACK-123.1, FRONT-456.2"
            echo "  - Pré-releases: v1.2.3-alpha, v1.2.3-beta"
        else
            echo "  - Tags temporaires: v1.2.3_BRANCHE.1"
            echo "  - Versions sémantiques: v1.2.3 (non recommandé)"
            echo "  - Tags de tickets: BACK-123.1 (non recommandé)"
        fi
        echo -e "${COLOR_RED}Formats interdits:${COLOR_NONE}"
        echo "  - Tags de test: v1.2.3_testing.1"
        echo "  - Tags non sémantiques: fix_something_v1"
        return 1
    fi
}

# Fonction pour vérifier si le tag existe déjà
check_tag_exists() {
    local tag="$1"

    if git tag -l | grep -q "^$tag$"; then
        echo -e "${COLOR_RED}❌ Le tag '$tag' existe déjà localement${COLOR_NONE}"
        return 1
    fi

    if git ls-remote --tags origin | grep -q "refs/tags/$tag$"; then
        echo -e "${COLOR_RED}❌ Le tag '$tag' existe déjà sur le remote${COLOR_NONE}"
        return 1
    fi

    return 0
}

# Fonction de nettoyage automatique des tags temporaires
auto_cleanup_temp_tags() {
    echo -e "\n${COLOR_BLUE}🧹 Nettoyage automatique des tags temporaires...${COLOR_NONE}"

    # Pattern amélioré pour détecter tous les types de tags temporaires
    temp_tags=$(git tag -l | grep -E "_.*\.|_[A-Z]+-[0-9]+$" || true)
    
    if [ -z "$temp_tags" ]; then
        echo -e "${COLOR_GREEN}   ✅ Aucun tag temporaire à nettoyer${COLOR_NONE}"
        return 0
    fi
    
    temp_count=$(echo "$temp_tags" | wc -l | tr -d ' ')
    echo -e "${COLOR_YELLOW}   🔍 $temp_count tags temporaires détectés${COLOR_NONE}"
    
    # Affiche les premiers tags temporaires
    echo "$temp_tags" | head -5 | while read tag; do
        echo "     - $tag"
    done
    
    if [ $temp_count -gt 5 ]; then
        echo "     ... et $((temp_count - 5)) autres"
    fi
    
    echo -e "${COLOR_BLUE}   Suppression automatique des tags temporaires...${COLOR_NONE}"
    
    count=0
    for tag in $temp_tags; do
        echo "     Suppression: $tag"
        git tag -d "$tag" 2>/dev/null || true
        count=$((count + 1))
    done
    
    echo -e "${COLOR_GREEN}   ✅ $count tags temporaires supprimés localement${COLOR_NONE}"
    
    # Nettoyage des tags temporaires distants
    echo -e "${COLOR_BLUE}   Nettoyage des tags temporaires sur le remote...${COLOR_NONE}"
    remote_temp_tags=$(git ls-remote --tags origin | grep -E "_.*\.|_[A-Z]+-[0-9]+$" | awk '{print $2}' | sed 's/refs\/tags\///' || true)
    
    if [ ! -z "$remote_temp_tags" ]; then
        remote_count=0
        for tag in $remote_temp_tags; do
            echo "     Suppression remote: $tag"
            git push --delete origin "$tag" 2>/dev/null || echo "       ⚠️  Tag $tag déjà supprimé"
            remote_count=$((remote_count + 1))
        done
        echo -e "${COLOR_GREEN}   ✅ $remote_count tags temporaires distants supprimés${COLOR_NONE}"
    else
        echo -e "${COLOR_GREEN}   ✅ Aucun tag temporaire distant à supprimer${COLOR_NONE}"
    fi
}

# Fonction pour créer et pousser le tag
create_and_push_tag() {
    local tag="$1"
    local commit="$2"
    
    echo -e "\n${COLOR_BLUE}🏷️  Création du tag '$tag'...${COLOR_NONE}"
    
    # Vérifier que le commit existe
    if ! git rev-parse --verify "$commit" >/dev/null 2>&1; then
        echo -e "${COLOR_RED}❌ Le commit '$commit' n'existe pas${COLOR_NONE}"
        return 1
    fi

    # Créer le tag
    git tag "$tag" "$commit" -m "Build tag $tag"
    echo -e "${COLOR_GREEN}   ✅ Tag '$tag' créé localement${COLOR_NONE}"
    
    # Pousser le tag
    echo -e "${COLOR_BLUE}   📤 Push du tag vers le remote...${COLOR_NONE}"
    git push origin "$tag"
    echo -e "${COLOR_GREEN}   ✅ Tag '$tag' poussé sur le remote${COLOR_NONE}"
}

# Fonction pour afficher les statistiques finales
show_final_stats() {
    if is_main_branch; then
        echo -e "\n${COLOR_BLUE}📊 Statistiques finales:${COLOR_NONE}"
        total_tags=$(git tag -l | wc -l | tr -d ' ')
        temp_tags=$(git tag -l | grep -E "_.*\.|_[A-Z]+-[0-9]+$" | wc -l | tr -d ' ')
        clean_tags=$((total_tags - temp_tags))
        
        echo "   Total des tags: $total_tags"
        echo "   Tags temporaires: $temp_tags"
        echo "   Tags propres: $clean_tags"
        
        if [ $temp_tags -eq 0 ]; then
            echo -e "${COLOR_GREEN}   🎉 Dépôt parfaitement nettoyé !${COLOR_NONE}"
        fi
    fi
}

# MAIN EXECUTION
if is_main_branch; then
    echo -e "${COLOR_BLUE}🔍 Validation du tag '$TAG_NAME'...${COLOR_NONE}"
    
    # 1. Valider le format du tag (uniquement sur branches principales)
    if ! validate_tag_format "$TAG_NAME"; then
        exit 1
    fi
fi

# 2. Vérifier que le tag n'existe pas déjà
if ! check_tag_exists "$TAG_NAME"; then
    exit 1
fi

# 3. Nettoyage automatique (uniquement sur les branches principales)
if is_main_branch; then
    auto_cleanup_temp_tags
fi

# 4. Créer et pousser le tag
if ! create_and_push_tag "$TAG_NAME" "$COMMIT_HASH"; then
    exit 1
fi

# 5. Afficher les statistiques finales
show_final_stats

echo -e "\n${COLOR_GREEN}🎉 Tag '$TAG_NAME' créé avec succès !${COLOR_NONE}"

if is_main_branch; then
    echo -e "${COLOR_BLUE}Le dépôt a été automatiquement nettoyé des tags temporaires.${COLOR_NONE}"
    
    # Message de bonnes pratiques pour les branches principales
    echo -e "\n${COLOR_YELLOW}💡 Bonnes pratiques:${COLOR_NONE}"
    echo "   - Utilisez ce script pour créer tous vos tags"
    echo "   - Évitez 'git tag' et 'git push --tags' directement"
    echo "   - Le nettoyage automatique maintient un dépôt propre"
else
    # Message simplifié pour les branches secondaires
    echo -e "\n${COLOR_YELLOW}💡 Tag temporaire créé pour le développement sur cette branche.${COLOR_NONE}"
fi
