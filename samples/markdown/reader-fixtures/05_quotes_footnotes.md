# Reader Fixture: Quotes and Footnotes

> A good reader lets the user slow down without losing structure.
> Continued quote lines should remain visually grouped.
Lazy continuation should stay inside the quote block without requiring another marker.
>
> Second quoted paragraph keeps **inline emphasis** after a marked blank line.
> > Nested quote should hide the extra marker but keep readable indentation.
> Embedded evidence ![[../../../docs/assets/markprompt_interaction_prototype_v4.png|160]] should stay inside the quote block.

> [!NOTE]
> Callouts should hide the marker and show a readable label.
> > [!tip]- Nested reviewer hint
> > Inner nested detail should keep indentation without exposing the marker.

> [!WARNING]
> Risky changes need a distinct warning treatment.

> [!todo]+ Ship review workflow
> Fold markers should not leak into the readable callout title.

> [!faq]- Why keep source text?
> Obsidian aliases should map to readable question callouts.

> [!bug]
> Renderer regressions should be visible without showing the marker.

> [!review]- Needs reviewer follow-up
> Custom callouts should fall back to note styling without leaking source syntax.

The first important claim has a footnote reference.[^local-first]

The second claim has another reference.[^anchor]

[^local-first]: Local-first rendering means the Markdown content is processed on the user's device.

[^anchor]: Anchors need selected text, source context, and rendered ranges.
    Continuation lines should remain part of the same footnote when possible.
