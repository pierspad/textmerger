# Tab Improvements Plan

## Goal Description
Improve the aesthetics, responsiveness, and usability of the tabs in `TextMerger`. The goal is to achieve a modern, Firefox-like look and handle tab overflow gracefully with scroll controls.

## Proposed Changes

### [textmerger/src]

#### [MODIFY] [App.svelte](file:///home/ribben/Desktop/textmerger/textmerger/src/App.svelte)
- Update tab styling
    - Change inactive tab background to be distinct but subtle.
    - Make active tab connect seamlessly with the content area (remove bottom border, match background).
    - Add hover effects for tabs and close buttons.
    - Add separator lines between inactive tabs.
- Implement tab scrolling
    - Wrap the tab list in a scrollable container with `overflow-x-auto` but `scrollbar-hide`.
    - Add "Scroll Left" and "Scroll Right" buttons that appear when overflow content is detected (or always present if that's preferred, but conditional is better).
    - Ensure the "New Tab" button is always accessible or scrolls with tabs.
- Update `handleTabClick` and file selection to ensure the active tab is scrolled into view.

#### [MODIFY] [app.css](file:///home/ribben/Desktop/textmerger/textmerger/src/app.css)
- Add new CSS variables if needed for specific tab colors (e.g., `--bg-tab-inactive`, `--bg-tab-active`).

## Verification Plan

### Manual Verification
1.  **Aesthetics**:
    - Launch the app (`npm run tauri dev`).
    - Verify tabs look like the proposed design (connected active tab, floating/distinct inactive tabs).
    - Check hover states.
2.  **Responsiveness**:
    - Resize the window to be very narrow.
    - Verify tabs scroll or buttons appear.
    - Add many tabs (10+) to force overflow.
    - Verify scroll buttons work (slide tabs left/right).
3.  **Usability**:
    - Create a new tab. Verify it appears and is focused.
    - Close a tab. Verify layout adjusts.
    - Drag and drop tabs (existing functionality) - verify it still works with new layout.
