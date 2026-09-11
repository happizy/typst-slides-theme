# Typst Slides Template

A Typst slide theme with automatic title, contents, section, and content slides,
plus optional side-by-side speaker notes.

## Quick start

Compile the example with the bundled fonts:

```sh
typst compile slides.typ --font-path theme/fonts
```

Import the theme and wrap the presentation in `slides`:

```typ
#import "theme/typst-theme-izzy.typ": *

#slides(
  title: [Presentation title],
  authors: ("Author",),
  speaker-notes: true,
  title-note: [Introduce the presentation.],
  toc-note: [Present the structure of the talk.],
)[
  = Section title
  #speaker-note([Notes for the section slide.])

  == Content slide
  #speaker-note([Notes for the content slide.])
  Slide content
]
```

Level-one headings create section slides. Level-two headings create content
slides and start a new page. Content that continues onto another page receives
a Roman continuation suffix such as `(ii)`.

## `slides` parameters

The slide height is fixed at `10.5cm`; `ratio` determines the width of one
slide. The theme uses a fixed `1.6cm` spacing unit.

| Parameter | Default | Behavior |
| --- | --- | --- |
| `content` | Required | Arbitrary Typst slide content. |
| `title` | `none` | Required presentation title, including when `first-slide` is `false`. |
| `font` | `"Alegreya"` | Presentation font family. |
| `subtitle` | `none` | Subtitle on the generated title slide. |
| `date` | `none` | Date on the generated title slide. |
| `authors` | `()` | One author or an array of authors. |
| `title-logo` | `()` | One item or an array of logos for the title slide; `none` entries are ignored. |
| `content-logo` | `()` | One item or an array of logos for content-slide headers; `none` entries are ignored. |
| `ratio` | `4 / 3` | Width-to-height ratio of one slide. |
| `title-color` | `#0d44ac` | Accent color used for titles and derived theme colors. |
| `first-slide` | `true` | Whether to generate the title slide. |
| `bg-color` | `#faf9f6` | Page and notes-panel background color. |
| `toc` | `true` | Whether to generate a table of contents containing level-one sections. |
| `speaker-notes` | `false` | Adds a notes panel beside every slide, doubling the physical PDF page width. |
| `title-note` | `none` | Note for the generated title slide; ignored when that slide is disabled. |
| `toc-note` | `none` | Note for the first generated ToC page; ignored when the ToC is disabled. |
| `counter-total` | `true` | Uses `current / total` instead of current-page-only numbering. |
| `contents-label` | `[Contents]` | ToC title and ToC footer label. |
| `slide-label` | `[Slide]` | Slide-number label in speaker-note panels only. |

Page totals include title, ToC, section, content, and continuation pages.
Supplying `title-note` or `toc-note` does not enable speaker notes; set
`speaker-notes: true` explicitly.

## Speaker notes

Use `speaker-note` after the heading of the slide it belongs to:

```typ
#speaker-note([Arbitrary Typst content is supported.])
```

For continuation pages, `skip` moves a note forward from the slide's first
physical page:

```typ
#speaker-note(skip: 1)[This note appears on the second physical page.]
```

If `skip` exceeds the actual continuation-page count, the note appears on a
later slide. Title and ToC notes use the dedicated `title-note` and `toc-note`
parameters.

## Sections and contents

The automatic ToC contains level-one sections, not individual content slides.
Use `hidden-section` to create a visible, numbered section slide that is omitted
from the ToC:

```typ
#hidden-section([Internal section])
```

Its child slides remain visible in the section overview.

## Footnotes

A wildcard theme import replaces Typst's native `footnote` with a compatible
run-in implementation. Footnotes on the same page are rendered compactly on
one line. All native arguments remain available, plus `newline: true`:

```typ
#footnote[First definition]
#footnote(newline: true)[Start this definition on a new line]
```

Call `footnotes-display()` to render the current page's footnotes at that point
in the slide instead of in the native bottom area:

```typ
#footnotes-display()
```

## French date helper

An optional helper formats today's date in French:

```typ
#import "theme/date-fr.typ": date-fr

#slides(
  title: [Présentation],
  date: date-fr(),
)[...]
```
