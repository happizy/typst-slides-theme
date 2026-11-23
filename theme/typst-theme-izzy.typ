#import "@preview/zebraw:0.6.3": *

/// Attaches speaker-note content to the current slide.
///
/// A note belongs to the current slide segment. Put it after an explicit
/// `pagebreak()` to attach it to that continuation. Enabling note panels
/// remains the responsibility of `slides(speaker-notes: true)`.
#let speaker-note(body) = metadata((
  kind: "izzy-speaker-note",
  body: body,
))

/// Builds a grid whose cells participate in the slide animation timeline.
///
/// Arguments are forwarded to Typst's native `grid`. Cells reveal in visual
/// row-major order: left to right, then top to bottom.
#let animated-grid(..args) = metadata((
  kind: "izzy-animated-grid",
  positional: args.pos(),
  named: args.named(),
))

// Image framing --------------------------------------------------------------
// Keep access to Typst's native function before the public wrapper shadows it.
// Theme backgrounds use this native binding to avoid adding a framing box.
#let __std-image = image

/// Replaces Typst's native `image` after a wildcard theme import.
///
/// All native arguments are supported. The additional `inset` argument
/// controls padding inside a clipped box with a fixed `4pt` corner radius.
/// String paths are project-root-relative; use `path(...)` when a path should
/// remain relative to the Typst file containing the call.
#let image(source, ..args) = {
  let inset = args.named().at("inset", default: 0pt)
  let forwarded = (:)
  for (key, value) in args.named() {
    if key != "inset" {
      forwarded.insert(key, value)
    }
  }
  // The native image call happens in this theme module. Turn string paths into
  // project-root paths so calls in the main deck keep their expected meaning.
  // A resolved `path` value and raw image bytes pass through unchanged.
  let source = if type(source) == str {
    path(if source.starts-with("/") { source } else { "/" + source })
  } else {
    source
  }
  if "icc" in forwarded and type(forwarded.icc) == str {
    let profile = forwarded.icc
    forwarded.icc = path(
      if profile.starts-with("/") { profile } else { "/" + profile },
    )
  }
  box(inset: inset, clip: true, radius: 4pt)[
    #__std-image(source, ..forwarded)
  ]
}

// Footnotes run-in ------------------------------------------------------------
// Override #footnote to render entries in a compact run-in list at the bottom
// of the content. `newline: true` forces a line break before that entry.
// `break` is a Typst keyword, so the argument is named `newline`.
//
// This override must be defined at module scope because content passed to
// `slides(...)` is evaluated in the caller's scope before the function call.
// A wildcard import therefore shadows Typst's native `footnote` in the caller.
// The theme retains access to the native element through `__std-footnote`.
#let __std-footnote = footnote
#let __izzy-fn-breaks = state("izzy-fn-breaks", ())

/// Replaces Typst's native `footnote` after a wildcard theme import.
///
/// It accepts the native footnote arguments plus `newline: true`, which starts
/// this entry on a new line in the theme's compact run-in footnote list.
#let footnote(..args) = {
  let brk = args.named().at("newline", default: false)
  // Forward every other named argument to the native footnote.
  let fwd = (:)
  for (k, v) in args.named() {
    if k != "newline" { fwd.insert(k, v) }
  }
  // A label reference does not create a numbered entry. Record the line-break
  // flag only for real notes to stay aligned with the global footnote counter.
  let is-ref = args.pos().len() > 0 and type(args.pos().first()) == label
  if not is-ref { __izzy-fn-breaks.update(a => a + (brk,)) }
  __std-footnote(..args.pos(), ..fwd)
}

// Separator shared with #footnotes-display(). slides() updates it to the
// configured title color; this default also supports standalone use.
#let __izzy-fn-line = state("izzy-fn-line", line(length: 40% + 0pt, stroke: 0.05em + rgb("#0d44ac")))
#let __izzy-fn-muted-line = state(
  "izzy-fn-muted-line",
  line(length: 40% + 0pt, stroke: 0.05em + rgb("#0d44ac").transparentize(85%)),
)
#let __izzy-animation-muted = state("izzy-animation-muted", luma(82%))

// Whether page `pg` contains a call to #footnotes-display().
#let __izzy-page-has-display(pg) = query(metadata).any(m => (
  type(m.value) == dictionary
    and m.value.at("kind", default: "") == "izzy-footnotes-display"
    and m.location().page() == pg
))

// Return the animation state of the part containing `loc`. Animation renderers
// place one marker before every part on every overlay page.
#let __izzy-animation-state-at(loc) = {
  let markers = query(selector(metadata).before(loc)).filter(m => {
    let value = m.value
    (
      type(value) == dictionary
        and value.at("kind", default: "") == "izzy-animation-part"
        and m.location().page() == loc.page()
    )
  })
  if markers.len() > 0 {
    markers.last().value.at("state", default: "visible")
  } else {
    "visible"
  }
}

#let __izzy-style-animation-text(body, state) = {
  if state == "invisible" {
    hide(body)
  } else if state == "grayed" {
    text(fill: __izzy-animation-muted.get(), body)
  } else {
    body
  }
}

#let __izzy-footnote-separator(notes, separator, muted-separator) = {
  let pg = if notes.len() > 0 { notes.first().location().page() } else { none }
  let part-markers = if pg == none {
    ()
  } else {
    query(metadata).filter(m => {
      let value = m.value
      (
        type(value) == dictionary
          and value.at("kind", default: "") == "izzy-animation-part"
          and value.at("footnotes", default: 0) > 0
          and m.location().page() == pg
      )
    })
  }
  let states = if part-markers.len() > 0 {
    part-markers.map(m => m.value.at("state", default: "visible"))
  } else {
    notes.map(n => __izzy-animation-state-at(n.location()))
  }
  if states.len() > 0 and states.all(state => state == "invisible") {
    hide(separator)
  } else if states.len() > 0 and not states.any(state => state == "visible") {
    muted-separator
  } else {
    separator
  }
}

// Build the run-in list from footnote elements. Must be called in context.
#let __izzy-render-notes(notes) = {
  let breaks = __izzy-fn-breaks.final()
  set text(0.8em)
  let out = []
  let i = 0
  for n in notes {
    let k = counter(__std-footnote).at(n.location()).first()
    let brk = if k - 1 < breaks.len() { breaks.at(k - 1) } else { false }
    let marker = super(numbering(n.numbering, k))
    let state = __izzy-animation-state-at(n.location())
    let entry = marker + h(0.35em) + n.body
    if i == 0 {
      out = out + __izzy-style-animation-text(entry, state)
    } else if brk {
      out = out + __izzy-style-animation-text(linebreak() + entry, state)
    } else {
      out = out + __izzy-style-animation-text(h(1em) + entry, state)
    }
    i = i + 1
  }
  out
}

/// Renders the current page's footnotes at the call site instead of at the
/// bottom of the page. Without this call, footnotes remain at the bottom.
#let footnotes-display() = context {
  let pg = here().page()
  let notes = query(__std-footnote).filter(n => n.location().page() == pg)
  if notes.len() > 0 {
    v(0.4em)
    __izzy-footnote-separator(
      notes,
      __izzy-fn-line.get(),
      __izzy-fn-muted-line.get(),
    )
    v(__std-footnote.entry.clearance)
    __izzy-render-notes(notes)
  }
  metadata((kind: "izzy-footnotes-display")) // Suppress the bottom list.
}

/// Creates a visible, numbered section slide excluded from the table of
/// contents. Its child slides remain visible in the section overview.
#let hidden-section(title) = heading(
  level: 1,
  outlined: false,
  title,
)

/// Builds and styles a complete slide deck.
///
/// - `content` accepts arbitrary Typst content. Level-one headings create
///   section slides and level-two headings create content slides.
/// - `title` is required even when `first-slide` is `false`.
/// - `font` sets the presentation font; `subtitle` and `date` configure the
///   generated title slide.
/// - `authors` accepts one author or an array and supplies document metadata.
/// - `title-logo` and `content-logo` each accept one item or an array; `none`
///   entries are ignored.
/// - `ratio` controls one slide's width-to-height ratio. Slide height is fixed
///   at `10.5cm`, with `1.6cm` as the layout spacing unit.
/// - `title-color` defaults to `#0d44ac`; `bg-color` defaults to `#faf9f6`.
/// - `first-slide` controls automatic title-slide generation; `toc` controls
///   automatic table-of-contents generation.
/// - `speaker-notes` adds a notes panel beside every slide and therefore
///   doubles the physical PDF page width. Notes belong to the explicit
///   `pagebreak()` segment where they are written and follow its animations.
/// - `animations` turns `>>>>>>` delimiters and `animated-grid` cells in
///   content slides into cumulative PDF overlay pages. Delimiters may be inline
///   or trail a list item; raw code is ignored. `animation-style` accepts
///   `"invisible"`, `"grayed"`, or `"next-grayed"` for future parts and cells.
///   Labels remain unique and target the first fully visible overlay.
/// - `title-note` and `toc-note` accept arbitrary content for their generated
///   slides. They do not enable speaker notes. Each is ignored when its related
///   generated slide is disabled, and the ToC note appears only on its first
///   physical page.
/// - `counter-total` selects `current / total` logical-page numbering instead
///   of the current page only. Title, ToC, section, and continuation pages all
///   count; animation overlays share their slide's page number.
/// - `contents-label` changes the ToC title and its footer label.
/// - `slide-label` changes the label shown only in speaker-note panels.
#let slides(
  content,
  title: none,
  font: "Alegreya",
  subtitle: none,
  date: none,
  authors: (),
  title-logo: (),
  content-logo: (),
  ratio: 4 / 3,
  title-color: none,
  first-slide: true,
  bg-color: rgb("#faf9f6"),
  toc: true,
  speaker-notes: false,
  animations: false,
  animation-style: "invisible",
  title-note: none,
  toc-note: none,
  counter-total: true,
  contents-label: [Contents],
  slide-label: [Slide],
) = {
  if animation-style not in ("invisible", "grayed", "next-grayed") {
    panic(
      "Unknown animation style; expected 'invisible', 'grayed', or 'next-grayed'",
    )
  }

  let height = 10.5cm
  let space = 1.6cm
  let slide-width = ratio * height
  let width = if speaker-notes { 2 * slide-width } else { slide-width }
  let notes-margin = if speaker-notes {
    (left: 0cm, right: slide-width, top: 0cm, bottom: 0cm)
  } else {
    0cm
  }

  if type(title-logo) != array {
    title-logo = (title-logo,)
  }
  let title-logos = title-logo.filter(logo => logo != none)

  if type(content-logo) != array {
    content-logo = (content-logo,)
  }
  let content-logos = content-logo.filter(logo => logo != none)

  let page-margin = if speaker-notes {
    (
      left: 0.5 * space,
      right: slide-width + 0.5 * space,
      top: space + 1em,
      bottom: 0.6 * space,
    )
  } else {
    (x: 0.5 * space, top: space, bottom: 0.6 * space)
  }

  // Colors
  if title-color == none {
    title-color = rgb("#0d44ac")
  }
  let block-color = title-color.lighten(90%)
  let header-color = title-color.lighten(65%)
  let fill-color = title-color.lighten(50%)
  __izzy-animation-muted.update(bg-color.darken(15%))

  // Animation parsing and rendering -----------------------------------------
  let content-type = type([])

  let nodes-of(body) = {
    let fields = if type(body) == content-type { body.fields() } else { (:) }
    if fields.keys() == ("children",) {
      fields.values().first()
    } else {
      (body,)
    }
  }

  let join-nodes(nodes) = if nodes.len() == 0 { [] } else { nodes.join() }

  let is-animated-grid(node) = {
    if type(node) != content-type or node.func() != metadata {
      return false
    }
    let value = node.at("value", default: none)
    (
      type(value) == dictionary
        and value.at("kind", default: "") == "izzy-animated-grid"
    )
  }

  // Materialize a helper call through the native grid constructor. Besides
  // normalizing raw children into grid.cell elements, this preserves every
  // native named argument without maintaining a second grid API here.
  let animated-grid-fields(node) = {
    let value = node.at("value")
    grid(
      ..value.at("positional", default: ()),
      ..value.at("named", default: (:)),
    ).fields()
  }

  let animated-grid-cell-count(node) = (
    animated-grid-fields(node)
      .at("children", default: ())
      .filter(child => child.func() == grid.cell)
      .len()
  )

  let attach-source-label(body, source, keep: true) = {
    let source-label = source.at("label", default: none)
    if keep and source-label != none {
      [#body#source-label]
    } else {
      body
    }
  }

  let part-grid-cell-count(nodes) = nodes.fold(
    0,
    (count, node) => count + if is-animated-grid(node) {
      animated-grid-cell-count(node)
    } else {
      0
    },
  )

  let materialize-animation-grids(nodes) = {
    nodes.map(node => {
      if not is-animated-grid(node) {
        node
      } else {
        let fields = animated-grid-fields(node)
        let children = fields.remove("children")
        attach-source-label(grid(..children, ..fields), node)
      }
    }).join()
  }

  let is-gt(node) = (
    type(node) == content-type
      and node.func() == text
      and node.at("text", default: "") == ">"
  )

  // Typst may merge the final greater-than sign with following text. Split
  // only text nodes that contain `>` so inline delimiters can be recognized
  // without disturbing normal text shaping. Raw nodes remain atomic.
  let split-gt-text(node) = {
    if (
      type(node) != content-type
        or node.func() != text
        or not node.at("text", default: "").contains(">")
    ) {
      return (node,)
    }

    let out = ()
    let run = ""
    for cluster in node.at("text").clusters() {
      if cluster == ">" {
        if run != "" {
          out.push(text(run))
          run = ""
        }
        out.push(text(">"))
      } else {
        run += cluster
      }
    }
    if run != "" {
      out.push(text(run))
    }
    out
  }

  let has-leading-delimiter(nodes) = (
    nodes.len() >= 6
      and nodes.slice(0, 6).all(is-gt)
      and (nodes.len() == 6 or not is-gt(nodes.at(6)))
  )

  let has-trailing-delimiter(nodes) = (
    nodes.len() >= 6
      and nodes.slice(nodes.len() - 6).all(is-gt)
      and (nodes.len() == 6 or not is-gt(nodes.at(nodes.len() - 7)))
  )

  let rebuild-list-item(item, body-nodes) = {
    let fields = item.fields()
    let _ = fields.remove("body")
    item.func()(join-nodes(body-nodes), ..fields)
  }

  // A delimiter at either edge of a list item's body belongs between list
  // items, not inside the item. Lifting it preserves compact list spacing.
  let normalize-animation-nodes(nodes) = {
    let out = ()
    for node in nodes {
      if type(node) == content-type and node.func() == list.item {
        let fields = node.fields()
        let body-nodes = nodes-of(fields.at("body")).map(split-gt-text).flatten()
        let leading = has-leading-delimiter(body-nodes)
        let trailing = has-trailing-delimiter(body-nodes)
        let start = if leading { 6 } else { 0 }
        let end = if trailing { body-nodes.len() - 6 } else { body-nodes.len() }

        if leading {
          out += (text(">"), text(">"), text(">"), text(">"), text(">"), text(">"))
        }
        out.push(rebuild-list-item(node, body-nodes.slice(start, end)))
        if trailing {
          out += (text(">"), text(">"), text(">"), text(">"), text(">"), text(">"))
        }
      } else {
        out += split-gt-text(node)
      }
    }
    out
  }

  let is-heading(node, depth: none) = {
    let node-depth = if type(node) == content-type {
      let fields = node.fields()
      fields.at("depth", default: fields.at("level", default: none))
    } else {
      none
    }
    node-depth != none and (depth == none or node-depth == depth)
  }

  let has-label(value) = {
    if type(value) == content-type {
      let fields = value.fields()
      if fields.at("label", default: none) != none {
        true
      } else {
        fields.values().any(has-label)
      }
    } else if type(value) == array {
      value.any(has-label)
    } else if type(value) == dictionary {
      value.values().any(has-label)
    } else {
      false
    }
  }

  // Rebuild an element after recursively changing one of its fields. Typst's
  // content fields retain the names of positional arguments, so the common
  // positional shapes need to be forwarded explicitly.
  let rebuild-animation-content(node, fields) = {
    let element = node.func()
    if element == [].func() {
      join-nodes(fields.at("children", default: ()))
    } else if repr(element) == "styled" {
      let child = fields.remove("child")
      let styles = fields.remove("styles")
      element(child, styles, ..fields)
    } else if element == link {
      let dest = fields.remove("dest")
      let body = fields.remove("body")
      element(dest, body, ..fields)
    } else if element == align {
      let alignment = fields.remove("alignment")
      let body = fields.remove("body")
      element(alignment, body, ..fields)
    } else if element == place and "alignment" in fields {
      let alignment = fields.remove("alignment")
      let body = fields.remove("body")
      element(alignment, body, ..fields)
    } else if element == rotate {
      let angle = fields.remove("angle")
      let body = fields.remove("body")
      element(angle, body, ..fields)
    } else if element == columns and "count" in fields {
      let count = fields.remove("count")
      let body = fields.remove("body")
      element(count, body, ..fields)
    } else if element == terms.item {
      let term = fields.remove("term")
      let description = fields.remove("description")
      element(term, description, ..fields)
    } else if element == ref {
      let target = fields.remove("target")
      element(target, ..fields)
    } else if element == cite {
      let key = fields.remove("key")
      element(key, ..fields)
    } else if element == metadata {
      let value = fields.remove("value")
      element(value, ..fields)
    } else if "body" in fields {
      let body = fields.remove("body")
      element(body, ..fields)
    } else if "text" in fields {
      let value = fields.remove("text")
      element(value, ..fields)
    } else if "source" in fields {
      let source = fields.remove("source")
      element(source, ..fields)
    } else if "children" in fields {
      let children = fields.remove("children")
      element(..children, ..fields)
    } else if "vertices" in fields {
      let vertices = fields.remove("vertices")
      element(..vertices, ..fields)
    } else {
      element(..fields)
    }
  }

  // Every animation overlay contains a fresh copy of its content. Retaining a
  // source label in every copy makes Typst reject native references as
  // ambiguous. Recursively remove labels from every copy except the overlay
  // on which the associated animation atom first becomes fully visible.
  let strip-animation-labels(value) = {
    if type(value) == content-type {
      if not has-label(value) {
        return value
      }
      let fields = value.fields()
      let _ = fields.remove("label", default: none)
      for key in fields.keys() {
        fields.at(key) = strip-animation-labels(fields.at(key))
      }
      rebuild-animation-content(value, fields)
    } else if type(value) == array {
      value.map(strip-animation-labels)
    } else if type(value) == dictionary {
      let stripped = (:)
      for (key, field) in value {
        stripped.insert(key, strip-animation-labels(field))
      }
      stripped
    } else {
      value
    }
  }

  let count-element(value, element) = {
    if type(value) == content-type {
      let own = if value.func() == element { 1 } else { 0 }
      own + value.fields().values().fold(
        0,
        (sum, field) => sum + count-element(field, element),
      )
    } else if type(value) == array {
      value.fold(0, (sum, item) => sum + count-element(item, element))
    } else if type(value) == dictionary {
      value.values().fold(0, (sum, field) => sum + count-element(field, element))
    } else {
      0
    }
  }

  let source-figure-kind(node) = {
    let fields = node.fields()
    let kind = fields.at("kind", default: auto)
    if kind != auto {
      kind
    } else {
      let body = fields.at("body")
      if count-element(body, table) > 0 {
        table
      } else if count-element(body, raw) > 0 {
        raw
      } else {
        __std-image
      }
    }
  }

  let collect-figure-kinds(value) = {
    if type(value) == content-type {
      let own = if value.func() == figure {
        (source-figure-kind(value),)
      } else {
        ()
      }
      own + value.fields().values().map(collect-figure-kinds).flatten()
    } else if type(value) == array {
      value.map(collect-figure-kinds).flatten()
    } else if type(value) == dictionary {
      value.values().map(collect-figure-kinds).flatten()
    } else {
      ()
    }
  }

  let count-footnotes(value) = {
    if type(value) == content-type {
      let fields = value.fields()
      let own = if value.func() == __std-footnote and "body" in fields {
        1
      } else {
        0
      }
      own + fields.values().fold(
        0,
        (sum, field) => sum + count-footnotes(field),
      )
    } else if type(value) == array {
      value.fold(0, (sum, item) => sum + count-footnotes(item))
    } else if type(value) == dictionary {
      value.values().fold(0, (sum, field) => sum + count-footnotes(field))
    } else {
      0
    }
  }

  let split-animation-parts(nodes) = {
    let parts = ()
    let part = ()
    let delimiters = 0
    let i = 0
    while i < nodes.len() {
      let delimiter = (
        i + 6 <= nodes.len()
          and nodes.slice(i, i + 6).all(is-gt)
          and (i == 0 or not is-gt(nodes.at(i - 1)))
          and (i + 6 == nodes.len() or not is-gt(nodes.at(i + 6)))
      )
      if delimiter {
        parts.push(part)
        part = ()
        delimiters += 1
        i += 6
      } else {
        part.push(nodes.at(i))
        i += 1
      }
    }
    parts.push(part)
    (parts: parts, delimiters: delimiters)
  }

  let is-animation-whitespace(node) = if type(node) != content-type {
    false
  } else if node.func() == text {
    node.at("text", default: "").trim() == ""
  } else {
    node.func() in ([ ].func(), parbreak, linebreak)
  }

  let part-is-empty(nodes) = nodes.len() == 0 or nodes.all(is-animation-whitespace)

  // Fade arbitrary content by drawing a nearly opaque background-colored layer
  // over it. The outsets cover glyph and image ink beyond Typst's measured
  // bounds; the larger lower outset fully covers font descenders.
  let wash-animation-part(body) = layout(size => {
    let wash-outset = 1pt
    let wash-bottom-outset = 3pt
    let wrapped = block(width: size.width, body)
    let measured = measure(wrapped)
    block(width: size.width, height: measured.height)[
      #wrapped
      #place(
        top + left,
        dx: -wash-outset,
        dy: -wash-outset,
        rect(
          width: size.width + 2 * wash-outset,
          height: measured.height + wash-outset + wash-bottom-outset,
          fill: bg-color.transparentize(15%),
        ),
      )
    ]
  })

  let style-animation-part(body, state) = {
    if state == "invisible" {
      hide(body)
    } else if state == "grayed" {
      wash-animation-part(body)
    } else {
      body
    }
  }

  // Style directly in the native cell layout. In particular, do not introduce
  // a block or box around the body: that changes how flexible content such as
  // v(1fr) resolves and can make an otherwise fitting grid overflow. `place`
  // contributes no layout size, while the outsets still cover glyph ink.
  let style-animation-grid-cell(body, state) = {
    let wash-outset = 1pt
    let wash-bottom-outset = 3pt
    if state == "invisible" {
      hide(body)
    } else if state == "grayed" {
      body + place(
        top + left,
        dx: -wash-outset,
        dy: -wash-outset,
        rect(
          width: 100% + 2 * wash-outset,
          height: 100% + wash-outset + wash-bottom-outset,
          fill: bg-color.transparentize(15%),
        ),
      )
    } else {
      body
    }
  }

  let style-animation-list-body(body, state) = {
    if state == "invisible" {
      hide(body)
    } else if state == "grayed" {
      text(fill: bg-color.darken(15%), body)
    } else {
      body
    }
  }

  let style-animation-list-marker(symbol, state) = {
    if state == "invisible" {
      hide(text(fill: title-color, symbol))
    } else if state == "grayed" {
      text(fill: bg-color.darken(15%), symbol)
    } else {
      text(fill: title-color, symbol)
    }
  }

  let animation-state(atom, step) = {
    if atom <= step {
      "visible"
    } else if animation-style == "next-grayed" {
      if atom == step + 1 { "grayed" } else { "invisible" }
    } else {
      animation-style
    }
  }

  let animation-part-marker(
    body,
    state: none,
    step: none,
    part: none,
    continuation: none,
  ) = metadata((
    kind: "izzy-animation-part",
    state: state,
    step: step,
    part: part,
    continuation: continuation,
    footnotes: count-footnotes(body),
  ))

  let rebuild-grid-cell(cell, body) = {
    let fields = cell.fields()
    let _ = fields.remove("body")
    cell.func()(body, ..fields)
  }

  // Resolve native grid placement sufficiently to sort cells by their visual
  // top-left position. Normal cells use Typst's row-major auto-placement;
  // explicit x/y coordinates and spans reserve the same slots.
  let animated-grid-cell-order(fields, cells) = {
    let columns = calc.max(1, fields.at("columns", default: (auto,)).len())
    let occupied = (:)
    let placements = ()
    let cursor = 0

    let key-of(x, y) = str(x) + ":" + str(y)
    let fits(x, y, colspan, rowspan) = {
      if x < 0 or y < 0 or x + colspan > columns {
        return false
      }
      for dy in range(rowspan) {
        for dx in range(colspan) {
          if key-of(x + dx, y + dy) in occupied {
            return false
          }
        }
      }
      true
    }
    let reserve(slots, x, y, colspan, rowspan) = {
      for dy in range(rowspan) {
        for dx in range(colspan) {
          slots.insert(key-of(x + dx, y + dy), true)
        }
      }
      slots
    }

    for (index, cell) in cells.enumerate() {
      let cell-fields = cell.fields()
      let colspan = cell-fields.at("colspan", default: 1)
      let rowspan = cell-fields.at("rowspan", default: 1)
      let explicit-x = cell-fields.at("x", default: none)
      let explicit-y = cell-fields.at("y", default: none)
      let x = explicit-x
      let y = explicit-y

      if x == none and y == none {
        let candidate = cursor
        while not fits(calc.rem(candidate, columns), calc.quo(candidate, columns), colspan, rowspan) {
          candidate += 1
        }
        x = calc.rem(candidate, columns)
        y = calc.quo(candidate, columns)
        cursor = candidate + 1
      } else if x != none and y == none {
        y = 0
        while not fits(x, y, colspan, rowspan) {
          y += 1
        }
      } else if x == none and y != none {
        x = 0
        while x < columns and not fits(x, y, colspan, rowspan) {
          x += 1
        }
      }

      occupied = reserve(occupied, x, y, colspan, rowspan)
      placements.push((index: index, x: x, y: y))
    }

    placements.sorted(key: placement => (
      placement.y,
      placement.x,
      placement.index,
    )).map(placement => placement.index)
  }

  let render-animated-grid(
    node,
    step: none,
    atom-start: 0,
    part: none,
    continuation: none,
  ) = {
    let fields = animated-grid-fields(node)
    let children = fields.remove("children")
    let cells = children.filter(child => child.func() == grid.cell)
    if cells.len() == 0 {
      return grid(..children, ..fields)
    }

    let order = animated-grid-cell-order(fields, cells)
    let rendered = ()
    let cell-index = 0
    for child in children {
      if child.func() != grid.cell {
        rendered.push(if step == atom-start {
          child
        } else {
          strip-animation-labels(child)
        })
        continue
      }
      let rank = order.position(value => value == cell-index)
      let cell-atom = atom-start + rank
      let state = animation-state(cell-atom, step)
      let rendered-child = if step == cell-atom {
        child
      } else {
        strip-animation-labels(child)
      }
      let body = rendered-child.fields().at("body")
      let marker = animation-part-marker(
        body,
        state: state,
        step: step,
        part: part,
        continuation: continuation,
      )
      rendered.push(rebuild-grid-cell(
        rendered-child,
        marker + style-animation-grid-cell(body, state),
      ))
      cell-index += 1
    }
    let rendered-grid = grid(..rendered, ..fields)
    let label-atom = atom-start + calc.max(0, cells.len() - 1)
    attach-source-label(rendered-grid, node, keep: step == label-atom)
  }

  // Turn list items into temporary placeholders. After every part has its
  // overlay state, adjacent placeholders are rebuilt as one native tight list.
  let render-animation-part(
    nodes,
    state: none,
    step: none,
    part: none,
    continuation: none,
    atom-start: 0,
  ) = {
    let out = ()
    let i = 0
    let grid-offset = 0
    while i < nodes.len() {
      let node = nodes.at(i)
      if is-animated-grid(node) {
        out.push(render-animated-grid(
          node,
          step: step,
          atom-start: atom-start + grid-offset,
          part: part,
          continuation: continuation,
        ))
        grid-offset += animated-grid-cell-count(node)
        i += 1
      } else if type(node) == content-type and node.func() == list.item {
        let rendered-node = if step == atom-start {
          node
        } else {
          strip-animation-labels(node)
        }
        let body = rendered-node.fields().at("body")
        let styled-body = (
          box(animation-part-marker(
            body,
            state: state,
            step: step,
            part: part,
            continuation: continuation,
          ))
          + style-animation-list-body(body, state)
        )
        let item = rebuild-list-item(
          rendered-node,
          (styled-body,),
        )
        out.push(metadata((
          kind: "izzy-animation-list-item",
          item: item,
          state: state,
        )))
        i += 1
      } else {
        let end = i + 1
        while end < nodes.len() and not (
          is-animated-grid(nodes.at(end))
            or (
              type(nodes.at(end)) == content-type
                and nodes.at(end).func() == list.item
            )
        ) {
          end += 1
        }
        let run = if step == atom-start {
          nodes.slice(i, end)
        } else {
          nodes.slice(i, end).map(strip-animation-labels)
        }
        if run.all(is-animation-whitespace) {
          // Whitespace is layout-neutral and must not become its own block
          // between adjacent list items.
          out.push(join-nodes(run))
        } else {
          let body = join-nodes(run)
          out.push(animation-part-marker(
            body,
            state: state,
            step: step,
            part: part,
            continuation: continuation,
          ))
          out.push(style-animation-part(body, state))
        }
        i = end
      }
    }
    out.join()
  }

  let animation-list-marker-counter = counter("izzy-animation-list-marker")

  let render-animation-list(items, states) = {
    animation-list-marker-counter.update(0)
    list(
      tight: true,
      marker: [
        #animation-list-marker-counter.step()
        #context {
          let index = animation-list-marker-counter.at(here()).first() - 1
          let state = states.at(index, default: "visible")
          style-animation-list-marker([•], state)
        }
      ],
      ..items,
    )
  }

  let is-animation-list-item(node) = {
    if type(node) != content-type or node.func() != metadata {
      return false
    }
    let value = node.at("value", default: none)
    (
      type(value) == dictionary
        and value.at("kind", default: "") == "izzy-animation-list-item"
    )
  }

  // Replace each adjacent run of animated list-item placeholders with one
  // explicit tight list. This keeps item spacing native and prevents Typst
  // from collecting items across generated overlay page breaks.
  let render-animation-lists(nodes) = {
    let out = ()
    let i = 0
    while i < nodes.len() {
      if not is-animation-list-item(nodes.at(i)) {
        out.push(nodes.at(i))
        i += 1
        continue
      }

      let items = ()
      let states = ()
      let j = i
      let trailing-whitespace = ()
      while j < nodes.len() and is-animation-list-item(nodes.at(j)) {
        let value = nodes.at(j).at("value")
        items.push(value.at("item"))
        states.push(value.at("state", default: "visible"))
        j += 1

        let whitespace-start = j
        while j < nodes.len() and is-animation-whitespace(nodes.at(j)) {
          j += 1
        }
        if j < nodes.len() and is-animation-list-item(nodes.at(j)) {
          // Whitespace between items belongs to the same native list.
        } else {
          trailing-whitespace = nodes.slice(whitespace-start, j)
          break
        }
      }

      out.push(render-animation-list(items, states))
      out += trailing-whitespace
      i = j
    }
    out.join()
  }

  let render-animation-segment(nodes, continuation: 0) = {
    let normalized-nodes = normalize-animation-nodes(nodes)
    let split = split-animation-parts(normalized-nodes)
    let parts = split.parts
    let segment-marker = metadata((
      kind: "izzy-slide-segment",
      continuation: continuation,
    ))
    let has-animated-grid = parts.any(part => part.any(is-animated-grid))
    if split.delimiters == 0 and not has-animated-grid {
      segment-marker + join-nodes(normalized-nodes)
    } else if not animations {
      segment-marker + parts.map(materialize-animation-grids).join()
    } else {
      if split.delimiters > 0 and parts.any(part-is-empty) {
        panic("Animation delimiters must separate non-empty slide parts")
      }
      let segment = join-nodes(nodes)

      let footnote-count = count-footnotes(segment)
      let figure-kinds = collect-figure-kinds(segment)
      let equation-count = count-element(segment, math.equation)
      let part-starts = ()
      let atom-count = 0
      for part in parts {
        part-starts.push(atom-count)
        atom-count += calc.max(1, part-grid-cell-count(part))
      }

      let out = (segment-marker,)
      for step in range(atom-count) {
        let overlay = ()
        for (index, part) in parts.enumerate() {
          let atom-start = part-starts.at(index)
          let state = animation-state(atom-start, step)
          overlay.push(render-animation-part(
            part,
            state: state,
            step: step,
            part: index,
            continuation: continuation,
            atom-start: atom-start,
          ))
        }
        out.push(render-animation-lists(nodes-of(overlay.join())))
        if step + 1 < atom-count {
          out.push(pagebreak())
          out.push(counter(page).update(n => n - 1))
          if footnote-count > 0 {
            out.push(counter(__std-footnote).update(n => n - footnote-count))
            out.push(__izzy-fn-breaks.update(breaks => {
              breaks.slice(0, calc.max(0, breaks.len() - footnote-count))
            }))
          }
          if figure-kinds.len() > 0 {
            let reset-kinds = ()
            for kind in figure-kinds {
              if not reset-kinds.any(existing => existing == kind) {
                reset-kinds.push(kind)
              }
            }
            for kind in reset-kinds {
              let count = figure-kinds.filter(found => found == kind).len()
              out.push(counter(figure.where(kind: kind)).update(n => n - count))
            }
          }
          if equation-count > 0 {
            out.push(counter(math.equation).update(n => n - equation-count))
          }
        }
      }
      out.join()
    }
  }

  let render-slide-body(nodes) = {
    let out = ()
    let segment = ()
    let continuation = 0
    for node in nodes {
      if type(node) == content-type and node.func() == pagebreak {
        out.push(render-animation-segment(segment, continuation: continuation))
        out.push(node)
        segment = ()
        continuation += 1
      } else {
        segment.push(node)
      }
    }
    out.push(render-animation-segment(segment, continuation: continuation))
    out.join()
  }

  let render-deck(body) = {
    let body-fields = if type(body) == content-type {
      body.fields()
    } else {
      (:)
    }
    if repr(body.func()) == "styled" and "child" in body-fields {
      let fields = body-fields
      let child = render-deck(fields.at("child"))
      let styles = fields.at("styles")
      let _ = fields.remove("child")
      let _ = fields.remove("styles")
      return body.func()(child, styles, ..fields)
    }

    let nodes = nodes-of(body)
    let out = ()
    let i = 0
    while i < nodes.len() {
      if is-heading(nodes.at(i), depth: 2) {
        out.push(nodes.at(i))
        let end = i + 1
        while end < nodes.len() and not (
          is-heading(nodes.at(end), depth: 1)
            or is-heading(nodes.at(end), depth: 2)
        ) {
          end += 1
        }
        out.push(render-slide-body(nodes.slice(i + 1, end)))
        i = end
      } else {
        let node = nodes.at(i)
        let fields = if type(node) == content-type {
          node.fields()
        } else {
          (:)
        }
        if (
          type(node) == content-type
            and repr(node.func()) == "styled"
            and "child" in fields
        ) {
          out.push(render-deck(node))
        } else {
          out.push(node)
        }
        i += 1
      }
    }
    out.join()
  }

  // Setup
  set text(font: font, 1em)
  set document(
    title: title,
    author: authors,
  )
  set heading(numbering: "1.a")
  let slide-counter(current, total) = if counter-total {
    [#current / #total]
  } else {
    current
  }

  let notes-panel = context {
    let page-num = here().page()
    let current = counter(page).at(here()).first()
    let total = counter(page).final().first()

    let sections = query(heading.where(level: 1))
    let section = sections.rev().find(h => h.location().page() <= page-num)

    let subsections = query(heading.where(level: 2))
    let subsection = subsections.rev().find(h => h.location().page() <= page-num)

    let notes = query(metadata).filter(m => {
      let value = m.value
      (
        type(value) == dictionary
          and value.at("kind", default: "") == "izzy-speaker-note"
          and m.location().page() == page-num
      )
    })

    place(
      left + top,
      dx: slide-width,
      block(
        width: slide-width,
        height: height,
        fill: bg-color,
        inset: (x: 0.5 * space, top: 0.5 * space, bottom: 0.6 * space),
      )[
        #block(
          width: 100%,
          fill: header-color,
          inset: 8pt,
          radius: 2pt,
          below: 0.6em,
        )[
          #set text(0.85em, fill: title-color)
          #if section != none { strong(section.body) } else { [—] }
          #v(0.3em)
          #if subsection != none { subsection.body } else { [—] }
          #v(0.3em)
          #text(weight: "bold")[#slide-label #slide-counter(current, total)]
        ]
        #if notes.len() > 0 {
          for note in notes {
            let state = __izzy-animation-state-at(note.location())
            style-animation-part(note.value.at("body") + v(0.5em), state)
          }
        } else {
          set text(fill: title-color.lighten(40%))
          align(horizon)[—]
        }
      ],
    )
  }

  // PAGE----------------------------------------------
  set page(
    fill: bg-color,
    width: width,
    height: height,
    margin: page-margin,
    background: place(
      top + left,
      __std-image(
        "theme-assets/bg-content.png",
        width: slide-width,
        height: height,
        fit: "cover",
      ),
    ),
    foreground: if speaker-notes { notes-panel } else { none },
    // HEADER
    header: context {
      let physical-page = here().page()
      let headings = query(selector(heading.where(level: 2)))
      let heading = headings.rev().find(x => x.location().page() <= physical-page)

      let title-content = if heading != none {
        let marker = query(metadata).find(m => {
          let value = m.value
          (
            type(value) == dictionary
              and value.at("kind", default: "") == "izzy-animation-part"
              and m.location().page() == physical-page
          )
        })
        let segment-marker = query(metadata).rev().find(m => {
          let value = m.value
          (
            type(value) == dictionary
              and value.at("kind", default: "") == "izzy-slide-segment"
              and m.location().page() >= heading.location().page()
              and m.location().page() <= physical-page
          )
        })
        let continuation = if marker != none {
          marker.value.at("continuation", default: 0)
        } else if segment-marker != none {
          (
            segment-marker.value.at("continuation", default: 0)
              + physical-page
              - segment-marker.location().page()
          )
        } else {
          physical-page - heading.location().page()
        }
        [
          #heading.body
          #if continuation > 0 [
            #{ numbering("(i)", continuation + 1) }
          ]
        ]
      }

      let logo-content = if content-logos.len() > 0 {
        stack(
          dir: ltr,
          spacing: 0.75em,
          ..content-logos,
        )
      }

      let header-grid = [
        #grid(
          columns: (1fr, auto),
          gutter: 0.75em,
          align: (left + horizon, right + horizon),
          if title-content != none {
            title-content
          },
          if logo-content != none {
            logo-content
          },
        )]

      [
        #v(-space)
        #set text(1.4em, weight: "bold", fill: title-color)
        #header-grid
      ]
    },
    // FOOTER ----------------------------------------------------
    footer: [
      #set text(0.7em)
      #context {
        let page-num = here().page()
        let sections = query(heading.where(level: 1))
        let section = sections.rev().find(h => h.location().page() <= page-num)
        let last = counter(page).final().first()
        let current = counter(page).at(here()).first()

        let is-toc-page = (
          query(metadata)
            .filter(m => {
              let value = m.value
              (
                type(value) == dictionary
                  and value.at("kind", default: "") == "izzy-toc-page"
                  and m.location().page() == page-num
              )
            })
            .len()
            > 0
        )

        grid(
          columns: (1fr, 1fr),
          align: (left, right),
          inset: 4pt,
          [
            #if is-toc-page {
              contents-label
            } else if section != none {
              section.body
            } else {
              [—]
            }
          ],
          [
            #text(fill: black)[#slide-counter(current, last)]
          ],
        )
      }
    ],
    footer-descent: 0.2 * space,
  )

  // SLIDES STYLING --------------------------------------------------
  // Section Slides
  show heading.where(level: 1): x => {
    pagebreak(weak: true)
    set page(header: none, footer: none, margin: notes-margin, background: place(
      top + left,
      __std-image(
        "theme-assets/bg-section.png",
        width: slide-width,
        height: height,
        fit: "cover",
      ),
    ))
    set align(horizon)
    context {
      // Collect the level-2 headings belonging to this section:
      // everything between this level-1 heading and the next one.
      let loc = x.location()
      let ordered = query(heading.where(level: 1).or(heading.where(level: 2)))
      let subs = ()
      let in-section = false
      for h in ordered {
        if h.level == 1 {
          if h.location().page() == loc.page() {
            in-section = true
          } else if in-section {
            break
          }
        } else if in-section {
          subs.push(h)
        }
      }

      grid(
        columns: (1fr, 3fr),
        inset: 10pt,
        align: (right, left),
        fill: (title-color.opacify(-20%), bg-color),
        [#block(height: 100%)],
        [
          #text(1.2em, weight: "bold", fill: title-color)[#x]
          #if subs.len() > 0 {
            v(0.6em)
            set text(0.5em, fill: title-color)
            for sub in subs {
              link(sub.location())[
                #box(baseline: 0pt)[
                  #text(weight: "bold")[#numbering("1. 1", ..counter(heading).at(sub.location()))]
                  #h(0.4em) #sub.body
                ]
              ]
              linebreak()
            }
          }
        ],
      )
      // Drawn after the grid so the opaque cell fills don't hide it.
      place(
        bottom + right,
        dx: -0.59 * space,
        dy: -0.203 * space + 0.3pt,
        text(0.454em, fill: black, weight: "regular")[
          #slide-counter(counter(page).at(here()).first(), counter(page).final().first())
        ],
      )
    }
  }
  show heading.where(level: 2): pagebreak(weak: true) // this is where the magic happens
  show heading: set text(1.1em, fill: title-color)

  // ADDITIONAL STYLING --------------------------------------------------
  // Terms
  show terms.item: it => {
    stack(
      block(width: 100%, inset: 5pt, fill: header-color, radius: (top: 0.2em, bottom: 0cm), strong(it.term)),
      block(width: 100%, inset: 5pt, fill: block-color, radius: (top: 0cm, bottom: 0.2em), it.description),
    )
  }

  // Code
  show raw.where(block: false): it => {
    box(fill: block-color, inset: 1pt, radius: 1pt, baseline: 1pt)[#text(it)]
  }

  show: zebraw.with(
    radius: 4pt,
    lang: false,
    hanging-indent: true,
  )

  // Bullet List
  let animation-list-marker(symbol) = context {
    let state = __izzy-animation-state-at(here())
    style-animation-list-marker(symbol, state)
  }

  show list: set list(marker: (
    animation-list-marker([•]),
    animation-list-marker([‣]),
    animation-list-marker([-]),
  ))

  // Enum
  let color_number(nrs) = text(fill: title-color)[*#nrs.*]
  set enum(numbering: color_number)

  // Quote
  set quote(block: true)
  show quote.where(block: true): it => {
    v(-5pt)
    block(
      fill: block-color,
      inset: 5pt,
      radius: 1pt,
      stroke: (left: 3pt + fill-color),
      width: 100%,
      outset: (left: -5pt, right: -5pt, top: 5pt, bottom: 5pt),
    )[#it]
    v(-5pt)
  }

  // Run-in footnotes (see the #footnote override above).
  // Native run-in layout is unavailable (typst#6965), and every footnote.entry
  // is a separate block. The first note on each page therefore renders the
  // complete run-in list while the remaining entries render nothing. This
  // keeps the list in the native footnote area and reserves the expected space.
  // Limitations: page grouping follows marker positions and may be imperfect
  // when many notes overflow; links to empty entries share one visual target.
  //
  // When a page calls #footnotes-display(), notes render at that call site and
  // the bottom list is suppressed through empty entries and no separator.
  // Because `clearance` is a non-contextual length, a small clearance-sized
  // gap remains at the bottom of those pages.
  __izzy-fn-line.update(line(length: 40% + 0pt, stroke: 0.05em + title-color))
  __izzy-fn-muted-line.update(line(
    length: 40% + 0pt,
    stroke: 0.05em + title-color.transparentize(85%),
  ))

  set __std-footnote.entry(
    clearance: .7em, // Between slide content and the separator.
    gap: 0pt, // Empty entries must not add inter-entry spacing.
    indent: 0pt,
    separator: context {
      let pg = here().page()
      let animated = query(metadata).any(m => {
        let value = m.value
        (
          type(value) == dictionary
            and value.at("kind", default: "") == "izzy-animation-part"
            and m.location().page() == pg
        )
      })
      if __izzy-page-has-display(pg) or animated {
        none
      } else {
        line(length: 40% + 0pt, stroke: 0.05em + title-color)
      }
    },
  )

  show __std-footnote.entry: it => context {
    let loc = it.note.location()
    if __izzy-page-has-display(loc.page()) {
      [] // #footnotes-display() owns rendering on this page.
    } else {
      let notes = query(__std-footnote).filter(n => n.location().page() == loc.page())
      let this-num = counter(__std-footnote).at(loc).first()
      let first-num = counter(__std-footnote).at(notes.first().location()).first()
      if this-num != first-num {
        [] // Non-first entries add no visible content.
      } else {
        let animated = query(metadata).any(m => {
          let value = m.value
          (
            type(value) == dictionary
              and value.at("kind", default: "") == "izzy-animation-part"
              and m.location().page() == loc.page()
          )
        })
        if animated {
          move(
            dy: 1.05em,
            __izzy-footnote-separator(
              notes,
              line(length: 40% + 0pt, stroke: 0.05em + title-color),
              line(
                length: 40% + 0pt,
                stroke: 0.05em + title-color.transparentize(85%),
              ),
            ),
          )
        }
        // Space between the separator and the definitions.
        v(__std-footnote.entry.clearance)
        __izzy-render-notes(notes)
      }
    }
  }

  // Link
  show link: it => {
    if type(it.dest) != str {
      // Local Links
      it
    } else {
      underline(stroke: 0.5pt + title-color)[#it] // Web Links
    }
  }

  // Outline
  set outline(
    target: heading.where(level: 1),
    indent: auto,
  )

  show outline: set heading(level: 2) // To not make the TOC heading a section slide by itself

  // Bibliography
  set bibliography(
    title: none,
  )

  // References
  show ref: it => {
    // Filter only for links, not for citations
    if it.element != none {
      let el = it.element
      set text(size: 0.7em, fill: white)
      box(
        fill: fill-color,
        outset: (x: 0.0em, y: 0.2em),
        radius: 0.8em,
        height: 0.8em,
        inset: (x: 0.5em),
      )[
        // if no supplement is passed
        #if el.func() == heading and it.supplement == auto {
          link(el.location(), el.body)
        } else if el.func() == heading {
          // if a supplement is passed
          link(el.location(), it.supplement.text)
        } else {
          // everything else (equations, figures etc)
          it
        }
      ]
    } else {
      // these are the citations
      return it
    }
  }

  // CONTENT---------------------------------------------
  // Title Slide
  if (title == none) {
    panic("A title is required")
  } else if (first-slide == false) {
    // Suppress the automatically generated title slide.
  } else {
    if (type(authors) != array) {
      authors = (authors,)
    }
    set page(footer: none, header: none, margin: notes-margin, background: place(
      top + left,
      __std-image(
        "theme-assets/bg-title.png",
        width: slide-width,
        height: height,
        fit: "cover",
      ),
    ))
    block(
      inset: (x: 0.5 * space, top: 0.5em, bottom: 3mm),
      fill: title-color.opacify(-20%),
      width: 100%,
      height: 75%,
      align(bottom)[
        #align(left + horizon)[
          #v(1fr)
          #stack(
            dir: ltr,
            spacing: 1em,
            ..title-logos,
          )
        ]
        #v(-4mm) // Keep your vertical adjustment here if needed below the logos

        #text(2.0em, weight: "bold", fill: bg-color, title)
        #v(-5mm)
        #text(1.4em, fill: bg-color, style: "italic", subtitle)
        #v(30pt)
      ],
    )
    block(
      height: 20%,
      width: 100%,
      inset: (x: 0.5 * space, top: -3mm, bottom: 3em),
      if date != none and authors != none {
        [
          #v(10pt)
          #text(1.1em, fill: black, date)
          #v(-6pt)
          #text(1.1em, fill: black, authors.join())
        ]
      },
    )
    if title-note != none {
      speaker-note(title-note)
    }
  }

  // Outline
  if (toc == true) {
    metadata((kind: "izzy-toc-page"))
    if toc-note != none {
      speaker-note(toc-note)
    }
    outline(title: contents-label)
  }
  // The body of the slides
  render-deck(content)
}
