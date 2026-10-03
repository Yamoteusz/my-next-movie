// Style for the lab PDFs. scripts/build-docs.sh turns docs/labN.md into
// Typst with pandoc, using docs/pandoc.typ, which applies this template.

#let lab(title: none, body) = {
  set document(title: title)
  set page(paper: "a4", margin: (x: 2.2cm, y: 2.2cm), numbering: "1")
  set text(lang: "pl", size: 11pt)
  set list(indent: 0.6em)
  set enum(indent: 0.6em)

  show heading: set block(above: 1.6em, below: 0.9em)

  show link: set text(fill: rgb("#1a5fb4"))
  show raw: set text(size: 9.5pt)
  show raw.where(block: true): block.with(
    width: 100%,
    inset: 8pt,
    radius: 4pt,
    fill: luma(245),
  )

  block(below: 1.2em, text(size: 20pt, weight: "bold", title))
  body
}
