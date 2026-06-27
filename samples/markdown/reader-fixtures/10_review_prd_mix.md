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

## Obsidian Review Notes

Connect this review back to [[Reader Vault/Weekly Review|weekly review]] and [[Prompt Quality]] while keeping #review/anchor visible as a tag.

Anchor links should keep their destination context: [[Prompt Quality#Review checklist]] and [[Decision Log#^accepted]].

Markdown-format internal links should behave the same: [review checklist](Prompt%20Quality.md#Review%20checklist), [extensionless retro](Reader%20Vault/Weekly%20Review#Retro), and [current block](#^review-context).

Inline embeds should stay selectable: ![[../../../docs/assets/markprompt_interaction_prototype_v4.png|220]].

Embedded note context should stay readable: ![[Research/Review Appendix#Findings|review appendix]].

Markdown-extension note embeds should hide file suffixes: ![[Research/Review Appendix.md#Risks]].

Percent-encoded note embeds should read like note names: ![[Research/Review%20Appendix.md#Risk%20Map]].

Inline reviewer context^[This should become a tooltip without polluting selected text.] should stay compact.

Private reviewer scratchpad %%needs a better example before sharing%% should not appear in reading mode. ^review-context

%%
Reviewer-only TODO:
- Hidden implementation concern that should not become a rendered task.

Private paragraph after blank line should stay hidden.
%%

Visible review note after the hidden scratchpad.

^visible-review-note

[^mix]: Mixed documents reveal whether independent renderer pieces work together.
