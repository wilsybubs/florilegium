# florilegium

## Origin

The [Reddit post](https://www.reddit.com/r/LaTeX/comments/1xixznw/how_do_you_make_these_flowers_in_latex/)
asked how to make flowers like these in LaTeX. I don't know how the original was made, and
this project doesn't try to reproduce it. It is one possible way, and the way I did it:
hand-authored primitives with randomized parameters, painted in Lua, placed by a procedural
layout whose "fill the unused space" part borrows a 1998 idea from the ornament literature.
It gets a similar look.

## What it is

Procedurally generated Delft-blue floral page margins for LuaLaTeX (and XeLaTeX). No images, no imported
paths, no external assets: every petal, leaf and stem is a parametric curve computed in Lua
while the page is being written, painted like a watercolor, and written straight into the
PDF. Every page gets its own garden.

![six seeds](gallery/seeds.gif)

*Six seeds of the grown composition. Same code, different seed — and the garden fills
whatever space the text leaves free.*

Two documents share one package, and a third shows what else it does:

| | `florilegium.tex` | `florilegium-grow.tex` |
|---|---|---|
| composition | **authored**: stems, leaves and flowers placed by hand, every parameter sampled | **grown**: a plant grown to fit the page by a greedy space-filling loop |
| adapts to | nothing (tuned for A4, 68 mm margin) | the page layout, and the free space below the text on the last page |
| preview | <img src="gallery/preview-authored.png" alt="authored" width="300"> | <img src="gallery/preview-grown.png" alt="grown" width="300"> |

Both PDFs are self-describing: the body text is the write-up of how the margin is drawn.

![last page of the grown document](gallery/preview-grown-lastpage.png)

*Last page of the grown document: the text ends early, so branches arch into the space below.*

![detail](gallery/detail.png)

*300 dpi crop. Mottled washes with white streaks lifted out, lobed leaves with white veins,
forget-me-not cymes, a pale ghost flower behind the stems.*

## Watch it grow

| as it grows | with the free space it fills |
|---|---|
| <img src="gallery/growth.gif" alt="seed 6 growing" width="400"> | <img src="gallery/growth-explain.gif" alt="seed 6 growing, with the free discs marked" width="400"> |

*Seed 6, from an empty margin to the finished page. The stems rise first, leaves open as
the tips pass their nodes, and each stem ends in a flower. Then the greedy loop takes over:
on the right, each dashed circle is the largest free disc it found, just before a branch
grows to it. Big holes come first and slowly, small ones last and fast. The butterflies and
bees fly in, the bird glides onto its twig, and the snail crawls up its stem until the last
frame, which is exactly the page this seed always gives.*

The growth is recorded once, while the page is laid out: each stem is also drawn as
prefixes of increasing length and each motif at a few smaller scales, replaying the same
random draws. A frame then writes the pieces whose time has come, in their original
painting order. `make grow-6` renders one seed this way (`build/grow-6.gif` and `.mp4`, about
45 seconds); add `EXPLAIN=1` for the dashed circles.

## The margin reads the text

![the three pages of showcase.tex](gallery/preview-showcase.png)

*`showcase.tex`, "A year in the margin": spring on the first page, summer, autumn on the
last. Each section describes the feature it shows.*

The grown margin can respond to the document around it:

- **Initials.** `\florilegiuminitial[5]{E}` sets the first letter of a paragraph in a tile
  five lines tall. The outline of the letter is read from an OpenType font (Latin Modern
  Bold by default) and painted like a petal; a vine passes over and under its strokes in
  turn, with leaves where they fit and flowers in the gaps, often in the letter's counters.
  The letter is also typeset invisibly, so the paragraph still copies as "Every".
- **Flowers at the headings.** With the option `sections`, every numbered section and
  subsection gets a flower in the margin beside its heading, painted in the copper of the
  accents, the way headings were once picked out in red.
- **A flower where the text asks.** `\florilegiumbloom` puts a flower beside the line it
  stands in; `\florilegiumbloom[lily]` asks for any motif of the garden. The marks are found
  in the page box when the page is shipped out, so this works in one run.
- **Seasons.** With the option `aging`, the garden ages from spring on the first page
  (mostly in bud, small pale leaves) to autumn on the last (seed heads, falling petals, a
  few copper leaves). It needs two runs, for the page count; `\florilegiumage{0.8}` sets an
  age by hand instead.

![four initials](gallery/initials.png)

![one seed through the seasons](gallery/seasons.png)

*One seed in spring, early summer, late summer and autumn. The seasons change what grows,
not where.*

## Visitors

![detail with a bird and a snail](gallery/detail-visitors.png)

Most pages have visitors: a butterfly or two and bees in the open spaces, a snail crawling
up one of the main stems, and on about one page in five a bird perched on a twig of its own.
They come from a random stream of their own, so a page without them is exactly the page it
would have been; the option `novisitors` leaves them out.

## Any ink

![one seed in six inks](gallery/inks.png)

*The whole palette comes from one color, `ink`: Delft blue, sepia, green, crimson, violet,
teal. The ramp from the darkest stroke to the palest wash is computed from that hue in
OKLCH, so the light end never turns gray.*

## Build

LuaLaTeX is the native route: one pass, about a second a page (two passes for
`showcase.tex`, whose seasons need the page count). XeLaTeX works too, see below.

```sh
make                        # the three PDFs
make seed-7                 # one page from seed 7 -> build/seed-7.pdf
make gallery                # gallery/seeds.png + seeds.gif, inks.png, seasons.png (python3, Pillow, pdftoppm)
make grow-6                 # growth animation of seed 6 -> build/grow-6.gif + .mp4 (ffmpeg)
make grow-6 EXPLAIN=1       # the same with the free discs marked -> build/grow-6-explain.*
```

No TeX installed? Build the image once and run everything in it:

```sh
docker build -t florilegium-tex tools
make RUN=tools/in-docker
```

Or paste `florilegium.sty`, the six `.lua` files and one of the `.tex` files into an
[Overleaf](https://www.overleaf.com) project and set the compiler to LuaLaTeX. (XeLaTeX
also needs `florilegium-xetex.def` and `florilegium-xe.lua`.)

### XeLaTeX

XeLaTeX cannot run Lua, so the drawing is done by `texlua` outside TeX
(`florilegium-xe.lua`, which runs the same Lua files) and placed as PDF pages with
`\special{pdf:image}`. The drawings are byte-identical to LuaLaTeX's, and the build time is
about the same. `florilegium-xetex.def` and `florilegium-xe.lua` must sit beside the `.sty`.
Two ways to build:

```sh
xelatex --shell-escape doc                                 # each drawing is made as it is placed
xelatex doc && texlua florilegium-xe.lua doc && xelatex doc   # no shell escape
make xe                     # the three demo documents, shell escape  -> build/xe/
make xe-batch               # the same without shell escape            -> build/xe-batch/
```

Run again when the log asks for it. The positions of headings and `\florilegiumbloom`
marks are known only after a page is shipped, so a document that uses them (`sections`,
blooms; `showcase.tex`) needs two runs in either mode. With `aging`, the batch route needs
one more `xelatex` before `texlua`, for the page count. A plain document without marks is
done in one run, or in the three steps. Without the drawings a run still finishes, with
a warning that names the commands.

`-output-directory` does not work with XeLaTeX (`xdvipdfmx` looks for the drawings in the
working directory); `-jobname=build/xe/doc` does, if the directory exists, and `texlua`
is then given the same base (`texlua florilegium-xe.lua build/xe/doc`). The byproducts
are `doc.flo` (the records), `doc-flo.pdf` or `doc-flo/` (the drawings), `doc-flo.tex` and
`doc.xdv`, all git-ignored and removed by `make clean`.

### In your own document

Use it in your own document:

```latex
\usepackage[grown]{florilegium}      % or plain \usepackage{florilegium} for the authored one
% options for the grown one: sections (flowers at the headings), aging (two runs),
% novisitors (no butterflies, bees, snails or birds)
\definecolor{ink}{HTML}{5B2A1F}      % optional: the hue of the whole palette (this is sepia)
\definecolor{accent}{HTML}{B4662F}   % optional: the copper of the hairlines
...
\florilegiuminitial[4]{T}his paragraph starts with a decorated T.
... a flower in the margin beside this line\florilegiumbloom ...
\florilegiumage{0.8}                 % grown only: autumn from here on
\florilegiumtextend                  % grown only: at the very end of the text
```

A fixed seed instead of the page number: `lualatex "\def\florilegiumseed{7}\input{florilegium-grow.tex}"`
(`xelatex` takes the same).

Any primitive can be drawn on its own inside a TikZ picture, under the current scope's
shift, rotation and scale:

```latex
\begin{tikzpicture}
  \begin{scope}[shift={(2,2)},rotate=20]\florilegiumdraw{flower}{1.3}\end{scope}
  \begin{scope}[shift={(5,0)}]\florilegiumdraw{leaf}{3.0, {depth=0.6}}\end{scope}
  \begin{scope}[shift={(8,1)}]\florilegiumdraw{ghost}{"lily", {s=1.4}}\end{scope}
  \begin{scope}[shift={(11,1)}]\florilegiumdraw{butterfly}{1.5}\end{scope}
\end{tikzpicture}
```

## How it works

**Drawing** (`ink.lua`). All geometry is computed in Lua and written as PDF path operators
into one literal node per page; TeX does no arithmetic. Primitives are drawn in a local
frame under an affine transform, which is read from TikZ when a primitive is called inside
a scope. Colors come from a tone ramp derived from the one document color `ink`: navy to
mist at the hue of `ink`, interpolated in OKLCH so the light end stays blue instead of
turning gray. Tapered strokes are two offset Béziers, not sampled ribbons.

**Primitives** (`flora.lua`). Painted in the order a watercolorist would: a flat wash,
darker blotches multiplied over it, pigment pooling at the edges, streaks lifted out in
white, a few fine veins, and almost no outlines. Broad petals and flowers, star lilies seen
at a tilt, blossoms and florets, buds and bellflowers; lobed and entire leaves; forget-me-not
cymes that curl like a scorpion's tail, branching sprigs, umbels, tendrils, seed heads;
butterflies, bees, snails and a bird; copper sparkles, rosettes and the ivy-leaf fleuron
whose stem becomes the head rule. Any of them can be painted as a pale ghost.

**Authored composition** (`authored.lua`). A plant grows from a root in the bottom-left
corner: three stems through hand-picked control points, a fourth along the bottom of the
page as the footer, leaves at chosen fractions of the stems, and every other motif on a
branch that leaves its stem tangentially and arrives along the motif's axis — so every
flower can be traced back to the root.

**Grown composition** (`grow.lua`), in the spirit of Wong, Zongker & Salesin,
[*Computer-Generated Floral Ornament*](https://dl.acm.org/doi/10.1145/280814.280948)
(SIGGRAPH 1998). The stems sway up the column as smooth noise of their height; leaves are
hung at their nodes where there is room. Then, repeatedly: take the largest free disc within
reach of a stem, choose a motif that fits it, and grow a branch to it from the nearest stem
point; the branch becomes a stem in turn. Big holes are taken first, so flowers and lilies
land early, sprays and leaves fill the middle, and the loop ends by tucking leaflets, buds
and florets onto the stems. The end of the text is measured with `\pagetotal` in the same
pass, so a short last page grows branches into the space below it with one compilation.

**Reading the page** (`florilegium.lua`). A heading or `\florilegiumbloom` leaves an
invisible marker node in the text. When the page is shipped out, its box is walked node by
node, adding up heights, depths and the glue as it was set, to find each marker's height on
the page; the garden then gives those lines their flowers before any leaf is hung. An age
reweights the motifs: buds and sprays of buds in spring, seed heads in autumn, when some
leaves are painted with a ramp built from the accent instead of the ink.

**Initials** (`initial.lua`). The letter's outline comes from luaotfload's OpenType reader as
Bézier segments. Flattened into polygons, it gives an even-odd inside test, and a grid of
distances to the letter and the frame finds the largest gaps for the flowers. The vine is a
Catmull-Rom curve across the tile; where it crosses the letter it goes over and under in
turn, and the strands that go over are drawn again, clipped to the letter, with a thin halo
of paper.

**Procedural ≠ random.** The seed is derived from the page number, so page *n* always
gets garden *n*. Reproducibility is what makes the document stable enough to typeset.

See [CLAUDE.md](CLAUDE.md) for a handoff-style map of the code, the tunables, and ideas not
yet done.

## License

MIT.
