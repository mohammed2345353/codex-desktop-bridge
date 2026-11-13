# Preview validation

## AI workflow extension — 2026-11-13

Local Windows PowerShell 7.6.9: original regression suite passed 15 cases; one
junction test skipped because junction creation is not permitted. The 13 new
workflow test groups passed: unconfirmed and expired account rejection, manual
web access, private/local-only constraints, total budget and task allowances,
capability matching, balancing, blocked dependencies, malformed requests,
inert/UTF-8 HTML payloads, non-executing discovery, disabled examples and vendor
SHA-256 integrity. Node's dependency-free UI harness passed branch/join progress
transitions, undo descendants, blocked-step gating, cycle detection and rejection
of invalid or cross-plan progress imports. This is not a rendered-browser test.

A real read-only discovery returned three filename/display-name matches among
seven catalog tools. Some uninstall registry views/entries were unreadable;
discovery correctly reported a partial result. No real account was confirmed.
The demo is synthetic and did not invoke any application or AI. The new command
returns HTML/JSON; output files were explicitly saved for review.

Windows PowerShell 5.1 execution was rejected by local script execution policy;
no policy bypass or change was attempted. Both PowerShell versions are covered by
the updated GitHub workflow; report its run separately rather than inferring CI
success from these local results. Print/PDF, real model quality, account quotas,
screen capture and live third-party tool handoff are not validated by this suite.
The optional free local worker could not start (timeout); no cloud fallback was
used. All implementation review, integration and verification remained here.

Local environment: Windows, Codex CLI 0.154.0, PowerShell 7.6.9.

GitHub Windows CI passed all 16 tests with no skips on both PowerShell 7.6.9 and Windows PowerShell 5.1. Evidence: [run 43324915507](https://github.com/mohammed2345353/codex-desktop-bridge/actions/runs/43324915507), testing commit `0b5439940ead4a7a804d3a68cb95ea1e317955b1`.

The automated suite covers setup, idempotence, WhatIf, changed-file preservation, argument handling, launch modes, MCP registration boundaries, and missing CLI diagnostics. The junction integration test was skipped because the execution environment denied junction creation; the script contains a path check but that case is not locally verified. Launcher and MCP mutation tests use a mock CLI; a real Codex version probe and a dry launch plan were also run. No real MCP server registration or model task was started.

Windows PowerShell 5.1 execution was blocked by the machine's script execution policy. Compatibility is intended and separate Windows CI jobs are supplied, but 5.1 is not locally verified. Global ChatGPT skill installation and GitHub publication are not implied by project setup.

The skill creator's optional Python frontmatter validator could not run because PyYAML was unavailable in this environment. PowerShell runtime tests do not replace that validator.

Live Desktop Commander and computer-use operations need separate testing after the user selects and connects the tools. Keyboard approval currently uses Codex's own focused prompt; global keyboard shortcuts remain planned.
