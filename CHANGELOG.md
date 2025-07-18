# Changelog

## [2025-07-18] Improved performance

### Added
- Grouping mode for bounce report: entries can now be grouped by sender address (`mailfrom`) when `GROUP_BY_FROM="true"` is set in config.
- HTML group headers include sender and bounce count, styled with `.grouphead` class.
- Visual improvement: added light gray background (`#e9e9e9`) to `.grouphead` rows for better readability.
- Fully consistent HTML escaping of all dynamic content to avoid rendering issues.
- New sender marking logic to identify bounced emails as **resent** (known senders sending from external domains) or **spoofing** (possible impersonation from internal domains).
- Introduced configuration flags `RECIPIENTS_CHECK` and `SPOOFING_CHECK` to control sender verification and spoofing detection.
- Added support for maintaining a known senders list via the helper script `postfix-build-submission-recipients.sh`.
- Added separate documentation file `SENDER_MARKING.md` explaining the marking logic and setup in detail.

### Changed
- Improved performance of postfix log parsing by replacing external `date` calls with inline `Time::Piece` Perl code.
- Added explicit year handling in log timestamp parsing to ensure correct epoch comparison.
- Optimized `generate_html_report()` function: moved all log parsing and HTML generation to a single `awk` block.
- Report generation time reduced from **several minutes to a few seconds** for large log files.

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