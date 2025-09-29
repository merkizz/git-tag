#!/bin/bash

#  Smart tool to create Git tags with built-in automatic cleanup
# Usage: ./create-tag.sh [tag-name] [commit-hash]

set -e

readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[1;36m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_ORANGE='\033[1;33m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_NONE='\033[0m'

readonly DEFAULT_COMMIT="HEAD"
readonly DEFAULT_MAJOR_VERSION="v1.0.0"
readonly DEFAULT_MINOR_VERSION="v0.1.0"

# Tag patterns
# SEMANTIC_VERSION_TAG_PATTERN: Semantic version vX.Y.Z (ex: v1.0.0)
# TICKET_TAG_PATTERN: Project ticket (ex: BACK-123.1)
# PRERELEASE_TAG_PATTERN: Pre-release (ex: v1.2.3-alpha)
# TEMPORARY_TAG_PATTERN: Temporary tag (ex: v1.2.3_FRONT-123.1)
# TEMPORARY_TAG_CLEANUP_PATTERN: Pattern to identify temporary tags to cleanup

readonly SEMANTIC_VERSION_TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+$'
readonly TICKET_TAG_PATTERN='^(BACK|FRONT)-[0-9]+\.[0-9]+$'
readonly PRERELEASE_TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+-[a-z]+$'
readonly TEMPORARY_TAG_PATTERN='^v[0-9]+\.[0-9]+\.[0-9]+_.+\.[0-9]+$'
readonly TEMPORARY_TAG_CLEANUP_PATTERN='_.*\.|_[A-Z]+-[0-9]+$'

readonly BRANCH_MASTER="master"
readonly BRANCH_MAIN="main"

print_blue() {
	echo -e "${COLOR_BLUE}$1${COLOR_NONE}"
}

print_cyan() {
	echo -e "${COLOR_CYAN}$1${COLOR_NONE}"
}

print_green() {
	echo -e "${COLOR_GREEN}$1${COLOR_NONE}"
}

print_orange() {
	echo -e "${COLOR_ORANGE}$1${COLOR_NONE}"
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
	print_green " ✅ $1"
}

print_warning() {
	print_orange "⚠️  $1"
}

print_error() {
	print_red " ❌ $1"
}

print_tip() {
	print_yellow "💡  $1"
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
	print_info "\n$1  $2"
}

get_latest_semantic_tag() {
	git tag -l | grep -E "$SEMANTIC_VERSION_TAG_PATTERN" | sort -V | tail -1
}

get_current_branch() {
	git branch --show-current
}

is_main_branch() {
	local branch=$(get_current_branch)
	[[ "$branch" == "$BRANCH_MASTER" || "$branch" == "$BRANCH_MAIN" ]]
}

# Find the latest semantic tag on the main branch from which the current branch has diverged
get_branch_base_tag() {
	local current_branch=$(get_current_branch)
	local main_branch="$BRANCH_MASTER"

	# Check if master exists, otherwise use main
	if ! git show-ref --verify --quiet refs/heads/master; then
		if git show-ref --verify --quiet refs/heads/main; then
			main_branch="$BRANCH_MAIN"
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
	local latest_base_tag=$(git tag -l --merged "$base_commit" | grep -E "$SEMANTIC_VERSION_TAG_PATTERN" | sort -V | tail -1)

	if [ -z "$latest_base_tag" ]; then
		# If no tag is found at the base point, use the latest semantic tag
		get_latest_semantic_tag
	else
		echo "$latest_base_tag"
	fi
}

get_next_temp_suffix() {
	local latest_base_tag="$1"
	local branch="$2"
	local suffix=1

	while git tag -l | grep -q "^${latest_base_tag}_${branch}\.${suffix}$"; do
		((suffix++))
	done

	echo "$suffix"
}

get_last_temp_tag() {
	local base_tag="$1"
	local branch="$2"
	local last_suffix=$(($(get_next_temp_suffix "$base_tag" "$branch") - 1))

	if [ "$last_suffix" -gt 0 ]; then
		echo "${base_tag}_${branch}.${last_suffix}"
	else
		echo ""
	fi
}

run_interactive_mode() {
	echo ""

	local current_branch=$(get_current_branch)
	local current_branch_is_main=$(is_main_branch && echo "true" || echo "false")
	local latest_tag=$(get_latest_semantic_tag)
	local selected_tag=""

	print_yellow "Current branch: ${COLOR_CYAN}$current_branch${COLOR_NONE}"

	if is_main_branch; then
		if [ -z "$latest_tag" ]; then
			print_yellow "No tag found"
			print_step "Select an option (1-3) or C to cancel:"
			print_option "1" "Development" "$DEFAULT_MINOR_VERSION"
			print_option "2" "Release" "$DEFAULT_MAJOR_VERSION"
			print_option "3" "Enter tag manually"
			read -p ": " choice
			case $choice in
			1)
				selected_tag="$DEFAULT_MINOR_VERSION"
				print_success "Selected tag: $selected_tag (development)"
				;;
			2)
				selected_tag="$DEFAULT_MAJOR_VERSION"
				print_success "Selected tag: $selected_tag (release)"
				;;
			3)
				print_blue "Enter tag:"
				read -r custom_tag
				if [ -z "$custom_tag" ]; then
					print_error "Empty tag, tag creation cancelled"
					exit 1
				fi
				selected_tag="$custom_tag"
				;;
			C)
				print_yellow "🚫  Tag creation cancelled."
				exit 0
				;;
			*)
				print_error "Invalid option, tag creation cancelled"
				exit 1
				;;
			esac
		else
			# Calculate next versions
			local version_digits=$(echo "$latest_tag" | sed 's/^v//' | tr '.' ' ')
			local patch=$(echo $version_digits | awk '{print $3}')
			local minor=$(echo $version_digits | awk '{print $2}')
			local major=$(echo $version_digits | awk '{print $1}')
			local next_patch="v$major.$minor.$((patch + 1))"
			local next_minor="v$major.$((minor + 1)).0"
			local next_major="v$((major + 1)).0.0"

			print_yellow "Latest tag: ${COLOR_CYAN}$latest_tag${COLOR_NONE}"
			print_step "Select an option (1-4) or C to cancel:"
			print_option "1" "Patch - Bug fixes" "$next_patch"
			print_option "2" "Minor - New features" "$next_minor"
			print_option "3" "Major - Breaking changes" "$next_major"
			print_option "4" "Enter tag manually"
			read -p ": " choice
			case $choice in
			1)
				selected_tag="$next_patch"
				print_success "Selected tag: $selected_tag (patch)"
				;;
			2)
				selected_tag="$next_minor"
				print_success "Selected tag: $selected_tag (minor)"
				;;
			3)
				selected_tag="$next_major"
				print_success "Selected tag: $selected_tag (major)"
				;;
			4)
				print_blue "Enter tag:"
				read -r custom_tag
				if [ -z "$custom_tag" ]; then
					print_error "Empty tag, operation cancelled"
					exit 1
				fi
				selected_tag="$custom_tag"
				print_success "Selected tag: $selected_tag"
				;;
			C)
				print_yellow "🚫  Tag creation cancelled."
				exit 0
				;;
			*)
				print_error "Invalid option, tag creation cancelled"
				exit 1
				;;
			esac
		fi
	else
		local latest_base_tag=$(get_branch_base_tag)
		local next_suffix=$(get_next_temp_suffix "$latest_base_tag" "$current_branch")
		local last_temp_tag=$(get_last_temp_tag "$latest_base_tag" "$current_branch")
		local next_tmp_tag="${latest_base_tag}_${current_branch}.${next_suffix}"

		print_yellow "Latest tag: ${COLOR_CYAN}$latest_tag${COLOR_NONE}"
		print_yellow "Latest base tag for this branch: ${COLOR_CYAN}$latest_base_tag${COLOR_NONE}"
		if [ ! -z "$last_temp_tag" ]; then
			print_yellow "Latest temporary tag for this branch: ${COLOR_CYAN}$last_temp_tag${COLOR_NONE}"
		fi

		echo ""
		print_tip "On a feature branch, only temporary tags are allowed. Final tags should be created on the main branch after merge."
		print_step "Enter V to create the following tag or C to cancel:"
		echo -e "   Temporary - Feature development ${COLOR_CYAN}$next_tmp_tag${COLOR_NONE}"
		read -p ": " choice
		case $choice in
		V)
			selected_tag="$next_tmp_tag"
			print_success "Selected tag: $selected_tag"
			;;
		C)
			print_yellow "🚫  Tag creation cancelled."
			exit 0
			;;
		*)
			print_error "Invalid option, tag creation cancelled"
			exit 1
			;;
		esac
	fi

	# Ensure the branch has not changed before the selection
	local current_branch_after=$(get_current_branch)
	local current_branch_is_main_after=$(is_main_branch && echo "true" || echo "false")

	if [ "$current_branch" != "$current_branch_after" ] || [ "$current_branch_is_main" != "$current_branch_is_main_after" ]; then
		print_error "The branch changed while the script was running!"
		print_red "Initial branch: $current_branch (main: $current_branch_is_main)"
		print_red "Current branch: $current_branch_after (main: $current_branch_is_main_after)"
		print_warning "You need to rerun the script on the current branch."
		exit 1
	fi

	TAG_NAME="$selected_tag"
}

validate_tag_pattern() {
	local tag="$1"
	local pattern="$2"
	[[ "$tag" =~ $pattern ]]
}

validate_tag() {
	local tag="$1"

	print_step "👮🏻‍♂️" "Validating tag $tag..."

	if validate_tag_pattern "$tag" "$SEMANTIC_VERSION_TAG_PATTERN"; then
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
	echo "   - Semantic version tag: v1.2.3"
	echo "   - Ticket tag: BACK-123.1, FRONT-456.2"
	echo "   - Pre-release tag: v1.2.3-alpha, v1.2.3-beta"
	return 1
}

check_tag_exists() {
	local tag="$1"

	if git tag -l | grep -q "^$tag$"; then
		print_error "The tag $tag already exists locally"
		return 1
	fi

	if git ls-remote --tags origin | grep -q "refs/tags/$tag$"; then
		print_error "The tag $tag already exists on the remote"
		return 1
	fi

	return 0
}

create_and_push_tag() {
	local tag="$1"
	local commit="$2"

	print_step "🏷" "Creating tag $tag..."

	if ! git rev-parse --verify "$commit" >/dev/null 2>&1; then
		print_error "Commit '$commit' does not exist"
		return 1
	fi

	git tag "$tag" "$commit" -m "Build tag $tag"
	print_success "Tag created locally"

	if git remote | grep -q origin; then
		# Check if current branch exists on remote
		local current_branch=$(get_current_branch)
		local branch_exists_on_remote=$(git ls-remote --heads origin "$current_branch" | wc -l | tr -d ' ')

		# Push branch to remote if it doesn't exist there yet
		if [ "$branch_exists_on_remote" -eq "0" ]; then
			print_info "Branch $current_branch does not exist on remote, pushing it first..."
			if git push -u origin "$current_branch" >/dev/null 2>&1; then
				print_success "Branch $current_branch pushed to the remote repository"
			else
				print_warning "Failed to push branch $current_branch to the remote repository"
				return 1
			fi
		fi

		# Push the tag
		if git push origin "$tag" >/dev/null 2>&1; then
			print_success "Tag pushed to the remote repository"
		else
			print_warning "Failed to push tag to the remote repository"
			return 1
		fi
	else
		print_info "No 'origin' remote configured, tag not pushed"
	fi
}

cleanup_temporary_tags() {
	print_step "🧹" "Cleaning up temporary tags..."

	tmp_tags=$(git tag -l | grep -E "$TEMPORARY_TAG_CLEANUP_PATTERN" || true)

	if [ -z "$tmp_tags" ]; then
		print_success "No temporary tags to clean up"
		return 0
	fi

	local tag_count=$(echo "$tmp_tags" | wc -l | tr -d ' ')
	print_yellow "$tag_count temporary tags detected"

	echo "$tmp_tags" | head -5 | while read tag; do
		echo "   $tag"
	done
	if [ $tag_count -gt 5 ]; then
		echo "   ... and $((tag_count - 5)) more"
	fi

	local active_branches=$(git branch | sed 's/^[ *]*//' | tr '\n' '|' | sed 's/|$//')

	echo ""
	print_yellow "Deleting temporary tags on the local repository..."

	local deleted_count=0
	for tag in $tmp_tags; do
		local branch_name=$(echo "$tag" | grep -o "_[^.]*" | sed 's/^_//')
		if [[ -n "$branch_name" ]] && [[ "$active_branches" =~ "$branch_name" ]]; then
			continue
		fi

		git tag -d "$tag" 2>/dev/null || true
		deleted_count=$((deleted_count + 1))
	done

	print_success "$deleted_count tags deleted from the local repository"

	echo ""
	print_yellow "Deleting temporary tags on the remote repository..."

	local remote_tmp_tags=$(git ls-remote --tags origin | grep -v "\^{}" | awk '{print $2}' | sed 's/refs\/tags\///' | grep -E "$TEMPORARY_TAG_CLEANUP_PATTERN" || true)

	if [ -z "$remote_tmp_tags" ]; then
		print_success "No temporary tags to clean up on the remote repository"
		return 0
	fi

	local remote_deleted_count=0
	for tag in $remote_tmp_tags; do
		local branch_name=$(echo "$tag" | grep -o "_[^.]*" | sed 's/^_//')
		if [[ -n "$branch_name" ]] && [[ "$active_branches" =~ "$branch_name" ]]; then
			continue
		fi

		if git push --delete origin "$tag" 2>/dev/null; then
			remote_deleted_count=$((remote_deleted_count + 1))
		else
			print_warning "Failed to delete tag $tag"
		fi
	done

	print_success "$remote_deleted_count temporary tags deleted from the remote repository"
}

analyze_tag_inventory() {
	print_step "📊" "Analyzing tag inventory..."

	local total_tags=$(git tag -l | wc -l | tr -d ' ')
	local tmp_tags=$(git tag -l | grep -E "$TEMPORARY_TAG_CLEANUP_PATTERN" | wc -l | tr -d ' ')
	local clean_tags=$((total_tags - tmp_tags))

	echo "   Total tags: $total_tags"
	echo "   Temporary tags: $tmp_tags"
	echo "   Clean tags: $clean_tags"

	if [ $tmp_tags -eq 0 ]; then
		print_success "The repository is perfectly cleaned up!"
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
if ! git rev-parse --git-dir >/dev/null 2>&1; then
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
		print_step "🔍" "Validating tag $TAG_NAME..."

		if ! [[ "$TAG_NAME" =~ $TEMPORARY_TAG_PATTERN ]]; then
			print_error "Invalid tag format: $TAG_NAME"
			print_tip "Accepted format:"
			echo "   - Temporary tag: v1.2.3_BRANCH_NAME.1"
			print_tip "Only temporary tags are allowed on feature branches"
			print_tip "It's recommended to use the interactive mode to create a temporary tag"
			exit 1
		fi
	fi
fi

# 1. Validate the tag
if is_main_branch; then
	if ! validate_tag "$TAG_NAME"; then
		exit 1
	fi
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
	analyze_tag_inventory
fi

print_yellow "\n🎉  Tag $TAG_NAME created successfully!"

echo ""
print_tip "Good practices:"
echo "   - Use this script to create all your tags"
echo "   - Avoid using 'git tag' and 'git push --tags' directly"
echo "   - Automatic cleanup keeps the repository clean"
