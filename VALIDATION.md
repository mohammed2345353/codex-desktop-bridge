# Preview validation

Local environment: Windows, Codex CLI 0.154.0, PowerShell 7.6.9.

GitHub Windows CI passed all 16 tests with no skips on both PowerShell 7.6.9 and Windows PowerShell 5.1. Evidence: [run 43324915507](https://github.com/mohammed2345353/codex-desktop-bridge/actions/runs/43324915507), testing commit `0b5439940ead4a7a804d3a68cb95ea1e317955b1`.

The automated suite covers setup, idempotence, WhatIf, changed-file preservation, argument handling, launch modes, MCP registration boundaries, and missing CLI diagnostics. The junction integration test was skipped because the execution environment denied junction creation; the script contains a path check but that case is not locally verified. Launcher and MCP mutation tests use a mock CLI; a real Codex version probe and a dry launch plan were also run. No real MCP server registration or model task was started.

Windows PowerShell 5.1 execution was blocked by the machine's script execution policy. Compatibility is intended and separate Windows CI jobs are supplied, but 5.1 is not locally verified. Global ChatGPT skill installation and GitHub publication are not implied by project setup.

The skill creator's optional Python frontmatter validator could not run because PyYAML was unavailable in this environment. PowerShell runtime tests do not replace that validator.

Live Desktop Commander and computer-use operations need separate testing after the user selects and connects the tools. Keyboard approval currently uses Codex's own focused prompt; global keyboard shortcuts remain planned.
