# DESIGN.md

# Meshiji — Design & System Architecture Document

Meshiji is a high‑end Android/Linux file explorer.

This document defines the complete design language, UI system, motion philosophy, theming structure, and architectural constraints for implementing Meshiji in Flutter.

This is not a generic Material file browser.
This is a deliberate, sharp, premium system tool.

---

# 1. Product Identity

Meshiji is:

* Minimal but powerful
* Fast and deliberate
* Dark-first
* Precision-focused
* System-level feeling
* Clean, not playful

It should feel closer to:

* A modern Linux power tool
* A refined terminal companion
* A developer-grade utility

It must NOT feel like:

* A colorful consumer file manager
* A stock Android Material template
* A generic Flutter demo app

---

# 2. Core Design Principles

1. Function first.
2. Visual hierarchy must support scanning.
3. Motion must communicate state.
4. Depth must be subtle.
5. Custom over default.

---

# 3. Design Token System

All UI must be driven by tokens.

## 3.1 Token Layers

Layer 1 — Primitive Tokens

* Raw color constants
* Base spacing unit (8px scale)
* Radius values
* Duration constants
* Font sizes

Layer 2 — Semantic Tokens

* backgroundPrimary
* backgroundSecondary
* surfacePrimary
* surfaceElevated
* accentPrimary
* accentDanger
* textPrimary
* textSecondary
* textMuted
* borderSubtle
* divider
* selectionOverlay

Layer 3 — Component Tokens

* fileRowHoverColor
* directoryRowColor
* sidebarBackground
* toolbarBackground
* dialogSurface
* contextMenuSurface

No widget may directly use raw colors.

---

# 4. Color System

## 4.1 Visual Foundation

Primary mode: Dark.

Background: Deep blue-black, not pure black.

Accent: Gold / amber or controlled highlight tone.

Danger: Deep red (used for delete, destructive operations).

Text must meet strong contrast ratios.

Avoid gray-on-gray fatigue.

## 4.2 Surface Elevation Model

Define layered surfaces:

Level 0 — Main canvas
Level 1 — Panels (sidebar, main file list container)
Level 2 — Cards, dialogs
Level 3 — Context menus, floating surfaces

Each level slightly lighter than the previous.

No thick borders.
Use contrast layering.

---

# 5. Typography System

## 5.1 Goals

* Highly readable
* Neutral
* Developer-friendly
* Clear monospace support

File explorer must support:

* Primary UI font
* Monospace option for file names (optional toggle)

## 5.2 Hierarchy

* App Title
* Section Title
* Path Header
* File Name
* Metadata (size/date)
* Caption

File names must visually dominate metadata.

Metadata must be muted but legible.

---

# 6. Layout Architecture

## 6.1 Platform Layout Differences

Android Layout:

* Top toolbar
* Main file list
* Optional bottom action bar (multi-select mode)

Linux Desktop Layout:

* Sidebar (directory tree)
* Main file panel
* Optional preview panel (future)
* Top toolbar

Do NOT force mobile layout on desktop.

## 6.2 Breakpoints

Mobile: < 640
Tablet: 640–1024
Desktop: > 1024

Use responsive utility abstraction.

---

# 7. File List Design

## 7.1 Row Structure

Each row contains:

* Icon (file/folder type)
* File name
* Optional metadata
* Optional trailing action indicator

Row must:

* Have hover state (desktop)
* Have selection state
* Support long press (mobile)

## 7.2 States

Normal
Hover
Selected
Focused (keyboard)
Cut (clipboard move state)
Disabled (restricted permissions)

Each state must have defined visual response.

---

# 8. Interaction Model

## 8.1 Navigation

* Tap/click folder → enter
* Back button → previous directory
* Breadcrumb path clickable

Breadcrumb must not overflow awkwardly.
Implement horizontal scroll or collapse logic.

## 8.2 Selection Mode

Entering multi-select:

* Toolbar changes appearance
* Selected count visible
* Action icons appear

Selection overlay must be subtle.
Not heavy opaque highlight.

## 8.3 Context Menu

Desktop:

* Right-click opens context menu

Android:

* Long press opens context menu

Context menu:

* Surface level 3
* Soft elevation
* Keyboard navigable (desktop)

---

# 9. Motion System

## 9.1 Duration Constants

Fast: 120ms
Standard: 200ms
Emphasis: 300–350ms

## 9.2 File Navigation Motion

When entering directory:

* Slight fade-through
* Optional subtle slide

Avoid dramatic transitions.
This is a productivity tool.

## 9.3 Hover Motion

* Slight background shift
* Minimal scale (<= 1.01)

No bounce.
No spring overshoot.

---

# 10. Toolbar Design

Toolbar must:

* Be clean
* Use icon buttons
* Avoid heavy app bar styling

Include:

* Back
* Current path
* Search
* View mode toggle (grid/list future)
* Settings

No default Material AppBar look.
Override fully.

---

# 11. Sidebar (Desktop)

Sidebar includes:

* Home
* Root
* Mounted drives
* Bookmarks

Visually separated via surface contrast.

Selected location clearly indicated.

Not bright.
Not glowing excessively.

---

# 12. View Modes (Future Ready)

System must support:

* List view (default)
* Grid view
* Compact density mode

Density scaling must be token-controlled.

---

# 13. Search UX

Search should:

* Animate into view
* Not reload whole screen
* Show results inline

Highlight matched substrings.

Search highlight color must use accentPrimary with transparency.

---

# 14. Dialog System

Dialogs must:

* Be centered (desktop)
* Bottom sheet or centered (mobile depending on context)
* Have clear action hierarchy

Destructive action must use accentDanger.

Never rely only on red text without clear label.

---

# 15. Accessibility

Must support:

* Keyboard navigation (desktop)
* Focus traversal
* Screen reader labels
* Large text scaling

Focus indicator must be visible.
Not subtle.

---

# 16. Performance Rules

* Use const widgets wherever possible
* Avoid rebuilding entire file list unnecessarily
* Use efficient list virtualization (ListView.builder)
* Debounce search input

File explorer must feel instant.

---

# 17. Folder Structure Recommendation

lib/
app/
meshiji_app.dart
router.dart
theme/
tokens/
semantic/
components/
core/
responsive/
extensions/
platform/
features/
explorer/
presentation/
state/
widgets/
sidebar/
search/
dialogs/
shared/
widgets/

Feature modules must be isolated.

---

# 18. Anti-Patterns to Avoid

* Default blue Material accents
* Heavy drop shadows
* Cartoonish easing curves
* Random spacing values
* Hardcoded inline styles
* Full-screen page reloads for small state changes

---

# 19. System Intent Check

Before merging UI changes, ask:

1. Does this increase clarity?
2. Does this reduce friction?
3. Does this maintain visual restraint?
4. Does this feel like a serious system tool?

If not — refine.

---

# 20. Long-Term Scalability

Design must allow:

* Plugin system
* Theming engine extraction
* Custom user themes
* Advanced power-user features
* Future terminal integration

Meshiji is not just a file browser.
It is a foundation system utility.

End of document.
