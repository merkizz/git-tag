#!/usr/bin/env bash

# === Variables ===
COMMAND_NAME="create-tag"            # Command name
SOURCE_SCRIPT="$(pwd)/create-tag.sh" # Source script (inside your project)
TARGET_DIR="$HOME/bin"

# === Step 0: Detect user shell ===
CURRENT_SHELL="$(basename "$SHELL")"

if [ "$CURRENT_SHELL" = "zsh" ]; then
	SHELL_RC="$HOME/.zshrc"
elif [ "$CURRENT_SHELL" = "bash" ]; then
	if [ "$(uname)" = "Darwin" ]; then
		SHELL_RC="$HOME/.bash_profile"
	else
		SHELL_RC="$HOME/.bashrc"
	fi
else
	echo "⚠️  Unsupported shell: $CURRENT_SHELL"
	echo "   Please edit the script and set SHELL_RC manually."
	exit 1
fi

install_script() {
	TARGET_PATH="$TARGET_DIR/$COMMAND_NAME"

	echo "🔎 Installing $COMMAND_NAME..."

	# Step 1: Create ~/bin if needed
	if [ ! -d "$TARGET_DIR" ]; then
		echo "📂 Creating directory $TARGET_DIR..."
		mkdir -p "$TARGET_DIR"
	fi

	# Step 2: Create the symbolic link
	if [ -L "$TARGET_PATH" ] || [ -f "$TARGET_PATH" ]; then
		echo "⚠️  $TARGET_PATH already exists. Removing..."
		rm -f "$TARGET_PATH"
	fi

	ln -s "$SOURCE_SCRIPT" "$TARGET_PATH"
	chmod +x "$SOURCE_SCRIPT"
	echo "✅ Script linked to $TARGET_PATH"

	# Step 3: Add ~/bin to PATH if needed
	if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$SHELL_RC"; then
		echo 'export PATH="$HOME/bin:$PATH"' >>"$SHELL_RC"
		echo "✅ Added ~/bin to PATH in $SHELL_RC"
	else
		echo "ℹ️  ~/bin is already in your PATH"
	fi

	# Step 4: Reload shell config
	echo "🔄 Reloading $SHELL_RC..."
	# shellcheck disable=SC1090
	source "$SHELL_RC"

	echo "🎉 Installation complete! You can now run the command: $COMMAND_NAME"
}

uninstall_script() {
	TARGET_PATH="$TARGET_DIR/$COMMAND_NAME"

	echo "🗑️ Uninstalling $COMMAND_NAME..."

	if [ -L "$TARGET_PATH" ] || [ -f "$TARGET_PATH" ]; then
		rm -f "$TARGET_PATH"
		echo "✅ Removed $TARGET_PATH"
	else
		echo "ℹ️  No installed script found at $TARGET_PATH"
	fi

	echo "⚠️  Note: This does NOT remove ~/bin from your PATH."
	echo "   If you want to fully clean up, remove this line manually from $SHELL_RC:"
	echo '   export PATH="$HOME/bin:$PATH"'

	echo "🎉 Uninstallation complete."
}

show_help() {
	echo "📖 Usage: $0 [OPTION]"
	echo ""
	echo "Options:"
	echo "  --i                 Install the script (default if no option is provided)"
	echo "  --u                 Uninstall the script"
	echo "  --name <new_name>   Override the default command name (default: '$COMMAND_NAME')"
	echo "  --h                 Show this help message"
	echo ""
	echo "Examples:"
	echo "  $0 --i                   Install with default name ('$COMMAND_NAME')"
	echo "  $0 --i --name my-cmd     Install with custom name 'my-cmd'"
	echo "  $0 --u                   Uninstall (uses the last chosen name)"
}

# === Parse Arguments ===
ACTION=""
while [[ $# -gt 0 ]]; do
	case "$1" in
	--i)
		ACTION="install"
		shift
		;;
	--u)
		ACTION="uninstall"
		shift
		;;
	--name)
		COMMAND_NAME="$2"
		shift 2
		;;
	--h)
		show_help
		exit 0
		;;
	*)
		echo "❌ Unknown option: $1"
		show_help
		exit 1
		;;
	esac
done

# === Default action (install) if no explicit choice ===
if [ -z "$ACTION" ]; then
	ACTION="install"
fi

# === Run ===
if [ "$ACTION" = "install" ]; then
	install_script
elif [ "$ACTION" = "uninstall" ]; then
	uninstall_script
fi
