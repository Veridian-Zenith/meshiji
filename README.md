# Meshiji (메시지)

**Meshiji** (derived from the Korean word for "Message") is a high-performance, dark-first system file explorer designed explicitly for modern Linux desktop environments (like Hyprland) and Android. It bypasses conventional generic Material design in favor of a precision-crafted, token-driven aesthetic featuring frosted glass backdrops, fluid continuous particle animations, and true window-manager integration.

This is not a toy file manager. It is designed to feel like a serious system tool.

## Key Features

* **Native Linux Desktop Compositing**: Fully transparent window backgrounds allowing the host compositor to draw borders, blur, and shadows behind a simulated frosted glass UI.
* **Hardware Accelerated UI**: Built with Flutter and running at full refresh rate. Continuous non-blocking particle runes and layout animations.
* **Isolate File Syncing**: Background processing for large directory reads and `statSync` calculations to ensure the UI thread never locks up, even in dense system folders.
* **Design Token Architecture**: Strict dark-first semantic theming driven entirely by modular layer tokens (`DESIGN.md`).
* **Intelligent Interactions**: Desktop-grade context menus, sidebar pinning, breadcrumb navigation, and instantaneous single-tap/click selection targeting.

## Installation & Setup

Meshiji requires `fvm` (Flutter Version Management) due to its use of specific engine rendering properties.

### Prerequisites

* FVM (<https://fvm.app/>)
* A Linux environment (tested heavily on Arch Linux + Hyprland)
* For transparency to work natively, your compositor must support `rgba` window hints.

### Build Instructions

1. Clone the repository:

    ```bash
    git clone https://github.com/yourusername/meshiji.trim
    cd meshiji
    ```

2. Install the required Flutter version:

    ```bash
    fvm install
    ```

3. Fetch dependencies:

    ```bash
    fvm flutter pub get
    ```

4. Run in debug mode (Linux):

    ```bash
    fvm flutter run -d linux
    ```

5. Build the release binary:

    ```bash
    fvm flutter build linux --release
    ```

## Architecture

Meshiji is structurally strict. Please review the provided `DESIGN.md` before making UI changes.

* `lib/app/`: Core app shell, `window_manager` listener implementation, and global transparent scaffolding.
* `lib/theme/`: Home to `DesignTokens`, ensuring zero hardcoded arbitrary colors in the widget tree.
* `lib/features/`: Segmented business logic (Explorer, Sidebar).
* `lib/shared/`: Global reusable UI like `FrostedGlassCard` and `ParticleBackground`.

## License

This software is released under the **Open Software License (OSL) v. 3.0**. See the `LICENSE` file for details. Copyright (c) 2026 Veridian Zenith.
