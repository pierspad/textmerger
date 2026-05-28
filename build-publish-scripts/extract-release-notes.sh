#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

VERSION="${1:-}"
NOTES_FILE="${2:-docs/release-notes.md}"
OUTPUT_FILE="${3:-}"

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version-or-tag> [release-notes-file] [output-file]" >&2
    exit 2
fi

if [ ! -f "$NOTES_FILE" ]; then
    echo "Release notes file not found: $NOTES_FILE" >&2
    exit 1
fi

VERSION="${VERSION#v}"

TMP_OUTPUT="$(mktemp)"
trap 'rm -f "$TMP_OUTPUT"' EXIT

if awk -v version="$VERSION" '
    function heading_level(line, i, c) {
        for (i = 1; i <= length(line); i++) {
            c = substr(line, i, 1)
            if (c != "#") return i - 1
        }
        return 0
    }

    function heading_title(line) {
        sub(/^#+[[:space:]]*/, "", line)
        sub(/^[Rr]elease[[:space:]]+[Nn]otes[[:space:]]+/, "", line)
        sub(/^[Vv]ersion[[:space:]]+/, "", line)
        sub(/^v/, "", line)
        sub(/[[:space:]]+$/, "", line)
        return line
    }

    /^#{1,6}[[:space:]]+/ {
        level = heading_level($0)
        title = heading_title($0)

        if (capture && level <= start_level) {
            exit
        }

        if (!capture && title == version) {
            capture = 1
            found = 1
            start_level = level
            next
        }
    }

    capture {
        print
    }

    END {
        if (!found) exit 42
    }
' "$NOTES_FILE" > "$TMP_OUTPUT"; then
    :
else
    if grep -q '^## Release Notes[[:space:]]*$' "$NOTES_FILE"; then
        cp "$NOTES_FILE" "$TMP_OUTPUT"
    else
        echo "No release notes section found for version v${VERSION} and no '## Release Notes' fallback in $NOTES_FILE" >&2
        exit 1
    fi
fi

if ! grep -q '[^[:space:]]' "$TMP_OUTPUT"; then
    echo "Release notes output for v${VERSION} is empty in $NOTES_FILE" >&2
    exit 1
fi

if [ -n "$OUTPUT_FILE" ]; then
    cp "$TMP_OUTPUT" "$OUTPUT_FILE"
else
    cat "$TMP_OUTPUT"
fi
