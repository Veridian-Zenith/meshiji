# Meshiji

Meshiji is a file explorer application designed for Linux.

## Version
v0.0.20b (beta 20) (Version skips due to internal testing and development)

*Releases for Android and Windows are planned, but will not be made until the linux version is stabilized.*

## Important Information
This repository contains the contents of `VZ_Meshiji`.

## Recent Changes

**Key changes and additions include:**

*   **Core Components Added:** Several new files have been introduced, suggesting the implementation of core features:
    *   `lib/app_theme.dart`: Defines application color schemes.
    *   `lib/explorer_home.dart`: Implements the main file explorer interface, including navigation, search, sorting, and settings access.
    *   `lib/file_tile.dart`: Handles the display and interaction for individual files and folders, including context menus for file operations.
    *   `lib/settings_dialog.dart`: Provides the user interface for application settings.
    *   `lib/size_cache.dart`: Introduces a cache for directory sizes with background computation.

*   **Modified Core Functionality:** Several existing files have been modified, likely to integrate the new components and refine existing features:
    *   `README.md`: Updated with this changelog.
    *   `lib/main.dart`: Application entry point and theme setup.
    *   `lib/plugin_manager.dart`: Enhancements to plugin loading and management.
    *   `lib/settings_manager.dart`: Updates to settings persistence and management.
    *   `lib/trash_manager.dart`: Refinements to trash functionality (move, restore, delete).
    *   `lib/utils.dart`: Utility functions, potentially for cross-platform compatibility or UI helpers.

## Features

Meshiji offers a robust set of features for file management:

*   **File Browsing:**
    *   Navigate through directories.
    *   Go up to parent directories.
    *   Quick access to Home, Documents, Downloads, and Trash.
*   **File and Folder Operations:**
    *   Create new folders.
    *   Move files and folders to the trash.
    *   Restore items from the trash.
    *   Permanently delete items from the trash.
*   **Search and Sorting:**
    *   Search for files and folders by name.
    *   Sort items by name or last modified date.
*   **Settings Management:**
    *   Configure concurrency for background tasks.
    *   Toggle auto-computation of folder sizes.
    *   Enable/disable low-spec mode for reduced resource usage.
    *   Manage plugin settings.
*   **Plugin System:**
    *   Support for Lua plugins.
    *   Plugins are loaded from `~/.config/meshiji/plugins`.
    *   Each plugin requires a `plugin.json` manifest and a Lua script.
*   **Trash Management:**
    *   Files moved to trash are stored in `~/.local/share/Trash/files`.
    *   Metadata for trashed items is stored in `~/.local/share/Trash/info`.
*   **Performance:**
    *   Directory size caching with background processing.
    *   Adjustable concurrency for I/O operations.

## Known Issues

*   **Settings Menu:** The settings menu now has basic functions.

## Work In Progress / Coming Soon

*   **Built-in Terminal:** Integration of a terminal directly within the application is planned.
*   **File Previews:** Functionality for previewing file content is under development.
*   **Enhanced Actions:** Additional file operations and context menu actions are planned.

## Build and Run Instructions

### Debug Mode
To build and run in debug mode:
```bash
flutter run -d linux
```

### Release Mode
To build and run in release mode:
```bash
flutter build linux --release
```
### Run the Application (Release Mode)
```bash
./build/linux/x64/release/bundle/vz_meshiji
```
