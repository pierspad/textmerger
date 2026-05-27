# Release Notes v2.6.0

## New Features

* **File Truncation**: Added configurable content truncation with custom character limits.
* **Recursive Truncation**: Added the "Truncate Recursively" action to the folder context menu and mapped it to the `Ctrl+Alt+Shift+T` keyboard shortcut, enabling users to re-truncate all expanded files under any specific directory in one action.
* **Content Visibility**: Added actions to expand truncated content or completely hide/show file contents.
* **File Filtering**: Updated file filtering behavior to preserve file headers and paths while hiding filtered content.
* **Automatic File Refresh**: Added support for automatically refreshing file contents at configurable time intervals.
* **Full Localization (15 Languages)**: Expanded localization support with translations for the recursive truncation feature across all 15 supported languages (`it`, `en`, `zh`, `de`, `es`, `fr`, `pt`, `ru`, `ja`, `ko`, `ar`, `pl`, `nl`, `tr`, `hi`) and updated build pipeline automation.

## Fixes

* **Settings Icon**: Fixed alignment issues and incorrect hover styling.

## Improvements

* **Performance**: Replaced two-pass file reading with single-pass buffered I/O, halving disk lookup and system call overhead.
* **Performance**: Optimized parallel string lookups in content merging from $O(N)$ to $O(1)$ using `HashSet`s and zero-allocation prefix checking.
* **Performance**: Eliminated redundant file system metadata queries when scanning and adding files by returning file sizes directly.
* **Frontend Performance**: Implemented reactive debouncing in Svelte to coalesce overlapping UI triggers, dramatically reducing redundant Tauri IPC calls.
* **Backend Architecture**: Extracted a unified pattern compiler (`FilterPatterns`), directory traversal helper, and parallel processing pipeline, eliminating extensive command duplication.
* **Deduplication**: Centralized the `normalize` path helper into a shared top-level utility, removing 7 duplicated local declarations from `App.svelte`.
* **Dependency Minimization**: Removed the external `html-escape` crate and implemented a highly efficient in-house escaping function.
* **Build Efficiency**: Completed a comprehensive dependency audit, confirming all 15 backend crates in `Cargo.toml` are actively utilized and release profile optimizations are fully enabled.
* **Build Size**: Enabled full Link-Time Optimization (LTO) in the release profile to produce a smaller and more optimized binary.
* **Codebase Cleanliness**: Conducted a full comment purge across Rust, Svelte, and TypeScript files, removing all doc-comments, inline comments, and placeholder comments.
* **Keyboard Shortcuts**: Improved shortcut support across the application and added support for filtering shortcuts by category.
* **Snackbars**: Added feedback notifications when removing excluded files.
* **User Interface**: Simplified interactions and improved overall usability.
* **Visual Consistency**: Improved continuity and alignment across UI elements.
* **Visual Interface**: Added dedicated SVG icons and visual identities for shell scripts, Docker, Java, CSS, configuration formats, PHP, logs, and additional file types to improve folder tree readability.
* **Excluded Files List**: Added additional columns and improved list visualization.
* **Notebook Handling**: Improved notebook rendering and aligned behavior with content truncation options.
* **Accessibility**: Improved keyboard-only navigation throughout the application.
