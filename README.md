# GNOME Extensions Backup & Restore Tool

A bash script to easily backup and restore your GNOME Shell extensions by saving their IDs and automatically reinstalling them.

## Features

- **Save** - Backs up all user-installed extension IDs to a file
- **List** - Shows all currently installed user extensions with their status (active/inactive)
- **Install** - Automatically downloads and installs extensions from backup file
- **Version compatibility check** - Verifies each extension supports your GNOME Shell version before installation
- **Smart filtering** - Automatically excludes system extensions (from `/usr/share`)
- **Flexible paths** - Save backups to custom locations or use the default location
- **Progress tracking** - Shows installation progress with success/failure counts

## Requirements

- GNOME Shell with `gnome-extensions` command
- `curl` (for downloading extensions)
- Internet connection (for installing extensions)

## Installation

1. Download or clone this repository
2. Make the script executable:
```bash
chmod +x gnome-extensions-backup.sh
```

## Usage

### Save Your Extensions

Save all currently installed user extensions to the default backup file:
```bash
./gnome-extensions-backup.sh save
```

Save to a custom file in the script directory:
```bash
./gnome-extensions-backup.sh save my-extensions.txt
```

Save to an absolute path:
```bash
./gnome-extensions-backup.sh save /tmp/backup.txt
```

### List Installed Extensions

Show all currently installed user extensions with their status:
```bash
./gnome-extensions-backup.sh list
```

### Install Extensions from Backup

Install all extensions from the default backup file:
```bash
./gnome-extensions-backup.sh install
```

Install from a custom backup file:
```bash
./gnome-extensions-backup.sh install my-extensions.txt
```

### Get Help

```bash
./gnome-extensions-backup.sh help
```

## How It Works

1. **Saving**: The script uses `gnome-extensions list` to get all installed extensions, filters out system extensions (located in `/usr/share`), and saves the remaining user extension IDs to a text file.

2. **Installing**: 
   - Detects your current GNOME Shell version
   - Reads extension IDs from the backup file
   - For each extension, checks if it's compatible with your GNOME Shell version
   - If compatible, downloads the extension zip file from extensions.gnome.org
   - Installs it using `gnome-extensions install`
   - If incompatible, shows which GNOME Shell versions are supported

3. **Smart handling**: Already installed extensions are skipped. Failed installations don't stop the process - the script continues with remaining extensions and provides a summary at the end.

## Default Backup Location

By default, backups are saved to:
```
<script-directory>/gnome-extensions-backup.txt
```

## Notes

- System extensions (pre-installed with GNOME) are automatically excluded from backups
- After installing extensions, you may need to:
  - Restart GNOME Shell: Press `Alt+F2`, type `r`, press Enter (X11 only)
  - Or log out and log back in (Wayland)
- The script automatically detects your GNOME Shell version and installs compatible extension versions
- Extensions that fail to install won't stop the script - it will continue with the remaining extensions

## Example Workflow

```bash
# On your current system - save your extensions
./gnome-extensions-backup.sh save

# Copy the script and backup file to a new system
# Then restore your extensions
./gnome-extensions-backup.sh install
```

## Troubleshooting

**Extension not compatible with your GNOME Shell version:**
- The script will show which GNOME Shell versions the extension supports
- Options:
  - Wait for the extension developer to add support for your version
  - Look for alternative extensions with similar functionality
  - Use an older GNOME Shell version (not recommended)
- Example error message:
  ```
  ✗ Not compatible with GNOME Shell 46
    Supported versions: 42, 43, 44, 45
  ```

**Extension not found during install:**
- The extension might have been removed from extensions.gnome.org
- Check the extension ID is correct in the backup file
- Search for the extension manually on extensions.gnome.org

**curl not found:**
```bash
# Ubuntu/Debian
sudo apt install curl

# Fedora
sudo dnf install curl

# Arch Linux
sudo pacman -S curl
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Feel free to submit issues or pull requests for improvements!
