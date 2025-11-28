# Implementation Plan - TextMerger Fixes & Enhancements

## Goal Description
Fix the AppImage build failure (`failed to run linuxdeploy`) and implement metadata extraction for video/image files instead of reading their binary content. Also, outline the plan for a GTK 4.22 rewrite.

## User Review Required
> [!IMPORTANT]
> **GTK Rewrite**: The request to "rewrite the whole GUI in GTK 4.22" implies a complete replacement of the current Tauri (Svelte+Rust) architecture with a native Rust+GTK4 application. This is a significant undertaking that will replace the current frontend. I will focus on fixing the current app first (Requests 1 & 2) before addressing the rewrite (Request 3).

## Proposed Changes

### Build Fixes
#### [MODIFY] [src-tauri/Cargo.toml](file:///home/ribben/Desktop/Various_Projects/textmerger/textmerger/src-tauri/Cargo.toml)
- Verify dependencies.
- (Investigation) The `linuxdeploy` error is likely environmental or configuration-based. I will attempt to debug by running the build.

### Metadata Extraction
#### [MODIFY] [src-tauri/Cargo.toml](file:///home/ribben/Desktop/Various_Projects/textmerger/textmerger/src-tauri/Cargo.toml)
- Add `nom-exif` dependency for metadata extraction.

#### [MODIFY] [src-tauri/src/file_ops.rs](file:///home/ribben/Desktop/Various_Projects/textmerger/textmerger/src-tauri/src/file_ops.rs)
- Update `read_and_check_file` to detect video/image extensions.
- Implement `read_metadata` using `nom-exif`.
- Return formatted metadata string instead of binary error or content.

## Verification Plan
### Automated Tests
- Run `npm run tauri build` to verify the fix for the build error.
- Create a test script or unit test in `file_ops.rs` to verify metadata extraction on sample files (if available).

### Manual Verification
- User should verify that adding a large video file now shows metadata instead of an error.
