# Technical change log

## 2026-10-07

- Updated locked development dependencies to devalue 5.9.4 and source-map-js 1.2.2 to address Dependabot alerts #58, #60, #62, #63, and #66.
- Added a postcss-selector-parser ^7.1.6 override for Tailwind 3 and postcss-nested to address alert #65 without migrating Tailwind.
- Synchronized the lockfile metadata with the existing application version 2.10.6.
- Validated with npm ci, npm run check (zero errors or warnings), and npm run build. Unrelated npm audit findings remain in the Tailwind dependency tree and nanoid.
