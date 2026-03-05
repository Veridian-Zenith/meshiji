# Meshiji - Development TODO

## Completed 🟢

- [x] Initial Project Setup (Flutter + FVM)
- [x] Custom Theme & Token System (`DesignTokens`)
- [x] Translucent Linux window background setup (`window_manager`)
- [x] Continuous background animation (`ParticleBackground` with `flutter_animate`)
- [x] UI Shell & Responsive Layout (Mobile vs Desktop)
- [x] Frosted Glass components (`FrostedGlassCard`)
- [x] Basic File System Reading & Display (Background Isolates)
- [x] Breadcrumb navigation
- [x] Hidden files toggle
- [x] Custom Context Menu (Right-click/Long-press)
- [x] File Deletion (Single & Multi-select)
- [x] Pin/Unpin Directories to Sidebar
- [x] Linux "Trash" support integrated into Sidebar
- [x] Context Menu modularized and split (`FileContextMenu` / `DirectoryContextMenu`)
- [x] Performance optimization (`listSync(followLinks: false)`, removed nested `AnimatedContainer`, conditional state rebuilds)
- [x] Project documentation & README updated

## Current Focus 🟡

- [ ] Implement basic File Explorer functions inside Context Menus:
  - [ ] Copy Files/Directories
  - [ ] Paste Files/Directories
  - [ ] Cut (Move) Files/Directories
  - [ ] Rename File/Directory
  - [ ] Create New Folder
  - [ ] Create New empty File

## Upcoming / Backlog 🔴

- [ ] **File Operations Feedback**: Add progress dialogs for long-running copy/move/delete operations.
- [ ] **Search**: Implement recursive file search with highlighting.
- [ ] **Sorting**: Allow sorting by Name, Date, Size, Type (Ascending/Descending).
- [ ] **View Modes**: Grid View vs List View toggle.
- [ ] **Keyboard Shortcuts**: (e.g., Delete key to delete, Ctrl+C/Ctrl+V, Arrow keys to navigate).
- [ ] **Properties Dialog**: Show detailed file information (Permissions, exact size, etc.).
- [ ] **Path Text Field**: Allow users to click the breadcrumbs and type an absolute path directly.

## Architecture & Refactoring Notes 🛠️

- Ensure `explorer_page.dart` doesn't become a god object.
- State management: Consider Riverpod or Provider if file state (copy/paste buffer) becomes complex across multiple split panes/tabs in the future.
- Context menu must remain strictly bound by the `DesignTokens` and `FrostedGlassCard` aesthetic.
