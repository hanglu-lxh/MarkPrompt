# Reader Fixture: Headings and Inline Styles

This document checks heading hierarchy, paragraph rhythm, inline emphasis, links, and code spans.

*[API]: Application Programming Interface

Setext **H1** with `heading code`
=================================

Setext H2 with [navigation link](https://example.com/setext)
------------------------------------------------------------

## H2 Section

The reader should make **bold claims** stand out, keep *italic nuance* readable, show `inline code` as a compact token, and render [a reference link](https://example.com/docs) without showing raw Markdown syntax.

Extended inline syntax should read naturally: water is H~2~O, a square term is x^2^, launch notes can say :rocket: :sparkles:, ==highlighted decisions== should stand out, ++inserted wording++ should look like an addition, and entities like A &amp; B &lt; C should be decoded.

Literal technical text should remain intact: API_TOKEN, snake_case, a_b_c, and 2 * 3.

Escaped Markdown markers should stay literal: \*not italic\*, \_not emphasis\_, \[not a link](https://example.com/no-link), and \![not an image](https://example.com/no-image.png).

Abbreviations should stay selectable while carrying a quiet hint: API design remains readable.

## Hard Breaks

First hard-break line uses a backslash\
Second line should stay visually separated. Soft wrapped text should merge with this line.

### H3 Section

Mixed inline content should remain selectable: **bold `code` inside text**, *italic with [link](https://example.com)*, and ~~removed wording~~.

#### H4 Section

Short paragraphs should not feel cramped.

##### H5 Section

Small headings still need hierarchy.

###### H6 Section

The smallest heading should be readable but quiet.
