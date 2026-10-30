-- florilegium.lua -- the TeX-facing side of florilegium.sty: page geometry,
-- colors, seeds, the TikZ transform, and the dispatch of primitives.

local ink = require("ink")
local flora = require("flora")
local M = { ink = ink, flora = flora }

-- access to TeX, replaceable by a driver running outside it (XeLaTeX): dimen(name)
-- in sp, macro(name) as a string, error(msg)
function M.dimen(name) return tex.dimen[name] end
function M.macro(name) return token.get_macro(name) end
function M.error(msg)
  if tex and tex.error then tex.error(msg) else io.stderr:write(msg, "\n") end
end

local SP_CM = 2.54 / (72.27 * 65536)          -- cm per scaled point
local function cm(name) return M.dimen(name) * SP_CM end

-- two-sided documents (option book; the .sty or the XeLaTeX driver sets M.book): the garden
-- is in the outer margin. A verso (even page) has it on the left, as always, with the
-- text at \evensidemargin. A recto (odd page) is laid out as if its text were a left-margin
-- page's, with the text mirrored about the middle of the paper (textleft = pw - right
-- edge of the real text, ...), and ink.set_mirror turns the drawing around at the end.
-- The drawing's frame moves with \hoffset like the text, so the mirror is about pw - 2·hoffset.
M.book = false
local cur_page = 1                            -- \value{page} of the margin being drawn, see M.seed
local function mirrored() return M.book and cur_page % 2 == 1 end

-- the page layout, in cm from the lower-left corner of the paper
function M.geometry()
  local inch = 2.54
  local g = {
    pw = cm("paperwidth"), ph = cm("paperheight"),
    textleft = inch + cm("oddsidemargin"),
  }
  g.textright = g.textleft + cm("textwidth")
  if M.book then
    local left = inch + cm(cur_page % 2 == 1 and "oddsidemargin" or "evensidemargin")
    g.textleft, g.textright = left, left + cm("textwidth")
    if mirrored() then
      local w = g.pw - 2 * cm("hoffset")
      g.textleft, g.textright = w - g.textright, w - g.textleft
      g.mirrorw = w
    end
    g.mirror = mirrored()
  end
  g.ytop = g.ph - inch - cm("topmargin") - cm("headheight") - cm("headsep")
  g.ybot = g.ytop - cm("textheight")
  g.colright = g.textleft - 0.4
  g.headrule = g.ytop + cm("headsep") - 0.1
  g.footy = g.ybot - cm("footskip")
  return g
end

-- colors: `ink` sets the hue of the whole ramp, `accent` the copper
function M.colors(ir, ig, ib, ar, ag, ab)
  ink.set_ink(ir, ig, ib)
  ink.set_accent(ar, ag, ab)
end

-- one rng per page; primitives drawn from TeX fork it in call order
local page_rng = ink.rng(1)
function M.seed(page, fixed)
  cur_page = page
  local s = fixed and (fixed * 7919 + page * 131) or (page * 97 + 1030)
  page_rng = ink.rng(s)
  return s
end
-- for replay by a process that sees only some of the pages' draws: back to the state
-- before any page was seeded, and skip k draws of the page rng
function M.reset_rng() page_rng = ink.rng(1) end
function M.advance(k) for _ = 1, k do page_rng.fork() end end

-- the current pgf transformation (TikZ scopes) as an ink transform: local cm -> page bp
local function sync_transform()
  local C = ink.CM
  local bp = 72 / 72.27 / 65536
  ink.set_transform({
    tonumber(M.macro("pgf@pt@aa")) * C, tonumber(M.macro("pgf@pt@ab")) * C,
    tonumber(M.macro("pgf@pt@ba")) * C, tonumber(M.macro("pgf@pt@bb")) * C,
    M.dimen("pgf@pt@x") * bp, M.dimen("pgf@pt@y") * bp })
end

-- \florilegiumdraw{name}{s, opts}: one primitive at the origin of the current TikZ scope
local scaled = { leaf = true, leaflet = true, petal = true }
function M.draw(name, s, o)
  local fn = flora[name]
  if not fn then M.error("florilegium: unknown primitive '" .. tostring(name) .. "'") return end
  sync_transform()
  local rng = page_rng.fork()
  if name == "ghost" then
    flora.ghost(o and o.lift, function() M.draw_inner(s, o, rng) end)
  elseif scaled[name] then
    ink.scale(s or 1) fn(rng, o)
  else
    fn(rng, s, o)
  end
  ink.flush()
end
-- \florilegiumdraw{ghost}{"flower", {s=1.4}} draws any primitive pale
function M.draw_inner(name, o, rng)
  o = o or {}
  local fn = flora[name]
  if scaled[name] then ink.scale(o.s or 1) fn(rng, o) else fn(rng, o.s or 1, o) end
end

-- the header: a copper ivy leaf whose stem becomes the head rule
function M.head(g)
  ink.set_transform({ ink.CM, 0, 0, ink.CM, 0, 0 })
  ink.push()
  ink.translate(g.colright - 0.55, g.headrule + 0.02)
  local x, y = flora.hedera(page_rng.fork(), 0.36)
  ink.pop()
  local e = g.textright
  ink.moveto(x, y) ink.curveto(x + 1.0, y, x + 1.5, g.headrule, x + 2.5, g.headrule) ink.lineto(e, g.headrule)
  ink.stroke(ink.accent(0), 0.4)
  ink.circle(e, g.headrule, 0.03) ink.fill(ink.accent(0))
  ink.flush()
end

-- ---------------------------------------------------------------- marks in the text
-- \florilegiumbloom[motif] and (option sections) the section headings leave a
-- whatsit in the text. The page box is searched for them at shipout, when the
-- garden is drawn, so the garden knows the height of those lines on the same
-- page in the same run.
local MARK = 0x464C4F                         -- "FLO"
local marks = {}
function M.mark(kind, arg)
  marks[#marks + 1] = { kind = kind, arg = arg }
  local n = node.new("whatsit", "user_defined")
  n.user_id, n.type, n.value = MARK, 100, #marks
  node.write(n)
end

local HLIST, VLIST, GLUE, KERN, RULE, WHATSIT, USER     -- node ids, set on first use (no node library outside LuaTeX)
local function node_ids()
  HLIST, VLIST, GLUE, KERN, RULE, WHATSIT = node.id("hlist"), node.id("vlist"), node.id("glue"), node.id("kern"), node.id("rule"), node.id("whatsit")
  USER = node.subtype("user_defined")
end
-- walk a box list; y grows downward from the top of the outer box, x rightward
local function walk(head, parent, x, y, vertical, out)
  for n in node.traverse(head) do
    local id = n.id
    if id == HLIST or id == VLIST then
      if vertical then
        local base = y + n.height
        if n.list then walk(n.list, n, x + n.shift, id == VLIST and y or base, id == VLIST, out) end
        y = base + n.depth
      else
        local base = y + n.shift
        if n.list then walk(n.list, n, x, id == VLIST and base - n.height or base, id == VLIST, out) end
        x = x + n.width
      end
    elseif id == GLUE then
      local w = node.effective_glue(n, parent)
      if vertical then y = y + w else x = x + w end
    elseif id == KERN then
      if vertical then y = y + n.kern else x = x + n.kern end
    elseif id == RULE then
      if vertical then y = y + n.height + n.depth else x = x + n.width end
    elseif id == WHATSIT and n.subtype == USER and n.user_id == MARK then
      local m = marks[n.value]
      if m then out[#out + 1] = { kind = m.kind, arg = m.arg, x = x, y = y } end
    elseif not vertical then
      x = x + node.dimensions(n, n.next)
    end
  end
end
-- the marks on the page being shipped out, in page cm from the lower-left corner.
-- A table is a list of marks already in page cm (from a driver outside LuaTeX).
local function page_marks(box)
  if type(box) == "table" then return box end
  if not HLIST then node_ids() end
  local b = box and tex.box[box]
  if not b then return {} end
  local out = {}
  walk(b.list, b, 0, 0, b.id == VLIST, out)
  local ph, inch = tex.dimen.paperheight * SP_CM, 2.54
  for _, m in ipairs(out) do
    m.x = inch + tex.hoffset * SP_CM + m.x * SP_CM
    m.y = ph - inch - tex.voffset * SP_CM - m.y * SP_CM
  end
  return out
end

-- ---------------------------------------------------------------- initials
-- \florilegiuminitial: a tile of side `side` (sp) whose top is the cap height
-- above the current baseline and whose left edge is `hang` (sp) to the left of
-- the current point, the start of the paragraph's first, indented line.
M.initial_font = "lmroman10-bold.otf"
function M.initial(letter, side, hang, cap)
  local bp = 72 / 72.27 / 65536
  ink.set_transform({ ink.CM, 0, 0, ink.CM, -hang * bp, (cap - side) * bp })
  local ok, err = require("initial").draw(page_rng.fork(), side * SP_CM, letter, { font = M.initial_font })
  if not ok then M.error("florilegium: " .. tostring(err)) end
  ink.flush()
end
-- the letter is also typeset in the text, in PDF's invisible text rendering
-- mode, so that the paragraph still copies and searches as "This", not "his"
function M.hidden(on)
  local n = node.new("whatsit", "pdf_literal")
  n.mode = 1                                  -- page level, outside the text object
  n.data = on and "3 Tr" or "0 Tr"
  node.write(n)
end

-- ---------------------------------------------------------------- aging
-- a garden's age: 0 spring (buds), 0.5 summer, 1 autumn (seed heads, falling
-- petals); nil leaves it as it always was. \florilegiumage sets it; the option
-- aging spreads it over the document, from the page count of the last run.
M.age = nil
function M.auto_age(page, last) M.age = last > 1 and math.min(1, (page - 1) / (last - 1)) or 0.5 end

-- the growth animation: after \florilegiumframe[explain]{k}{n}, a grown page
-- shows frame k of n of its garden's growth (animation.tex, tools/animate.py).
-- The garden is recorded once and each frame writes the part grown so far.
local frame, recorded = nil, {}
function M.frame(k, n, explain) frame = { k = k, n = n, explain = explain == "explain" } end

local function grown_frame(g)
  local key = string.format("%d %d %.3f %s %d %s", g.seed, g.spill, g.spilly, tostring(g.age), #g.marks, tostring(g.mirror))
  if not recorded[key] then
    g.anim = true
    recorded = { [key] = require("grow").page(g) }      -- keep only the latest garden
  end
  local r = recorded[key]
  -- the last frame is the page: every event finished (r.total itself may round below)
  local t = frame.k >= frame.n and math.huge or r.total * (frame.k - 1) / math.max(1, frame.n - 1)
  ink.emit(r.rec, function(tag)
    if tag.overlay and not frame.explain then return false end
    local e = tag[1]
    local p = (t - e.t0) / e.dur
    return p >= tag[2] and (tag[3] == nil or p < tag[3])
  end)
end

-- run fn(g) with the page mirror on when this page of a two-sided document needs it
local function mirrored_draw(g, fn)
  if not g.mirror then return fn() end
  ink.set_mirror(g.mirrorw * ink.CM)
  local ok, err = pcall(fn)
  ink.set_mirror(nil)
  if not ok then error(err, 0) end
end

-- the grown composition for this page; M.visitors = false (option novisitors)
-- leaves out the butterflies, bees, snails and birds
M.visitors = true
function M.grown(seed, spill, spilly, box)
  local g = M.geometry()
  g.seed, g.spill, g.spilly, g.visitors, g.age = seed, spill, spilly, M.visitors, M.age
  g.marks = page_marks(box)
  if g.mirror then                            -- marks are where the text really is
    local marks = {}
    for i, m in ipairs(g.marks) do marks[i] = { kind = m.kind, arg = m.arg, x = g.mirrorw - m.x, y = m.y } end
    g.marks = marks
  end
  mirrored_draw(g, function()
    if frame then grown_frame(g) else require("grow").page(g) end
    M.head(g)
  end)
end

-- the authored composition for this page
function M.authored(seed)
  local g = M.geometry()
  g.seed, g.visitors = seed, M.visitors
  mirrored_draw(g, function()
    require("authored").page(g)
    M.head(g)
  end)
end

return M
