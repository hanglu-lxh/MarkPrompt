---
title: Reader Fixture Frontmatter
owner: MarkPrompt
tags:
  - markdown
  - reader
---

# Reader Fixture: Frontmatter and HTML

Frontmatter should not dominate the reading experience.

<aside>
HTML blocks should be visible as fallback text unless a safe native renderer exists.
</aside>

Inline HTML such as <kbd>Command</kbd> + <kbd>F</kbd>, <mark>marked HTML</mark>, H<sub>2</sub>O, x<sup>2</sup>, <ins>inserted HTML</ins>, <del>removed HTML</del>, and <small>quiet HTML</small> should remain readable.

HTML links and line breaks should survive safely: <a href="https://example.com/html-link" title="HTML link title">HTML link label</a><br>Next HTML line should remain visually separated. Inline HTML image fallback: <img src="https://example.com/html-image.png" alt="HTML diagram">.

## HTML Table

<table>
  <tr><th>Capability</th><th>Status</th><th>Risk</th></tr>
  <tr><td>HTML table fallback</td><td>Native TextKit table</td><td>Selection remains mapped</td></tr>
  <tr><td>Unsafe scripts</td><td>Ignored</td><td>No WebView execution</td></tr>
</table>

---

After a thematic break, normal paragraphs continue.
