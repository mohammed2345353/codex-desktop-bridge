# Foundation audit and vendored sources

Reviewed 2026-11-13. Existing repository: `mohammed2345353/codex-desktop-bridge`.
The original preview is useful for workspace setup, literal argument boundaries,
CLI modes and optional MCP registration. It is not an AI router or screen-control
implementation; global keyboard approvals are still a design, not shipped code.
The original diagnostic executes `codex --version`; the new discovery deliberately
does not reuse that probe. Existing helpers and permissions are preserved.

## Downloaded and used in this repository

| Upstream | Exact reference | License | Actual use |
| --- | --- | --- | --- |
| [Dagre Graphlib](https://github.com/dagrejs/graphlib) | `0438a8f5c33d5d5ba1a9028832a0a4313cc7e3e9`, `dist/graphlib.js` | MIT | Directed task graph, topological ordering, branch/join traversal and undo of descendants in the offline HTML |
| [Google Material Design icons](https://github.com/google/material-design-icons) | `10ecc14790612ca8fd164e3f4ffe9c16fc50d5b7`, `src/action/check_circle/materialicons/24px.svg` | Apache-2.0 | Completion indicator in each reviewed step |

These are downloaded source assets under `vendor/`, not global installations.
Their original files and full licenses are retained, and the exported HTML embeds
both full license texts. `vendor/manifest.json` records SHA-256 fingerprints.
No account access, CLI execution, package lifecycle scripts or new service is
required. Graphlib's pinned source identifies as `4.0.8-pre`; this is a source
snapshot, not a claim that a stable release was installed. The current repository
had an October 2026 commit; its legacy latest-release API still pointed to a 2017
tag, so that endpoint alone is not a good maintenance signal. We test only the
small graph operations used here. No automatic upstream updates are enabled.

## Researched for later integrations, not installed or executed

| Project | Fit | Decision |
| --- | --- | --- |
| [Google Gemini CLI](https://github.com/google-gemini/gemini-cli) | Official open-source terminal AI; Apache-2.0; release `v0.68.0` published 2026-11-10 | Future opt-in handoff adapter; catalog only now. CLI authentication, subscription entitlement and API access must be checked separately. Installing/running it is unnecessary for a manual flowchart. |
| [Ollama](https://github.com/ollama/ollama) | Local model runtime, MIT; active releases | Discover filename evidence, let user confirm a downloaded local model. Individual model licenses differ. Ollama also supports cloud models, so never infer local processing from installation. |
| [Microsoft Semantic Kernel](https://github.com/microsoft/semantic-kernel) | MIT orchestration SDK with active releases | Possible later adapter framework; too much runtime/dependency scope for this small PowerShell/manual workflow. |
| [BerriAI LiteLLM](https://github.com/BerriAI/litellm) | Multi-provider routing and cost tracking | Useful reference for future API routing. Check the upstream license and enterprise-specific terms for any copied component; no code is copied and no API gateway is installed here. |
| [Microsoft WinGet](https://github.com/microsoft/winget-cli) | MIT package inventory/integration with active releases | Reference only. Direct read-only registry/PATH discovery avoids invoking package tools or refreshing network sources. |

Research is a fit and source/license review, not a full security audit of upstream
projects. No third-party AI agent, dependency installer or service was executed.
The Google icon is a visual asset; it is not presented as an AI integration.

## Capability evidence

`catalog/providers.json` links official sources for Codex, Claude Code, Gemini CLI,
Antigravity, VS Code AI features, Adobe Firefly and Ollama. These are broad,
advisory capabilities, not benchmark-based recommendations. Account-specific
models, free/subscription access, feature credits and numeric quotas are not
copied from marketing pages or inferred from local software. Confirm them in a
local file with a short validity period. No new subscription or API spending is
needed for the planner.
