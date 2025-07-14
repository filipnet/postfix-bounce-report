# Changelog

## [2025-07-11] Improved Version

### Changed

- Switched configuration format from `.xml` to `.conf` (bash-compatible).
- Replaced unstructured `MAILINFO` HTML string concatenation with structured `$'\n'`-based formatting for better readability.
- Improved line breaks and indentation in HTML email output.
- Replaced hardcoded HTML with external template system.
- Improved internal date parsing.

### Added

- Introduced `html_escape()` function to properly escape special characters in HTML output.
- Added runtime duration output in the final report.
- Included command-line debug messages (`[INFO]`, `[CRITICAL]`) for better traceability.
- Add `ONELINE` option to disable line wrapping and enable horizontal scrolling in HTML table output
- Separated CSS into external template files for cleaner HTML and easier customization.
- Enabled usage of custom HTML and CSS templates via configuration (TEMPLATE_BASENAME).
- Added fallback to default templates if custom templates are missing.
- Updated script to dynamically load and embed CSS from external files into the email HTML.
- Implemented example log entries in anonymized form for documentation/testing purposes.

### Updated

- Reworked and structured `README.md` instructions for better readability.
- General code cleanup and structural improvements for maintainability.
- Updated script shebang and ensured POSIX compatibility.