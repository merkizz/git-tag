#!/bin/bash

#  Script tool to create Git tags with built-in automatic cleanup
# Usage: ./create-tag.sh [tag-name] [commit-hash]

set -e

readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[1;36m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_NONE='\033[0m'

readonly DEFAULT_COMMIT="HEAD"
readonly DEFAULT_MAJOR_VERSION="v1.0.0"
readonly DEFAULT_MINOR_VERSION="v0.1.0"

readonly SEMANTIC_TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+$'
readonly TICKET_TAG_PATTERN='^(BACK|FRONT|CMP|CNS|PRTL)-[0-9]+\.[0-9]+$'
readonly PRERELEASE_TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+-[a-z]+$'
readonly TEMPORARY_TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+_.+\.[0-9]+$'
readonly TEMPORARY_TAG_CLEANUP_PATTERN='_.*\.|_[A-Z]+-[0-9]+$'

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

print_step() {
	print_info "\n$1"
}

get_latest_semantic_tag() {
    git tag -l | grep -E "$SEMANTIC_TAG_PATTERN" | sort -V | tail -1
}

get_current_branch() {
    git branch --show-current
}

is_main_branch() {
    local branch=$(get_current_branch)
    [[ "$branch" == "master" || "$branch" == "main" || "$branch" == "develop" ]]
}

# Find the latest semantic tag on the main branch from which the current branch has diverged
get_current_branch_base_tag() {
    local current_branch=$(get_current_branch)
    local main_branch="master"

    # Check if master exists, otherwise use main
    if ! git show-ref --verify --quiet refs/heads/master; then
        if git show-ref --verify --quiet refs/heads/main; then
            main_branch="main"
        else
            # Fallback to the latest semantic tag if no main branch is found
            get_latest_semantic_tag
            return
        fi
    fi

    # Find the base commit (merge-base) between the current branch and master/main
    local base_commit=$(git merge-base "$current_branch" "$main_branch" 2>/dev/null || echo "")

    if [ -z "$base_commit" ]; then
        # If no merge-base is found, use the latest semantic tag
        get_latest_semantic_tag
        return
    fi

    # Find the latest semantic tag that contains this base commit
    local base_tag=$(git tag -l --merged "$base_commit" | grep -E "$SEMANTIC_TAG_PATTERN" | sort -V | tail -1)

    if [ -z "$base_tag" ]; then
        # If no tag is found at the base point, use the latest semantic tag
        get_latest_semantic_tag
    else
        echo "$base_tag"
    fi
}

get_tmp_tag_next_suffix() {
    local base_tag="$1"
    local branch="$2"
    local suffix=1

    while git tag -l | grep -q "^${base_tag}_${branch}\.${suffix}$"; do
        ((suffix++))
    done

    echo "$suffix"
}

display_options() {
    local current_branch=$(get_current_branch)

    print_yellow "Current branch: ${COLOR_BLUE}$current_branch${COLOR_NONE}"

    if is_main_branch; then
        local latest_tag=$(get_latest_semantic_tag)
        if [ -z "$latest_tag" ]; then
            print_yellow "No semantic tag found"
            print_yellow "Version to create:"
            print_option "1" "First version" "v1.0.0"
            print_option "2" "Development version" "v0.1.0"
            print_option "3" "Enter manually"
            print_option "4" "Cancel"
            return 0
        fi

        # Calculate next versions
        local version_digits=$(echo "$latest_tag" | sed 's/^v//' | tr '.' ' ')
        local patch=$(echo $version_digits | awk '{print $3}')
        local minor=$(echo $version_digits | awk '{print $2}')
        local major=$(echo $version_digits | awk '{print $1}')
        local next_patch="v$major.$minor.$((patch + 1))"
        local next_minor="v$major.$((minor + 1)).0"
        local next_major="v$((major + 1)).0.0"

        print_yellow "Latest tag: ${COLOR_BLUE}$latest_tag${COLOR_NONE}"
        print_yellow "Version to create:"
        print_option "1" "Patch - Bug fixes" "$next_patch"
        print_option "2" "Minor - New features" "$next_minor"
        print_option "3" "Major - Breaking changes" "$next_major"
        print_option "4" "Enter manually"
        print_option "5" "Cancel"
    else
        local base_tag=$(get_current_branch_base_tag)
        local next_suffix=$(get_tmp_tag_next_suffix "$base_tag" "$current_branch")
        local temp_tag="${base_tag}_${current_branch}.${next_suffix}"

        print_yellow "Version to create:"
        print_option "1" "Temporary tag (based on $base_tag)" "$temp_tag"
        print_option "2" "Cancel"
        echo ""
        print_tip "On a feature branch, only temporary tags are allowed. Final tags should be created on the main branch after merging"
    fi
}

run_interactive_mode() {
    echo ""

    display_options

    local current_branch=$(get_current_branch)
    local latest_tag=$(get_latest_semantic_tag)
    local selected_tag=""

    echo ""

    local initial_branch=$(get_current_branch)
    local initial_is_main=$(is_main_branch && echo "true" || echo "false")

    if [ -z "$latest_tag" ]; then
        read -p "Select an option (1-4): " choice
        if [ "$choice" = "4" ]; then
            print_yellow "🚫 Tag creation cancelled."
            return 1
        fi
    else
        if is_main_branch; then
            read -p "Select an option (1-5): " choice
        else
            read -p "Select an option (1-2): " choice
        fi
    fi

	# Ensure the branch has not changed before the selection
    local current_branch_after=$(get_current_branch)
    local current_is_main_after=$(is_main_branch && echo "true" || echo "false")

    if [ "$initial_branch" != "$current_branch_after" ] || [ "$initial_is_main" != "$current_is_main_after" ]; then
        print_error "The branch changed while the script was running!"
        print_red "Initial branch: $initial_branch (main: $initial_is_main)"
        print_red "Current branch: $current_branch_after (main: $current_is_main_after)"
        print_warning "You need to rerun the script on the current branch."
        exit 1
    fi

    if [ ! -z "$latest_tag" ]; then
        local version_digits=$(echo "$latest_tag" | sed 's/^v//' | tr '.' ' ')
        local major=$(echo $version_digits | awk '{print $1}')
        local minor=$(echo $version_digits | awk '{print $2}')
        local patch=$(echo $version_digits | awk '{print $3}')
        local next_patch="v$major.$minor.$((patch + 1))"
        local next_minor="v$major.$((minor + 1)).0"
        local next_major="v$((major + 1)).0.0"
        local temp_patch="${next_patch}_${current_branch}.1"

        if is_main_branch; then
            case $choice in
                1)
                    selected_tag="$next_patch"
                    print_success "Selected: $selected_tag (patch)"
                    ;;
                2)
                    selected_tag="$next_minor"
                    print_success "Selected: $selected_tag (minor)"
                    ;;
                3)
                    selected_tag="$next_major"
                    print_success "Selected: $selected_tag (major)"
                    ;;
                4)
                    echo ""
                    print_yellow "Enter version number (format: vX.Y.Z): "
                    read -r custom_tag
                    if [ -z "$custom_tag" ]; then
                        print_error "Empty tag, operation cancelled"
                        exit 1
                    fi
                    selected_tag="$custom_tag"
                    ;;
                5)
                    print_yellow "🚫 Tag creation cancelled."
                    exit 0
                    ;;
                *)
                    print_error "Invalid option, operation cancelled"
                    exit 1
                    ;;
            esac
        else
            local base_tag=$(get_current_branch_base_tag)
            local next_suffix=$(get_tmp_tag_next_suffix "$base_tag" "$current_branch")
            local temp_tag="${base_tag}_${current_branch}.${next_suffix}"

            case $choice in
                1)
                    selected_tag="$temp_tag"
                    print_success "Selected: $selected_tag"
                    ;;
                2)
                    print_yellow "🚫 Tag creation cancelled."
                    exit 0
                    ;;
                *)
                    print_error "Invalid option, operation cancelled"
                    exit 1
                    ;;
            esac
        fi
    else
        case $choice in
            1)
                selected_tag="$DEFAULT_MAJOR_VERSION"
                print_success "Selected: $selected_tag (first version)"
                ;;
            2)
                selected_tag="$DEFAULT_MINOR_VERSION"
                print_success "Selected: $selected_tag (development version)"
                ;;
            3)
                echo ""
                print_yellow "Enter version number (format: vX.Y.Z): "
                read -r custom_tag
                if [ -z "$custom_tag" ]; then
                    print_error "Empty tag, operation cancelled"
                    exit 1
                fi
                selected_tag="$custom_tag"
                ;;
            *)
                print_error "Invalid option, operation cancelled"
                exit 1
                ;;
        esac
    fi

    if is_main_branch; then
        print_step "🚀 Applying selected tag: $selected_tag"
    fi
    TAG_NAME="$selected_tag"
}

validate_tag_pattern() {
    local tag="$1"
    local pattern="$2"
    [[ "$tag" =~ $pattern ]]
}

validate_tag() {
    if ! is_main_branch; then
        return 1
    fi

    local tag="$1"

    print_step "🔍 Validating tag '$tag'..."

    if validate_tag_pattern "$tag" "$SEMANTIC_TAG_PATTERN"; then
        print_success "Valid semantic version tag: $tag"
        return 0
    elif validate_tag_pattern "$tag" "$TICKET_TAG_PATTERN"; then
        print_success "Valid ticket tag: $tag"
        return 0
    elif validate_tag_pattern "$tag" "$PRERELEASE_TAG_PATTERN"; then
        print_success "Valid pre-release tag: $tag"
        return 0
    fi

    print_error "Invalid tag format: $tag"
    print_tip "Accepted formats:"
    echo "  - Semantic version tag: v1.2.3"
    echo "  - Ticket tag: BACK-123.1, FRONT-456.2"
    echo "  - Pre-release tag: v1.2.3-alpha, v1.2.3-beta"
    return 1
}

check_tag_exists() {
    local tag="$1"

    if git tag -l | grep -q "^$tag$"; then
        print_error "Tag '$tag' already exists locally"
        return 1
    fi

    if git ls-remote --tags origin | grep -q "refs/tags/$tag$"; then
        print_error "Tag '$tag' already exists on the remote"
        return 1
    fi

    return 0
}

create_and_push_tag() {
    print_step "🏷️  Creating tag '$tag'..."

    local tag="$1"
    local commit="$2"

    if ! git rev-parse --verify "$commit" >/dev/null 2>&1; then
        print_error "Commit '$commit' does not exist"
        return 1
    fi

    git tag "$tag" "$commit" -m "Build tag $tag"
    print_success "Tag '$tag' created locally"

    if git remote | grep -q origin; then
        print_step "📤 Pushing tag to the remote repository..."

        if git push origin "$tag" >/dev/null 2>&1; then
            print_success "Tag '$tag' pushed successfully"
        else
            print_warning "Failed to push tag '$tag'"
        fi
    else
        print_info "No 'origin' remote configured, tag not pushed"
    fi
}

cleanup_temporary_tags() {
    print_step "🧹 Cleaning up temporary tags..."

    tmp_tags=$(git tag -l | grep -E "$TEMPORARY_TAG_CLEANUP_PATTERN" || true)
    
    if [ -z "$tmp_tags" ]; then
        print_success "No temporary tags to clean up"
        return 0
    fi

    local tag_count=$(echo "$tmp_tags" | wc -l | tr -d ' ')
    print_yellow "$tag_count temporary tags detected"
    
    echo "$tmp_tags" | head -5 | while read tag; do
        echo "     - $tag"
    done
    if [ $tag_count -gt 5 ]; then
        echo "     ... and $((tag_count - 5)) more"
    fi

    print_info "Deleting temporary tags..."
    
    local deleted_count=0
    for tag in $tmp_tags; do
        echo "     Deleting tag '$tag'"
        git tag -d "$tag" 2>/dev/null || true
        deleted_count=$((deleted_count + 1))
    done
    
    print_success "$deleted_count temporary tags deleted from the local repository"

    print_info "Cleaning up temporary tags on the remote repository..."
    local remote_tmp_tags=$(git ls-remote --tags origin | grep -E "$TEMPORARY_TAG_CLEANUP_PATTERN" | awk '{print $2}' | sed 's/refs\/tags\///' || true)

	if [ -z "$remote_tmp_tags" ]; then
		print_success "No temporary tags to clean up on the remote repository"
		return 0
	fi

	local remote_deleted_count=0
	for tag in $remote_tmp_tags; do
		echo "     Deleting tag '$tag'"
		git push --delete origin "$tag" 2>/dev/null || print_warning  "Tag '$tag' already deleted"
		remote_deleted_count=$((remote_deleted_count + 1))
	done

	print_success "$remote_deleted_count temporary tags deleted from the remote repository"
}

show_tag_inventory() {
	print_step "📊 Display tag inventory..."

	total_tags=$(git tag -l | wc -l | tr -d ' ')
	tmp_tags=$(git tag -l | grep -E "$TEMPORARY_TAG_CLEANUP_PATTERN" | wc -l | tr -d ' ')
	clean_tags=$((total_tags - tmp_tags))

	echo "   Total tags: $total_tags"
	echo "   Temporary tags: $tmp_tags"
	echo "   Clean tags: $clean_tags"

	if [ $tmp_tags -eq 0 ]; then
		print_green "🎉 The repository is perfectly cleaned up!"
	fi
}

# MAIN EXECUTION

print_header "🏷️  Git tag creation script"
print_header "=========================================="

# Validate arguments and reject any option
FILTERED_ARGS=()
for arg in "$@"; do
    if [[ "$arg" =~ ^-- ]]; then
        print_error "Unknown option: $arg"
        print_info "This script does not accept any options."
        print_info "Usages:"
        echo "  $0                            # Interactive mode"
        echo "  $0 <tag-name>                 # Create tag from current commit"
        echo "  $0 <tag-name> <commit-hash>   # Create tag from specific commit"
        exit 1
    else
        FILTERED_ARGS+=("$arg")
    fi
done

# Check that we're in a Git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "This script must be run in a Git repository!"
    exit 1
fi

# Run interactive mode if no tag is provided
if [ ${#FILTERED_ARGS[@]} -lt 1 ]; then
    run_interactive_mode
fi

if [ -z "$TAG_NAME" ]; then
	TAG_NAME="${FILTERED_ARGS[0]}"

    # If we're on a feature branch and a tag is provided via command line
    if [ ! -z "$TAG_NAME" ] && ! is_main_branch; then
        print_step "🔍 Validation of the tag '$TAG_NAME'..."

        if ! [[ "$TAG_NAME" =~ $TEMPORARY_TAG_PATTERN ]]; then
            print_error "Invalid tag format: $TAG_NAME"
            print_tip "Accepted format:"
            echo "  - Temporary tag: v1.2.3_BRANCH_NAME.1"
            print_tip "Only temporary tags are allowed on feature branches"
            print_tip "It's recommenaded to use the interactive mode to create a temporary tag"
            exit 1
        fi
    fi
fi

# 1. Validate the tag
if ! validate_tag "$TAG_NAME"; then
    exit 1
fi

# 2. Check that the tag doesn't exist
if ! check_tag_exists "$TAG_NAME"; then
    exit 1
fi

# 3. Create and push the tag
COMMIT_HASH="${FILTERED_ARGS[1]:-$DEFAULT_COMMIT}"
if ! create_and_push_tag "$TAG_NAME" "$COMMIT_HASH"; then
    exit 1
fi

# 4. Clean temporary tags (only on the main branch)
if is_main_branch; then
    cleanup_temporary_tags
fi

# 5. Display tag inventory (only on the main branch)
if is_main_branch; then
	show_tag_inventory
fi

echo ""
print_green "🎉 Tag '$TAG_NAME' created successfully!"

echo ""
print_tip "Good practices:"
echo "   - Use this script to create all your tags"
echo "   - Avoid using 'git tag' and 'git push --tags' directly"
echo "   - Automatic cleanup keeps the repository clean"