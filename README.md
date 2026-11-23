# Typst Slides Template

A Typst slide theme with automatic title, contents, section, and content slides,
plus optional side-by-side speaker notes and incremental PDF animations.

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
  animations: true,
  animation-style: "invisible",
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
| `animations` | `false` | Turns top-level `>>>>>>` delimiters and `animated-grid` cells into cumulative PDF overlays. |
| `animation-style` | `"invisible"` | Appearance of unrevealed parts: `"invisible"`, `"grayed"`, or `"next-grayed"`. |
| `title-note` | `none` | Note for the generated title slide; ignored when that slide is disabled. |
| `toc-note` | `none` | Note for the first generated ToC page; ignored when the ToC is disabled. |
| `counter-total` | `true` | Uses logical `current / total` instead of current-page-only numbering. |
| `contents-label` | `[Contents]` | ToC title and ToC footer label. |
| `slide-label` | `[Slide]` | Slide-number label in speaker-note panels only. |

Page totals include title, ToC, section, content, and continuation pages.
Animation overlays share one logical page number and do not increase the total.
Supplying `title-note` or `toc-note` does not enable speaker notes; set
`speaker-notes: true` explicitly.

## Animations

Enable animations and choose how unrevealed parts look:

```typ
#slides(
  title: [Animated presentation],
  speaker-notes: true,
  animations: true,
  animation-style: "next-grayed",
)[
  == Incremental slide

  First part.
  #speaker-note([Shown with the first part.])

  >>>>>>

  Second part#footnote[Revealed with its marker and definition.]
  #speaker-note([Revealed with the second part.])

  >>>>>>

  Final part.
]
```

The delimiter can stand on its own or appear inline between top-level content.
For compact animated lists, append it to the preceding item, such as
`- First item >>>>>>`. Delimiters inside inline or block raw code are ignored.
Each overlay contains the parts revealed so far. With `"invisible"`, future
parts keep their layout but are hidden; with `"grayed"`, they are washed out.
With `"next-grayed"`, only the immediately following part is washed out and
later parts remain hidden. Revealed parts remain visible in every style.
Speaker notes are cumulative, and footnote markers and definitions follow the
part that contains them. When animations are disabled, delimiters are removed
and the final slide state is rendered once.

Labels inside animated content keep their normal Typst syntax and work with
`@label`, `#ref`, `#link`, and `query`. The theme retains each label only on the
first overlay where its part or grid cell is fully visible, preventing the
duplicate-label errors that cumulative overlays would otherwise cause:

```typ
#figure(
  rect(width: 2cm, height: 1cm),
  caption: [Revealed figure],
) <fig:revealed>

>>>>>>

See @fig:revealed.
```

A `show <label>` rule therefore applies only on that unique anchor overlay, not
to the unlabeled copies on later cumulative overlays. A label inside a grid
cell targets that cell's reveal; a label attached to `animated-grid` itself
targets the first overlay where the complete grid is visible.

Use `animated-grid` in place of Typst's native `grid` to reveal one cell per
overlay:

```typ
#animated-grid(
  columns: (1fr, 1fr),
  gutter: 0.8em,
)[First][Second][Third][Fourth]
```

The helper accepts the same cells and named arguments as `grid`. Cells advance
in comic-book order: left to right across a row, then top to bottom. Explicitly
positioned `grid.cell` elements follow their visual position, and a spanning
cell remains one step. A grid inside a delimited part finishes before the next
`>>>>>>` part begins. Multiple animated grids in the same part run sequentially
in document order. Static content in that part appears with the first cell.
Speaker notes and footnotes inside a cell follow that cell's reveal state. With
animations disabled, `animated-grid` renders as a complete native grid once.

Like delimiters, `animated-grid` must be a top-level element of the content
slide or delimited part rather than nested inside another content container.

An explicit `#pagebreak()` starts an independent animation sequence and keeps
the normal Roman continuation suffix. It also starts a new speaker-note
segment: notes written after the break appear on that continuation and animate
with its parts or grid cells. Each sequence's final state must fit on one page;
automatic overflow is not supported. Custom state and counter mutations inside
animated content are unsupported because the content is evaluated once per
overlay.

## Speaker notes

Use `speaker-note` after the heading of the slide it belongs to:

```typ
#speaker-note([Arbitrary Typst content is supported.])
```

Speaker notes belong to the segment where they are written. To annotate an
explicit continuation, put the note after its `pagebreak()`:

```typ
#pagebreak()
#speaker-note([Notes for this continuation.])
Continuation content
```

Each explicit continuation is an independent animation sequence. Put notes in
its relevant delimited part or animated-grid cell and they advance normally
within that continuation. Notes before the break remain on the preceding
segment and can never leak onto another slide. Automatic overflow does not
define note segments; use explicit page breaks when routing notes. Title and
ToC notes use the dedicated `title-note` and `toc-note` parameters.

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

## Images

A wildcard theme import replaces Typst's native `image` with a compatible
wrapper that clips images to a `4pt` corner radius. All native image arguments
remain available. The additional `inset` argument controls padding inside the
clipped box and defaults to `0pt`:

```typ
#image(path("figure.png"), width: 5cm)
#image(path("figure.png"), width: 5cm, inset: 6pt)
```

Because the wrapper lives in the theme module, file sources must be constructed
with `path(...)`. This resolves the file relative to the Typst source containing
the call before it crosses the module boundary. Raw image bytes remain supported.

## French date helper

An optional helper formats today's date in French:

```typ
#import "theme/date-fr.typ": date-fr

#slides(
  title: [Présentation],
  date: date-fr(),
)[...]
```
