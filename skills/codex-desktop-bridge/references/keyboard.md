# Keyboard approvals

In the Codex terminal, use the keys displayed by the current approval prompt. Keep that terminal focused. Do not assume a universal Y, Enter, or numbered choice across versions or approval types.

A skill cannot intercept keyboard input or change ChatGPT's interface shortcuts. The first release delegates approval UI to Codex; it does not install a global hotkey or send keystrokes to other windows.

For a future companion client, integrate with Codex App Server's request/response protocol. Show the pending action, workspace, session, and request identity before accepting a keyboard decision. Bind each keypress to the displayed request, approve once, clear resolved/cancelled requests, and reject stale or repeated events. Use only decisions supported by that request. Do not implement blind Enter/Y injection or an automatic approval loop. Multiple pending requests require explicit selection, not approval of an unseen queue.

Suggested future controls: Ctrl+Alt+Y for the displayed request, Ctrl+Alt+N to decline. These are proposed controls, not shortcuts supplied by this release or ChatGPT.

Reference: https://learn.chatgpt.com/docs/app-server
