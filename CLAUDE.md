# florilegium — handoff notes

Procedurally generated Delft-blue floral page margins for LuaLaTeX, and, since the
XeLaTeX path, for XeLaTeX. All geometry is computed in Lua and written as raw PDF path
operators; TeX does no arithmetic. LuaLaTeX runs the Lua inside TeX (native path); XeLaTeX
cannot, so `florilegium-xe.lua` runs the same Lua in texlua outside TeX and the drawings
are placed as PDF pages (byte-identical to LuaLaTeX's). Two
documents share one package: an **authored** composition (hand-placed stems, leaves and
branch targets, parameters sampled) and a **grown** one (layout computed by a greedy
space-filling loop). Same primitives, same motif table. No images, no assets. The grown
margin also reads the text (flowers at headings and marked lines, seasons over the
document), pages get visitors, and paragraphs can open with a decorated initial;
`showcase.tex` demonstrates all of it.

## Files

| file | what |
|---|---|
| `florilegium.sty` | thin TeX layer: options `authored` (default) / `grown`, `nomargin`, `novisitors`, `sections`, `aging`; colors `ink` and `accent`; `\florilegiumdraw`, `\florilegiumtextend`, `\florilegiumbloom`, `\florilegiumage`, `\florilegiuminitial`, `\florilegiuminitialfont`, `\florilegiumframe`; the shipout hook. LuaLaTeX natively; under XeLaTeX it loads the `.def` below instead of the shipout hook. |
| `florilegium-xetex.def` | XeLaTeX half of the `.sty` (loaded by it): one Lua record per margin/initial/`\florilegiumdraw` into `<jobname>.flo`, `\pdfsavepos` for marks, `\special{pdf:image}` to place the drawings, shell-escape one-run mode and batch mode, md5 of the records for the rerun warnings. The header comment is the spec of both build modes. |
| `florilegium-xe.lua` | the driver, run by texlua: reads the records, stubs the TeX accessors, plays them through `florilegium.lua` and writes minimal PDFs (`<base>-flo.pdf` + `-flo.tex` in batch mode; `<base>-flo/n.pdf` with `--item n` in shell-escape mode). Header comment: record format. Env `FLORILEGIUM_DUMP=<file>` appends every content stream. |
| `florilegium.lua` | glue: page geometry from TeX dimens (through `M.dimen`/`M.macro`/`M.error`, which the XeLaTeX driver replaces), `reset_rng`/`advance` to replay the page rng, marks given as a precomputed list, colors, page seed, the TikZ transform (`\pgf@pt@aa..bb`, `\pgf@pt@x/y`), primitive dispatch, the header; text marks (whatsits) and the walk of `\ShipoutBox` that finds them; age; animation frames; the initial's placement and its invisible letter. |
| `ink.lua` | drawing core: mulberry32 rng, 1-D gradient noise/fbm, OKLCH tone ramp, affine transform stack, path building (`smooth` = Catmull-Rom as Béziers, `taper`, `ribbon`, `blade`, `blob`), fill/stroke/clip with ExtGState opacity + multiply, numbered layers, `flush()` into one `pdf_literal` node. Output goes through `ink.backend` (`literal(s)`, `extgs(name, dict)`), which a driver outside TeX replaces. |
| `flora.lua` | the primitives: `petal flower lily blossom floret bud bell leaf leaflet stem cyme sprig umbel seedhead tendril sparkle rosette hedera ghost`, the visitors `butterfly bee snail bird`, plus `branch_path`. |
| `grow.lua` | grown composition: regions, grid, stems, marks, visitors on the stems, leaves at nodes, branch loop, falling petals, filler, footer tail; seasons; animation events. Also exports the **motif table** (`M.motifs`) and layer numbers used by `authored.lua`. |
| `authored.lua` | authored composition: the hand-placed "score" (STEMS, LEAVES, BRANCHES, GHOSTS, VISITORS, SNAIL, ACCENTS, FOOT) for A4 with a 68 mm left margin. |
| `initial.lua` | decorated initials: glyph outline via `fonts.handlers.otf.readers.loadshapes`, even-odd inside test, clearance grid, the vine over/under the letter, leaflets, flowers in the gaps, tile frame. |
| `florilegium.tex` / `florilegium-grow.tex` | demo documents (authored / grown). Body text = `text-methods.tex` (+ `text-growth.tex` for grown) + `text-sharing.tex`; it describes the code, so **update it when the method changes**. |
| `showcase.tex` | "A year in the margin": `[grown,sections,aging]`, an initial, `\florilegiumbloom`; each section describes the feature it shows. Two passes. |
| `gallery.tex`, `tools/gallery.py` | one short page per variant (`\galleryink`, `\galleryage`) → `gallery/seeds.png` + `seeds.gif`, `inks.png`, `seasons.png`. |
| `animation.tex`, `tools/animate.py` | growth animation: one page per frame (`\florilegiumframe`), parallel LuaLaTeX jobs, pdftoppm, ffmpeg → `build/grow-N.gif` + `.mp4`. `tools/animcheck.lua` checks that the last frame equals the page. |
| `tools/Dockerfile`, `tools/in-docker` | TeX Live 2023 image; `make RUN=tools/in-docker` when there's no local TeX. |

## Build

```sh
docker build -t florilegium-tex tools     # once, if there is no local TeX
make RUN=tools/in-docker                  # the three PDFs (showcase: two passes for aging)
make seed-7 RUN=tools/in-docker           # one page for seed 7 -> build/seed-7.pdf
make gallery RUN=tools/in-docker          # seeds, inks and seasons sheets (~40 s)
make grow-6 RUN=tools/in-docker [EXPLAIN=1]            # ~45 s: build/grow-6.gif + .mp4
make animation RUN=tools/in-docker                     # both, copied to gallery/growth*.gif
tools/in-docker texlua tools/animcheck.lua 1 2 3       # last frame == page, byte for byte
make preview                              # gallery/preview-*.png from the root PDFs
```

XeLaTeX (output in `build/xe/`, `build/xe-batch/`; each target runs the three demo documents):

```sh
make xe RUN=tools/in-docker               # xelatex --shell-escape -jobname=build/xe/<doc> (showcase twice)
make xe-batch RUN=tools/in-docker         # no shell escape: xelatex, texlua florilegium-xe.lua build/xe-batch/<doc>, xelatex
                                          #   (showcase: xelatex, xelatex, texlua, xelatex)
xelatex --shell-escape doc                # by hand, in your own document; twice if it has sections/blooms
xelatex doc && texlua florilegium-xe.lua doc && xelatex doc   # aging: one more xelatex before texlua
```

Check after touching the Lua core or the `.def`: (1) a LuaLaTeX build must stay byte-identical
to the previous commit's (`SOURCE_DATE_EPOCH=1 FORCE_SOURCE_DATE=1` makes the PDFs
reproducible; `cmp` the three PDFs against a build of the previous commit, e.g. from `git worktree`);
(2) the XeLaTeX drawings must equal LuaLaTeX's: run the driver with
`FLORILEGIUM_DUMP=/tmp/xe.dump` and compare it with the content streams of a LuaLaTeX run
(same `length\nstream\n` format, from a harness that replaces `ink.backend.literal`; or
extract the page content streams from the PDF), and diff the margins as pixels with `pdftoppm`.
`make xe` and `make xe-batch` must give pixel-identical pages.

Fixed seed: `lualatex "\def\florilegiumseed{7}\input{florilegium-grow.tex}"`. Any
positive integer works.

Look at output with `pdftoppm -png -r 100 file.pdf page` and read the PNG; for fine detail
use `-r 300` with `-x -y -W -H` crops. Always look before declaring a change good. For a
quick sheet of every primitive, `scratch/` (git-ignored) is the place for test documents.

Bytes per primitive: `tools/in-docker texlua tools/bytes.lua` (stubs out TeX). A flower
is ~70 KB of path operators, a page ~3 MB uncompressed, ~0.7 MB in the PDF.

## Conventions and traps

- **US spelling everywhere** (color, center, gray, meter) — code, comments, docs.
- **Raw literals bypass TikZ transforms.** A primitive called inside a TikZ scope must
  read pgf's matrix itself (`florilegium.lua: sync_transform`). Inside the margin picture
  the transform is just cm→bp from the page's lower-left corner.
- **Lua truncates multiple returns** in the middle of a table constructor:
  `{x0, y0, f(t), x1}` keeps only the first value of `f(t)`. Assign to locals first.
- **Line widths are absolute bp** (we transform points in Lua, not with `cm`). Anything
  that should scale with a motif is a filled shape (`taper`, `ribbon`); `flora.stem`
  switches to a stroke below ~0.7 bp.
- **Opacity/blend** need ExtGState resources: `ink.lua: gs()` registers `/floaNN` and
  `/flomNN` (multiply) through `\pgfutil@addpdfresource@extgs` once per document.
- **Size budget.** Output, not time, is the constraint. Coordinates are printed `%.1f` bp;
  a path used for fill and clip is emitted once (`clip()` then `flood()`); streaks are
  `taper` (2 Béziers); florets below 0.7 mm are a 10-point polygon. Measure before adding
  per-petal detail.
- **Level of detail**: primitives check `ink.unit()` (cm per local unit) and
  `ink.get_lift()` (ghost) and skip specks/veins when small or pale.
- **Determinism**: every primitive takes an rng; layout code draws from `layout` and
  hands primitives `rng.fork()`, so a change inside a primitive does not move the layout.
  Never iterate a string-keyed table with `pairs()` where the order feeds an rng (Lua's
  order changes from run to run); `authored.lua` uses a fixed stem order for this reason.
- **Animation replays draws.** With `g.anim`, `grow.lua: place()` calls each closure
  several times (smaller scales first) and restores `rng` and `layout` with
  `save()`/`load()` in between. A closure may only draw from those two (fork inside the
  closure, not before it), or the last frame stops matching the page; run
  `tools/animcheck.lua` after touching `grow.lua`.
- **Separate streams keep old pages stable.** Visitors draw from `ink.rng(seed*7919+101)`,
  the season's additions from `+211`, the authored visitors from `+103`. With no visitors,
  no age and no marks a grown page is byte-identical to before those features (check by
  comparing against `git show HEAD:grow.lua` etc. in a texlua harness with stubbed TeX).
- **The last animation frame uses t = ∞**: for the event that ends last,
  `(t0+dur-t0)/dur` can round just below 1 and leave a 95% bloom.
- **Text end, one pass**: `\florilegiumtextend` records `\pagetotal+\pagedepth` and the
  page number; the shipout hook of that same page reads them, in the same run.
- **Marks, one pass**: `florilegium.mark` writes a `user_defined` whatsit (user_id
  0x464C4F); in the shipout/background hook `\ShipoutBox` is complete, and walking it
  (heights, depths, `node.effective_glue`) gives each mark's y; the box's origin is 1 in
  (+`\voffset`) below the top of the paper. Option `sections` wraps `\@sect` at
  `\begin{document}` and puts the mark into the typeset title (#8), so standard classes only.
- **Aging needs the .aux**: `\flo@lastpage` is written at the end and read on the next run;
  until then every page is summer and LaTeX asks for a rerun.
- **Never wrap typeset text in `q`…`Q` page literals**: `Q` drops the `Tf` LuaTeX set
  inside and the rest of the page's text disappears. The initial's invisible letter uses
  `3 Tr` / `0 Tr` instead. (ActualText on a path-only span is ignored by poppler.)
- **XeLaTeX: xdvipdfmx converts pages while XeTeX is still running**, so a PDF made at the end
  of the run is too late. Shell-escape mode therefore draws each item as it is placed
  (`\write18{texlua ... --item n}`); batch mode needs the PDF from the run before.
- **xdvipdfmx fails fatally on a missing image file or page.** Every `\special{pdf:image}` is
  guarded (`\IfFileExists` in shell-escape mode, the page count from `-flo.tex` in batch mode); keep it so.
- **The XeLaTeX path must keep the page rng in step with LuaLaTeX.** The page seed is set at
  each margin page, the header takes one draw, each initial and each `\florilegiumdraw` one;
  records carry `rng={page,fixed,k}` and the driver replays it (`reset_rng`/`advance`). A new
  draw from the page rng in `florilegium.lua` must be mirrored in the `.def` and the driver.
- **XeLaTeX marks:** `\pdfsavepos` is from the paper's lower-left corner; the driver redoes
  `page_marks`' exact sum (with `\hoffset`/`\voffset`) to stay bit-identical.
- **`-output-directory` does not work under XeLaTeX** (xdvipdfmx looks in the working
  directory). Use `-jobname=dir/doc` (dir must exist) and give texlua the same base.
  Byproducts (`*.flo`, `*-flo.pdf`, `*-flo.tex`, `*-flo/`, `*.xdv`) are git-ignored and in `make clean`.
- **Any change to the Lua core must keep LuaLaTeX output byte-identical** (see Build).
- This container's TeX Live lacks luaotfload's font database for system fonts; the
  documents pin Computer Modern. Harmless to remove on a full install.

## How the growth works (grow.lua)

1. Regions: margin column, a footer band along the bottom (to ~45% of the text width),
   and on the last page the rectangle under the text.
2. Stems: three from a root near the bottom-left corner; x(y) = c + A·fbm(y/λ + φ), blended
   into the root over 4 cm. Tops at the page top (hero flower), 60–72% (lily), 36–48%
   (flower). A spiral scroll at the root; a footer stem to the right. On the last page,
   Bézier arcs from a main stem into the spill, each ending in a flower.
3. Ghosts (1–2 pale flowers, layer 1) get a weak proxy so the growth leaves them some room.
4. Leaves at nodes of every "leafy" stem (alternating, 35–60°, smaller toward the top; the
   footer gets leaflets that thin out), only where `free` allows.
5. Grid (2 mm), `free` = largest disc that fits (proxies count at κ=0.85 of their radius;
   stems are chains of small discs) and `sdist` = distance to the nearest stem point.
   Updates only visit lattice cells near the new disc.
6. Branch loop: cell with the largest `free·U(0.85,1.15)` within REACH (3 cm) of a stem;
   pick a motif by weight `w/(1+count/cap)` (hard caps only for flower, lily, umbel,
   bells); scale so r(s) ≈ 0.95·free; axis = away from the nearest stem point + `upright`
   lean; `flora.branch_path` from that stem point; the branch's points become stem points.
   Stop below SMALLEST (3.6 mm).
7. Filler: holes ≥ 1.7 mm within 7.5 mm of a stem get a leaflet pair, a bud or a floret
   cluster (capped); far holes get at most 6 copper accents; no dust.
8. Footer tail: copper hairline + sparkle. Layers: 1 ghost, 2 stems, 3 leaves, 4 airy,
   5 blooms, 6 accents (7 overlay, animation only); a safety clip a little outside the regions.
9. Marks (before the leaves, right after the ghosts): a flower beside each heading
   (copper, via `ink.in_accent`) or `\florilegiumbloom[motif]`, at the column's edge,
   shrunk or left out where there's no room. Then visitors on the stems: a snail on a
   main stem (40% of pages), a bird on its own twig (22%). Butterflies and bees are motif
   rows with `fly = true` (no branch, fixed caps of 2), allowed per page by the visitor stream.
10. Seasons (`g.age`; nil = summer, unchanged): `season(spring, summer, autumn)` blends a
   value; motif rows carry `spring`/`summer`/`autumn` weight multipliers (`budding` only in
   spring, `seedhead` only in autumn); the shorter stems end in buds or seed heads; young
   leaves are smaller and paler (ghost lift); autumn turns some leaves copper and drops
   petals below the flowers (`blooms`).
11. Animation (`g.anim`, set by `\florilegiumframe`): every step is an `event` (a stem
   that grows or a motif that opens), either in a phase (stems, ghost, marks, branch,
   fall, fill, accent, tail) or starting at a fraction `at` of its parent's growth. Output is tagged
   `{event, from, to}` (`ink.tag`); stems are also drawn as prefixes every GROWSTEP with a
   pointed tip, motifs at the BLOOM scales. `schedule()` times the events (T_* constants,
   ~13 s); `florilegium.lua` records once per garden and `ink.emit`s the visible pieces of
   each frame in painting order. The explained version adds a dashed disc per branch.
   `place(..., path, steps)` moves a motif along `path(e)` instead of opening it (visitors
   fly in, petals fall, the snail crawls with `till_end`).

To add a motif: write the primitive in `flora.lua` (origin at its base or center, axis
+y, takes `rng`), then add a row to `motifs` in `grow.lua` with `r(s)` (proxy radius),
`off(s)` (center back to the origin along the axis), `upright`, `layer`, `w`, `max`,
optionally `hard`/`hang`/`fly` and season multipliers, and `draw(rng, s)`. `authored.lua`
can then place it by name, and `\florilegiumbloom[name]` can ask for it.

## Ideas not done

- Cache the grown recording across frames/items in XeLaTeX shell-escape mode (every item is
  a separate texlua process that replays the page).
- Proxies of 2–3 discs for long motifs (leaves, cymes) instead of one disc.
- Read free space on every page (floats, display equations), not just the last.
- Leaf tips that curl over and show a paler underside, as in the reference image.
- Section flowers for KOMA/titlesec headings (only `\@sect`-based classes now).
- Initials in the authored composition's style for the first page, and a bigger, framed
  title-page tile.
- A mirrored right-margin variant for two-sided documents.
- Form XObjects for repeated sub-shapes (florets) to cut the PDF size further.
- A density/airiness option (SMALLEST, FILLMIN, caps) exposed in the `.sty`.
