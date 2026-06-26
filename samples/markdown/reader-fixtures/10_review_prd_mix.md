# Reader Fixture: Review PRD Mix

## Problem

AI-generated Markdown often needs human review before it is handed back to Codex.

## Proposed Flow

1. Open a local Markdown file.
2. Read in a clean centered reader.
3. Select problematic text.
4. Add a review note.
5. Generate a precise Prompt.

## Review Checklist

- [x] File opens locally
- [x] Outline is generated
- [ ] Reader table rendering is acceptable
- [ ] Prompt preview includes selected notes

## Decision Table

| Decision | Owner | Status | Review Note |
|---|---|---|---|
| Keep TextKit reader | App | Accepted | Preserves native selection |
| Avoid WebView | App | Accepted | Protects anchor model |
| Add live preview | Reader | Later | Requires anchor re-resolution |

> The product is a Markdown review tool, not a full Markdown editor.

Final sentence with **bold**, `code`, [link](https://example.com), and a footnote.[^mix]

[^mix]: Mixed documents reveal whether independent renderer pieces work together.

