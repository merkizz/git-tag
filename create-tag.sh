#!/bin/bash

# Script intelligent de création de tags avec nettoyage automatique intégré
# Usage: ./create-tag.sh [tag-name] [commit-hash]

set -e

# Couleurs pour l'affichage
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[1;36m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_NONE='\033[0m'

# Valeurs par défaut
readonly DEFAULT_COMMIT="HEAD"
readonly DEFAULT_MAJOR_VERSION="v1.0.0"
readonly DEFAULT_MINOR_VERSION="v0.1.0"

# Patterns de tags
readonly SEMANTIC_TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+$'
readonly TICKET_TAG_PATTERN='^(BACK|FRONT|CMP|CNS|PRTL)-[0-9]+\.[0-9]+$'
readonly PRERELEASE_TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+-[a-z]+$'
readonly TEMPORARY_TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+_.+\.[0-9]+$'
readonly TEMPORARY_TAG_CLEANUP_PATTERN='_.*\.|_[A-Z]+-[0-9]+$'

# Fonctions d'affichage pour factoriser les messages
print_blue() {
  echo -e "${COLOR_BLUE}$1${COLOR_NONE}"
}

print_cyan() {
  echo -e "${COLOR_CYAN}$1${COLOR_NONE}"
}

print_green() {
  echo -e "${COLOR_GREEN}$1${COLOR_NONE}"
}

print_red() {
  echo -e "${COLOR_RED}$1${COLOR_NONE}"
}

print_yellow() {
  echo -e "${COLOR_YELLOW}$1${COLOR_NONE}"
}

print_info() {
    print_blue "$1"
}

print_success() {
    print_green "✅ $1"
}

print_warning() {
    print_yellow "⚠️ $1"
}

print_error() {
    print_red "❌ $1"
}

print_tip() {
    print_yellow "💡 $1"
}

print_option() {
    local number="$1"
    local description="$2"
    local value="$3"
    echo -e "   ${COLOR_GREEN}${number})${COLOR_NONE} $description ${COLOR_CYAN}${value}${COLOR_NONE}"
}

print_header() {
    print_cyan "$1"
}

# Fonction pour obtenir le dernier tag sémantique
get_latest_semantic_tag() {
    git tag -l | grep -E "$SEMANTIC_TAG_PATTERN" | sort -V | tail -1
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
    local base_tag=$(git tag -l --merged "$base_commit" | grep -E "$SEMANTIC_TAG_PATTERN" | sort -V | tail -1)

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
    local current_branch=$(get_current_branch)

    print_yellow "Branche courante: ${COLOR_BLUE}$current_branch${COLOR_NONE}"

    if is_main_branch; then
        local latest_tag=$(get_latest_semantic_tag)
        if [ -z "$latest_tag" ]; then
            print_yellow "Aucun tag sémantique trouvé"
            print_yellow "Version à créer:"
            print_option "1" "Première version" "v1.0.0"
            print_option "2" "Version de développement" "v0.1.0"
            print_option "3" "Saisir manuellement"
            print_option "4" "Annuler"
            return 0
        fi

        # Calculer les versions suivantes
        local version_numbers=$(echo "$latest_tag" | sed 's/^v//' | tr '.' ' ')
        local major=$(echo $version_numbers | awk '{print $1}')
        local minor=$(echo $version_numbers | awk '{print $2}')
        local patch=$(echo $version_numbers | awk '{print $3}')

        # Branche principale : tags sémantiques seulement
        local next_patch="v$major.$minor.$((patch + 1))"
        local next_minor="v$major.$((minor + 1)).0"
        local next_major="v$((major + 1)).0.0"

        print_yellow "Dernier tag: ${COLOR_BLUE}$latest_tag${COLOR_NONE}"
        print_yellow "Version à créer:"
        print_option "1" "Correctif (patch) - Corrections de bugs" "$next_patch"
        print_option "2" "Fonctionnalité (minor) - Nouvelles fonctionnalités" "$next_minor"
        print_option "3"  "Majeure (major) - Changements non rétrocompatibles" "$next_major"
        print_option "4" "Saisir manuellement"
        print_option "5" "Annuler"
    else
        # Branche secondaire : uniquement des tags temporaires
        local base_tag=$(get_branch_base_tag)
        local next_suffix=$(get_next_temp_suffix "$base_tag" "$current_branch")
        local temp_tag="${base_tag}_${current_branch}.${next_suffix}"

        print_yellow "Version à créer:"
        print_option "1" "Tag temporaire (basé sur $base_tag)" "$temp_tag"
        print_option "2" "Annuler"
        echo ""
        print_tip "Sur une branche secondaire, seuls les tags temporaires sont autorisés, les tags finaux doivent être créés sur la branche principale après merge"
    fi
}

# Fonction pour le mode interactif
interactive_tag_creation() {
    echo ""

    suggest_next_versions

    local current_branch=$(get_current_branch)
    local latest_tag=$(get_latest_semantic_tag)
    local selected_tag=""

    echo ""

    local initial_branch=$(get_current_branch)
    local initial_is_main=$(is_main_branch && echo "true" || echo "false")

    if [ -z "$latest_tag" ]; then
        read -p "Choisissez une option (1-4): " choice
        if [ "$choice" = "4" ]; then
            print_yellow "🚫 Création de tag annulée."
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
        print_error "ERREUR : La branche a changé pendant l'exécution du script !"
        print_red "Branche initiale: $initial_branch (main: $initial_is_main)"
        print_red "Branche actuelle: $current_branch_after (main: $current_is_main_after)"
        print_warning "Pour éviter les incohérences, veuillez relancer le script sur la branche souhaitée."
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
                    print_success "Sélectionné: $selected_tag (correctif)"
                    ;;
                2)
                    selected_tag="$next_minor"
                    print_success "Sélectionné: $selected_tag (fonctionnalité)"
                    ;;
                3)
                    selected_tag="$next_major"
                    print_success "Sélectionné: $selected_tag (majeure)"
                    ;;
                4)
                    echo ""
                    read -p "Saisissez le tag manuellement: " selected_tag
                    if [ -z "$selected_tag" ]; then
                        print_error "Tag vide, opération annulée"
                        exit 1
                    fi
                    ;;
                5)
                    print_yellow "🚫 Création de tag annulée."
                    exit 0
                    ;;
                *)
                    print_error "Choix invalide, opération annulée"
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
                    print_success "Sélectionné: $selected_tag"
                    ;;
                2)
                    print_yellow "🚫 Création de tag annulée."
                    exit 0
                    ;;
                *)
                    print_error "Choix invalide, opération annulée"
                    exit 1
                    ;;
            esac
        fi
    else
        # Cas où il n'y a pas de tag sémantique existant
        case $choice in
            1)
                selected_tag="$DEFAULT_MAJOR_VERSION"
                print_success "Sélectionné: $selected_tag (première version)"
                ;;
            2)
                selected_tag="$DEFAULT_MINOR_VERSION"
                print_success "Sélectionné: $selected_tag (version de développement)"
                ;;
            3)
                echo ""
                read -p "Saisissez le tag manuellement: " selected_tag
                if [ -z "$selected_tag" ]; then
                    print_error "Tag vide, opération annulée"
                    exit 1
                fi
                ;;
            *)
                print_error "Choix invalide, opération annulée"
                exit 1
                ;;
        esac
    fi

    # Appliquer le tag sélectionné
    if is_main_branch; then
        echo ""
        print_info "🚀 Application du tag sélectionné: $selected_tag"
    fi
    TAG_NAME="$selected_tag"
}

# Fonction pour vérifier si un tag correspond à un pattern donné
validate_tag_pattern() {
    local tag="$1"
    local pattern="$2"
    [[ "$tag" =~ $pattern ]]
}

# Fonction pour valider le format du tag
validate_tag() {
    if ! is_main_branch; then
        return 1
    fi

    local tag="$1"

    echo ""
    print_info "🔍 Validation du tag '$tag'..."

    if validate_tag_pattern "$tag" "$SEMANTIC_TAG_PATTERN"; then
        print_success "Tag de version sémantique valide: $tag"
        return 0
    elif validate_tag_pattern "$tag" "$TICKET_TAG_PATTERN"; then
        print_success "Tag de ticket valide: $tag"
        return 0
    elif validate_tag_pattern "$tag" "$PRERELEASE_TAG_PATTERN"; then
        print_warning "Tag de pré-release: $tag"
        return 0
    fi

    print_error "Format de tag non valide: $tag"
    print_tip "Formats acceptés:"
    echo "  - Tag sémantique: v1.2.3"
    echo "  - Tag de ticket: BACK-123.1, FRONT-456.2"
    echo "  - Pré-release: v1.2.3-alpha, v1.2.3-beta"
    return 1
}

# Fonction pour vérifier si le tag existe déjà
check_tag_exists() {
    local tag="$1"

    if git tag -l | grep -q "^$tag$"; then
        print_error "Le tag '$tag' existe déjà localement"
        return 1
    fi

    if git ls-remote --tags origin | grep -q "refs/tags/$tag$"; then
        print_error "Le tag '$tag' existe déjà sur le remote"
        return 1
    fi

    return 0
}

# Fonction de nettoyage automatique des tags temporaires
cleanup_temporary_tags() {
    echo ""
    print_info "🧹 Nettoyage des tags temporaires..."

    # Récupération des tags temporaires sur le dépôt local
    tmp_tags=$(git tag -l | grep -E "$TEMPORARY_TAG_CLEANUP_PATTERN" || true)
    
    if [ -z "$tmp_tags" ]; then
        print_success "Aucun tag temporaire à nettoyer"
        return 0
    fi

    local tag_count=$(echo "$tmp_tags" | wc -l | tr -d ' ')
    print_yellow "$tag_count tags temporaires détectés"
    
    # Affichage des premiers tags et du nombre restant éventuel
    echo "$tmp_tags" | head -5 | while read tag; do
        echo "     - $tag"
    done
    if [ $tag_count -gt 5 ]; then
        echo "     ... et $((tag_count - 5)) autres"
    fi

    print_info "Suppression des tags temporaires..."
    
    local deleted_count=0
    for tag in $tmp_tags; do
        echo "     Suppression du tag '$tag'"
        git tag -d "$tag" 2>/dev/null || true
        deleted_count=$((deleted_count + 1))
    done
    
    print_success "$deleted_count tags temporaires supprimés sur le dépôt local"

    print_info "Nettoyage des tags temporaires sur le dépôt distant..."
    local remote_tmp_tags=$(git ls-remote --tags origin | grep -E "$TEMPORARY_TAG_CLEANUP_PATTERN" | awk '{print $2}' | sed 's/refs\/tags\///' || true)

	if [ -z "$remote_tmp_tags" ]; then
		print_success "Aucun tag temporaire distant à nettoyer"
		return 0
	fi

	local remote_deleted_count=0
	for tag in $remote_tmp_tags; do
		echo "     Suppression du tag '$tag'"
		git push --delete origin "$tag" 2>/dev/null || print_warning  "Tag '$tag' déjà supprimé"
		remote_deleted_count=$((remote_deleted_count + 1))
	done

	print_success "$remote_deleted_count tags temporaires sur le dépôt distant"
}

# Fonction pour créer et pousser le tag
create_and_push_tag() {
    local tag="$1"
    local commit="$2"

    echo ""
    print_info "🏷️  Création du tag '$tag'..."

    # Vérifier que le commit existe
    if ! git rev-parse --verify "$commit" >/dev/null 2>&1; then
        print_error "Le commit '$commit' n'existe pas"
        return 1
    fi

    # Créer le tag
    git tag "$tag" "$commit" -m "Build tag $tag"
    print_success "Tag '$tag' créé localement"

    # Pousser le tag
    print_info "📤 Push du tag vers le remote..."
    git push origin "$tag"
    print_success "Tag '$tag' poussé sur le remote"
}

# Fonction pour afficher les statistiques finales
show_final_stats() {
    if is_main_branch; then
        echo ""
        print_info "📊 Statistiques finales:"
        total_tags=$(git tag -l | wc -l | tr -d ' ')
        temp_tags=$(git tag -l | grep -E "$TEMPORARY_TAG_CLEANUP_PATTERN" | wc -l | tr -d ' ')
        clean_tags=$((total_tags - temp_tags))

        echo "   Total des tags: $total_tags"
        echo "   Tags temporaires: $temp_tags"
        echo "   Tags propres: $clean_tags"

        if [ $temp_tags -eq 0 ]; then
            print_green "🎉 Dépôt parfaitement nettoyé !"
        fi
    fi
}

# MAIN EXECUTION

print_header "🏷️  Script intelligent de création de tags"
print_header "=========================================="

# Valider les arguments - rejeter toute option inconnue
FILTERED_ARGS=()
for arg in "$@"; do
    if [[ "$arg" =~ ^-- ]]; then
        print_error "Option inconnue: $arg"
        print_info "Ce script n'accepte aucune option."
        print_info "Usage:"
        echo "  $0                            # Mode interactif"
        echo "  $0 <tag-name>                 # Création directe à partir du commit actuel"
        echo "  $0 <tag-name> <commit-hash>   # Création directe à partir d'un commit spécifique"
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

    # Si on est sur une branche secondaire et qu'un tag est fourni en ligne de commande
    if [ ! -z "$TAG_NAME" ] && ! is_main_branch; then
        echo ""
        print_info "🔍 Validation du tag '$TAG_NAME'..."

        if ! [[ "$TAG_NAME" =~ $TEMPORARY_TAG_PATTERN ]]; then
            print_error "Format de tag non valide: $TAG_NAME"
            print_tip "Format accepté:"
            echo "  - Tag temporaire: v1.2.3_NOM_BRANCHE.1"
            print_tip "Seuls les tags temporaires sont autorisés sur les branches secondaires"
            print_tip "Utilisez le mode interactif pour créer un tag temporaire"
            exit 1
        fi
    fi
fi

# Vérification que nous sommes dans un dépôt Git
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Erreur: Ce script doit être exécuté dans un dépôt Git"
    exit 1
fi

if ! validate_tag "$TAG_NAME"; then
    exit 1
fi

# 2. Vérifier que le tag n'existe pas déjà
if ! check_tag_exists "$TAG_NAME"; then
    exit 1
fi

# 3. Créer et pousser le tag
COMMIT_HASH="${FILTERED_ARGS[1]:-$DEFAULT_COMMIT}"
if ! create_and_push_tag "$TAG_NAME" "$COMMIT_HASH"; then
    exit 1
fi

# 4. Nettoyage automatique (uniquement sur les branches principales)
if is_main_branch; then
    cleanup_temporary_tags
fi

# 5. Afficher les statistiques finales
show_final_stats

echo ""
print_green "🎉 Tag '$TAG_NAME' créé avec succès !"

if is_main_branch; then
    print_info "Le dépôt a été automatiquement nettoyé des tags temporaires."

    # Message de bonnes pratiques pour les branches principales
    echo ""
    print_tip "Bonnes pratiques:"
    echo "   - Utilisez ce script pour créer tous vos tags"
    echo "   - Évitez 'git tag' et 'git push --tags' directement"
    echo "   - Le nettoyage automatique maintient un dépôt propre"
else
    # Message simplifié pour les branches secondaires
    print_success "Tag temporaire créé pour déployer le développement sur cette branche."
fi
