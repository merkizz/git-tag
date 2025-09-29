# Git Tag

`create-tag` is an advanced tool for creating and managing Git tags with smart version management features.

## Features

- 🏷️ Create version tags (`vX.Y.Z`)
- 💡 Incremental version suggestions (patch, minor, major)
- 🪾 Create temporary tags on feature branches (`vX.Y.Z_BRANCH.N`)
- 🧹 Automatic cleanup of temporary tags
- 🔍 Tag format validation
- 🔄 Synchronize tags between main branches (main/master) and feature branches

## Requirements

- Bash 4.0 or higher
- Git 2.0 or higher

## Installation

1. Clone this repository
2. Run the installation script:
   ```bash
   ./install.sh
   ```
   The `create-tag` command will be installed and available in your shell.
3. If you want to define a different command name, use the `--name` option:
   ```bash
   ./install.sh --name my-create-tag
   ```
4. To uninstall the command:
   ```bash
   ./install.sh --u --name my-create-tag
   ```

## Usage

### Basic mode

```bash
create-tag [TAG_NAME] [COMMIT_HASH]
```

- `TAG_NAME`: The name of the tag to create (format `vX.Y.Z`)
- `COMMIT_HASH` (optional): The commit hash to tag (default: `HEAD`)

### Interactive mode

Run the script without arguments to start interactive mode:

```bash
create-tag
```

The interactive mode will guide you through tag creation with advanced features:
- On a main branch (main/master): options to create version tags (patch, minor, major)
- On a feature branch: creation of temporary tags based on the latest version from the main branch

### Examples

1. Create a tag on the current commit:
   ```bash
   create-tag v1.2.3
   ```

2. Create a tag on a specific commit:
   ```bash
   create-tag v1.2.3 a1b2c3d
   ```

## Supported tag formats

- **Semantic version tags**: `vX.Y.Z` (e.g., v1.0.0)
  - `X`: Major version (backward-incompatible changes)
  - `Y`: Minor version (new features)
  - `Z`: Patch version (bug fixes)
- **Ticket tags**: `TICKET.X` (e.g., FEATURE-123.1)
- **Pre-release tags**: `vX.Y.Z-alpha` (e.g. v1.0.0-alpha)
- **Temporary tags**: `vX.Y.Z_BRANCH.N` (e.g., v1.0.0_FEATURE-123.1)

## How it works

### Tag creation process

The script uses Git commands to:
- Create the tag locally and push it to the remote
- Fetch the latest tags to suggest the next ones
- Determine the appropriate base tag for temporary tags on feature branches

### Automatic cleanup system

When you run the script on a main branch:
1. Temporary tags are analyzed
2. Temporary tags associated with deleted branches are identified
3. These tags are removed both locally and on the remote repository

## Workflow examples

### Creating a new version on the main branch

```bash
git checkout main
create-tag
# Select the option to create a version tag (patch, minor, major)
```

### Creating a temporary tag on a feature branch

```bash
git checkout feature/my-feature
create-tag
# The script will automatically suggest a temporary tag based on the latest version
```

## Troubleshooting

- **Script can't find the main branch**: Make sure you have a branch named `main` or `master`
- **Error during tag cleanup**: Check your permissions on the remote repository
- **Temporary tags not cleanup**: Temporary tags doesn't match the pattern `vX.Y.Z_BRANCH.N`
- **Tag already exists**: Choose another tag name or delete the existing tag
- **Command not found after installation**: Restart your terminal or source your shell configuration file

## License

This project is licensed under the MIT License.
