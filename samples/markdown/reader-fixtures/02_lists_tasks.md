# Reader Fixture: Lists and Tasks

## Unordered Lists

- First product decision
- Second product decision with **inline emphasis**
  Continuation line that explains the rationale with [a link](https://example.com/list-continuation).
  Another continuation with `inline code`.

  Loose continuation paragraph after a blank line with *extra context*.
- Evidence screenshot ![[../../../docs/assets/markprompt_interaction_prototype_v4.png|180]] should stay inside the list item.
- Third product decision with `inline code`

## Ordered Lists

1. Read the generated Markdown.
2. Select the exact text to annotate.
3. Write the review note.
4. Generate the Prompt.

## Ordered Start and Parentheses

3. Preserve the author's starting number.
4. Continue from the authored number.
10) Parenthesized ordered marker.
11) Another parenthesized marker.

## Task Lists

- [x] Confirm local-first behavior
  Done evidence should inherit the completed state.
- [ ] Review anchor recovery
  Continuation should stay part of the task item instead of becoming a loose paragraph.

  Loose task paragraph should still map to the task list item.
- [-] Reject stale prompt draft
- [/] Investigate annotation anchor drift
- [!] Escalate blocked review note
- [a] Arbitrary completed review task
- [ ] Check Prompt preview warnings

## Nested Lists

- Parent item A
  - Child item A.1
    Continuation under child should align with child text.
  - Child item A.2
- Parent item B
  1. Ordered child B.1
  2. Ordered child B.2

## Definition Lists

API
: Application Programming Interface
: Stable review contract with `anchors`

PromptBuilder
: Builds a review prompt from included notes.

Evidence artifact
: Screenshot ![[../../../docs/assets/markprompt_interaction_prototype_v4.png|150]] documents the review surface.
