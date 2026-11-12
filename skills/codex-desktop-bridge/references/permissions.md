# Permissions and launch modes

The companion scripts use session CLI flags, not changes to global config.toml.

| Mode | Settings | Result |
| --- | --- | --- |
| Standard | workspace-write, on-request | Work within the workspace; surface required approvals |
| Review | workspace-write, on-request, auto reviewer | Route eligible requests to automatic review; denials remain possible |
| Quiet | workspace-write, never | Do permitted work; return failures rather than asking to escalate |

Read current CLI help before relying on an option. Organization policies, host restrictions, MCP approvals and device permissions can still apply. Workspace-write limits writes, not necessarily reads to only that folder. MCP services enforce their own access; the shell sandbox does not automatically constrain a remote MCP server. Additional writable paths must be selected explicitly.

Inventory the available tools at runtime. The optional Desktop Commander registration accepts an existing executable and a caller-selected argument array. It does not download software, infer package names, or prove that a server is healthy. Use a known, reviewed server installation and verify a harmless read through its actual tool.

Sources checked 2026-11-13:
- https://learn.chatgpt.com/docs/agent-approvals-security
- https://learn.chatgpt.com/docs/build-skills
- https://learn.chatgpt.com/docs/extend/mcp?surface=cli
