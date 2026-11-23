#import "theme/typst-theme-izzy.typ": *
// #import "theme/date-fr.typ": date-fr // Optional French date helper.

#let title-color = rgb("#000000")

#slides(
  font: "Alegreya",
  // ratio: 16 / 9,
  ratio: 4 / 3,
  title-color: title-color,
  speaker-notes: true,
  animations: true,
  animation-style: "next-grayed",
  counter-total: false,
  toc: true,
  title: [Presentation Title],
  subtitle: [Presentation Subtitle],
  authors: ("Author Name",),
  date: datetime.today().display("[day] [month repr:short] [year]"),
  // date: date-fr(), // Requires the optional import above.
  title-logo: (
    image("assets/logos/helmet-white.png", height: 3.2cm),
    image("assets/logos/zaku-white.png", height: 4cm),
  ),
  content-logo: (
    image("assets/logos/helmet-black.png", height: 0.7cm),
    image("assets/logos/zaku-black.png", height: 0.9cm),
  ),
  title-note: [This note appears only on the title slide.],
  toc-note: [This note appears only on the first ToC page.],
  // slide-label: [Diapositive], // Customizes "Slide".
  // contents-label: [Contenu], // Customizes "Contents".
)[
  #set text(size: 0.94em)

  = Theme Introduction

  #speaker-note([
    Speaker notes can contain almost any Typst content, including:

    - Lists
    - _Emphasis_
    - Mathematics and shapes
    - Images

    For example:
    #rect($k "is a constant"$)
    #image("assets/figures/Tetrahedron.png", width: 1cm)
  ])

  == Grids, boxes, code, quotes, and terms
  #grid(
    columns: (1fr, 1.2fr),
    gutter: 0.76em,
  )[
    #box(radius: 4pt, fill: black.lighten(90%), inset: 6pt)[
      *Code snippets*
      #zebraw(comment-flag: [$~~>$], highlight-lines: (
        (1, [For a more advanced example, see Zebraw @zebraw.]),
      ))[
        ```typ
        = Section title
        == Slide title
        Typst combines markup, scripting, and typesetting in one system.
        ```
      ]

      ```py
      def simple_snippet():
          print("Hello, World!")

      simple_snippet();
      ```
      #v(1fr)
    ]
  ][
    #box(radius: 4pt, fill: black.lighten(95%), inset: 6pt)[
      *Quotes, terms, and mathematics*

      Quotes can include attributions, while term lists pair terms with descriptions:
      #quote(
        attribution: [_Char Aznable_],
      )[The people who remain on Earth do nothing but pollute it, because their souls are weighed down by gravity.]

      / Term title:
        A description aligned with its term.
        #v(1fr)
    ]
  ]

  == Animated reveals

  Separate animation steps with `>>>>>>`. It can be inline or appended to a
  list item; delimiters in raw code are ignored. Revealed steps remain visible
  as the slide advances.
  #speaker-note([Introduce the six-character animation delimiter and its list syntax.])

  >>>>>>

  Choose how unrevealed steps are displayed:

  - `"invisible"`: hide every future step. >>>>>>
  - `"grayed"`: gray every future step. >>>>>>
  - `"next-grayed"`: gray only the next step and hide later ones.

  #speaker-note([Compare the three available animation styles.])

  >>>>>>

  Grid cells can be animated in the same way as list items. The `#animated-grid()` macro is a drop-in replacement for `#grid()`.
  #animated-grid(columns: (1fr, 1fr), gutter: 0.4em, align: horizon)[
    *1.* Start at the left <grid-animation-start>
  ][
    *2.* Continue across the row
  ][
    *3.* Begin the next row#footnote[Footnotes follow their animation timing.]
  ][
    *4.* Final cell; #link(<grid-animation-start>)[link to the first overlay]
    #speaker-note([The final grid cell and this note appear on the last grid overlay.])
  ]

  == Figures, tables, and page breaks

  #speaker-note([
    This note belongs to the main figures-and-tables segment. To annotate a
    continuation, place its speaker note after the explicit `#pagebreak()`.
  ])

  #grid(columns: (1fr, 1.6fr), gutter: 0.75em)[
    #box(radius: 4pt, fill: black.lighten(90%), inset: 6pt)[
      *Figures*
      #figure(caption: [Picture of a frog])[
        #box(clip: true, radius: 4pt)[#image("assets/figures/frog.png")]
      ]<fig:frog>
      Figures can have captions and labels. Reference a labeled figure with #ref(<fig:frog>).#v(1fr)
    ]
  ][
    #box(radius: 4pt, fill: black.lighten(95%), inset: 6pt)[
      *Tables*

      #figure(caption: [Volume formulas])[
        #box(inset: 0pt, stroke: 1pt, radius: 4pt, clip: true)[
          #table(
            columns: (1fr, auto, auto),
            inset: 10pt,
            align: horizon,
            table.header([], [*Volume*], [*Parameters*]),
            image("assets/figures/Cylinder.png"),
            $ pi h (D^2 - d^2) / 4 $,
            [
              $h$: height \
              $D$: outer radius \
              $d$: inner radius
            ],

            image("assets/figures/Tetrahedron.png"), $ sqrt(2) / 12 a^3 $, [$a$: edge length],
          )
        ]
      ]<tab:volumes>
      Tables can be labeled and referenced in the same way: #ref(<tab:volumes>).#v(1fr)
    ]
  ]
  #pagebreak()
  #speaker-note([This note belongs to the continuation's first animation step.])
  This continuation page#footnote([A continuation page belongs to the preceding slide.]) was created with `#pagebreak()`. Typst can also create one automatically when content#footnote([By default footnotes sit on the same line.]) overflows#footnote(newline: true)[`newline` forces footnotes to start on a new line.].

  >>>>>>

  Its animations start a fresh sequence while keeping the parent slide number.
  #speaker-note([This note appears with the continuation's second animation step.])

  #hidden-section([Section omitted from the ToC])
  == Content in a hidden section
  #speaker-note([Speaker notes also work on slides within hidden sections.])
  This section remains numbered but does not appear in the ToC.

  *References*
  #text(size: 0.8em)[#bibliography("refs.bib", full: true)]

  = Conclusion
  == Thank you
  This theme is based on *diatypst* @diatypst.

  It retains many of the original features while providing a personalized look and feel. It is also designed for presenters who need Beamer-inspired speaker notes.

  *Slides with speaker notes can be presented with Pympress @pympress or other tools that support Beamer-style notes.*


  #box(
    radius: 4pt,
    fill: black.lighten(90%),
    inset: 6pt,
  )[If you find the theme useful, consider starring the repository #text(size: 2em)[$star$]]
]
