-- florilegium-xe.lua -- the XeLaTeX side of florilegium: draws the margins and the
-- inline drawings outside TeX, with the same Lua code that LuaLaTeX runs inside it.
--
-- florilegium-xetex.def (XeLaTeX) writes one Lua record per drawing (PAGE, MARK,
-- INITIAL, DRAW; format below). This script plays the records through florilegium.lua
-- with its TeX accessors stubbed, and writes the result as PDF pages that XeLaTeX
-- places with \special{pdf:image}: one page per item, in the order of the item ids.
--
--   texlua florilegium-xe.lua <base>
--       batch: reads <base>.flo, writes <base>-flo.pdf and <base>-flo.tex. Used by
--       the build without shell escape:
--           xelatex doc && texlua florilegium-xe.lua doc && xelatex doc
--   texlua florilegium-xe.lua --item <n> <base>
--       one item: reads <base>-item.flo (a record, and the marks of its page),
--       writes <base>-flo/<n>.pdf. Called by XeLaTeX itself, once per drawing, when
--       it is run with --shell-escape:  xelatex --shell-escape doc
--
-- Record format (a Lua chunk; PAGE{...} PAGE is a function in the reading environment):
--   PAGE{id, n, page, fixed, grown, visitors, aging, age, last, ink, accent, endpage,
--        endtotal, frame, book, paperwidth, paperheight, hoffset, voffset, oddsidemargin,
--        evensidemargin, textwidth, topmargin, headheight, headsep, textheight, footskip}
--       the margin of one page; n counts the shipped pages, page is \thepage; fixed is
--       \florilegiumseed or nil, age is the last \florilegiumage or nil, last the last
--       page of the previous run (option aging) or nil, book true when the option book is on
--       in a two-sided layout (florilegium.lua then picks the side from page and the margins),
--       endpage/endtotal the text end
--       (\florilegiumtextend; page, sp), frame {k, n, explain} or nil; lengths in sp
--   MARK{n, page, kind, arg, x, y}   a heading or \florilegiumbloom on shipped page n; x, y in
--       sp from the lower-left corner of the paper
--   INITIAL{id, letter, side, hang, cap, font, ink, accent, rng}   \florilegiuminitial
--   DRAW{id, name, args, aa, ab, ba, bb, x, y, ink, accent, rng}   \florilegiumdraw; args
--       is the Lua text of its second argument, aa..bb the pgf matrix, x, y the pgf origin
--       (sp)
--   rng = {page, fixed, k}: the page rng was last seeded for page `page` (nil: never), and
--       k other draws were taken from it since. An item replays this, so it can be
--       drawn on its own.
--
-- Environment: FLORILEGIUM_DUMP=<file> appends every content stream, as "length\n stream\n"
-- (to compare with LuaLaTeX's, see the XeLaTeX notes in florilegium-xetex.def).

local here = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = here .. "/?.lua;" .. package.path
if not pcall(require, "ink") then
  -- installed in a TEXMF tree: find the Lua files with kpathsea
  local p = kpse.find_file("ink.lua", "lua") or kpse.find_file("ink.lua", "tex")
  if p then package.path = p:match("^(.*)[/\\][^/\\]*$") .. "/?.lua;" .. package.path end
end

local item_mode, base, item_no
do
  local a = { table.unpack(arg) }
  if a[1] == "--item" then item_mode, item_no, base = true, tonumber(a[2]), a[3] else base = a[1] end
  if not base or (item_mode and not item_no) then
    io.stderr:write("usage: texlua florilegium-xe.lua <base>\n       texlua florilegium-xe.lua --item <n> <base>\n")
    os.exit(2)
  end
end

local M = require("florilegium")
local ink = M.ink
-- load everything now: initial.lua starts luaotfload's font reader, which resets package.path
for _, m in ipairs({ "grow", "authored", "initial" }) do require(m) end
if item_mode then texio.write_nl = function() end end        -- the growth report of grow.lua

-- ---------------------------------------------------------------- the TeX stubs
local SP_BP = 72 / 72.27 / 65536
local dims, macros = {}, {}
M.dimen = function(name) return dims[name] end
M.macro = function(name) return macros[name] end

local streams, extgs = {}, {}
local dump = os.getenv("FLORILEGIUM_DUMP") and io.open(os.getenv("FLORILEGIUM_DUMP"), "ab")
ink.backend.literal = function(s)
  streams[#streams + 1] = s
  if dump then dump:write(#s, "\n", s, "\n") end
end
ink.backend.extgs = function(name, dict) extgs[name] = dict end

-- ---------------------------------------------------------------- the records
local items, pages = {}, {}
local env = {
  PAGE = function(t) t.kind = "page" items[#items + 1] = t pages[t.n] = t end,
  INITIAL = function(t) t.kind = "initial" items[#items + 1] = t end,
  DRAW = function(t) t.kind = "draw" items[#items + 1] = t end,
  MARK = function(t)
    local p = pages[t.n]
    if p then p.marks = p.marks or {} p.marks[#p.marks + 1] = t end
  end,
}
local text
do
  local f = io.open(base .. (item_mode and "-item.flo" or ".flo"), "rb")
  if not f then io.stderr:write("florilegium-xe: no ", base, item_mode and "-item.flo" or ".flo", "\n") os.exit(1) end
  text = f:read("a")
  f:close()
  if item_mode then os.remove(base .. "-item.flo") end
end
assert(load(text, "=" .. base .. ".flo", "t", env))()

-- ---------------------------------------------------------------- playing an item
local function colors(d)
  M.colors(d.ink[1], d.ink[2], d.ink[3], d.accent[1], d.accent[2], d.accent[3])
end
-- the page rng as the item finds it in LuaTeX (see the rng field above)
local function replay(r)
  if r.page then M.seed(r.page, r.fixed) else M.reset_rng() end
  M.advance(r.k)
end

local SP_CM = 2.54 / (72.27 * 65536)
local ORIGIN = 4736286                     -- 1in in sp
local function page(d)
  dims = d
  colors(d)
  local seed = M.seed(d.page, d.fixed)
  M.visitors = d.visitors
  M.book = d.book
  if d.grown then
    if d.frame then M.frame(d.frame.k, d.frame.n, d.frame.explain) end
    M.age = d.age
    if d.aging and d.last then M.auto_age(d.page, d.last) end
    -- XeTeX counts from the paper's lower-left corner, florilegium.lua's page_marks from
    -- the page box (1 in, i.e. 4736286 sp, in and down), and in cm: do that sum the same way
    local marks = {}
    for _, m in ipairs(d.marks or {}) do
      local bx = m.x - ORIGIN - d.hoffset
      local by = d.paperheight - ORIGIN - d.voffset - m.y
      marks[#marks + 1] = { kind = m.kind, arg = m.arg,
        x = 2.54 + d.hoffset * SP_CM + bx * SP_CM,
        y = d.paperheight * SP_CM - 2.54 - d.voffset * SP_CM - by * SP_CM }
    end
    if d.endpage == d.page then
      M.grown(seed, 1, M.geometry().ytop - d.endtotal * 2.54 / (72.27 * 65536), marks)
    else
      M.grown(seed, 0, 0, marks)
    end
  else
    M.authored(seed)
  end
end

local function initial(d)
  colors(d)
  replay(d.rng)
  M.initial_font = d.font
  M.initial(d.letter, d.side, d.hang, d.cap)
end

local function draw(d)
  colors(d)
  replay(d.rng)
  dims = { ["pgf@pt@x"] = d.x, ["pgf@pt@y"] = d.y }
  macros = { ["pgf@pt@aa"] = d.aa, ["pgf@pt@ab"] = d.ab, ["pgf@pt@ba"] = d.ba, ["pgf@pt@bb"] = d.bb }
  local call = assert(load("local florilegium = ... return florilegium.draw(" .. string.format("%q", d.name) .. ", " .. d.args .. ")",
    "=\\florilegiumdraw{" .. d.name .. "}"))
  call(M)
end

-- an inline item (initial, drawing) is drawn relative to the current point in every
-- direction; its PDF page is [0 0 2D 2D] with the drawing shifted by (D, D), and the
-- .def shifts the image back. D is a constant of florilegium-xetex.def too.
local D = 1200

local function play(d)
  streams = {}
  if d.kind == "page" then page(d) elseif d.kind == "initial" then initial(d) else draw(d) end
  local body = table.concat(streams, "\n")
  if d.kind == "page" then
    return { data = body, w = d.paperwidth * SP_BP, h = d.paperheight * SP_BP }
  end
  return { data = string.format("1 0 0 1 %d %d cm\n", D, D) .. body, w = 2 * D, h = 2 * D }
end

-- ---------------------------------------------------------------- the PDF
-- a minimal PDF: one page per item with a compressed content stream, and one shared
-- ExtGState dictionary for the opacities and the multiply blend
local function write_pdf(path, list)
  local objs = {}
  local function obj(s) objs[#objs + 1] = s return #objs end
  local names, gsdict = {}, {}
  for k in pairs(extgs) do names[#names + 1] = k end
  table.sort(names)
  for _, k in ipairs(names) do gsdict[#gsdict + 1] = "/" .. k .. " " .. extgs[k] end
  local catalog, pagesobj = obj(false), obj(false)
  local gsobj = obj("<< " .. table.concat(gsdict, " ") .. " >>")
  local refs = {}
  for i, it in ipairs(list) do
    local z = zlib.compress(it.data)
    local c = obj(string.format("<< /Length %d /Filter /FlateDecode >>\nstream\n%s\nendstream", #z, z))
    local pg = obj(string.format(
      "<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %.5f %.5f] /Contents %d 0 R /Resources << /ExtGState %d 0 R >> >>",
      pagesobj, it.w, it.h, c, gsobj))
    refs[i] = pg .. " 0 R"
  end
  objs[catalog] = string.format("<< /Type /Catalog /Pages %d 0 R >>", pagesobj)
  objs[pagesobj] = string.format("<< /Type /Pages /Kids [%s] /Count %d >>", table.concat(refs, " "), #list)
  local buf, offs = { "%PDF-1.5\n%\xE2\xE3\xCF\xD3\n" }, {}
  local pos = #buf[1]
  for i, o in ipairs(objs) do
    offs[i] = pos
    local s = string.format("%d 0 obj\n%s\nendobj\n", i, o)
    buf[#buf + 1] = s
    pos = pos + #s
  end
  local xref = { string.format("xref\n0 %d\n0000000000 65535 f \n", #objs + 1) }
  for i = 1, #objs do xref[#xref + 1] = string.format("%010d 00000 n \n", offs[i]) end
  buf[#buf + 1] = table.concat(xref)
  buf[#buf + 1] = string.format("trailer\n<< /Size %d /Root %d 0 R >>\nstartxref\n%d\n%%%%EOF\n", #objs + 1, catalog, pos)
  local o = assert(io.open(path, "wb"))
  o:write(table.concat(buf))
  o:close()
end

-- ---------------------------------------------------------------- main
if item_mode then
  local dir = base .. "-flo"
  lfs.mkdir(dir)
  local path = string.format("%s/%d.pdf", dir, item_no)
  os.remove(path)                              -- no stale drawing if this fails
  local d = assert(items[1], "florilegium-xe: no item in " .. base .. "-item.flo")
  write_pdf(path, { play(d) })
else
  if #items == 0 then
    io.stderr:write("florilegium-xe: no drawings in ", base, ".flo (a run with --shell-escape draws as it goes",
      " and leaves only the marks there)\n")
  end
  table.sort(items, function(a, b) return a.id < b.id end)
  local list = {}
  for i, d in ipairs(items) do
    if d.id ~= i then error(string.format("florilegium-xe: item ids are not 1..n (found %s at %d)", tostring(d.id), i)) end
    list[i] = play(d)
  end
  write_pdf(base .. "-flo.pdf", list)
  -- last: the .def reads this to learn what the PDF holds and which .flo it was drawn from
  local o = assert(io.open(base .. "-flo.tex", "wb"))
  o:write(string.format("\\csname flo@drawn\\endcsname{%d}{%s}\n", #list, md5.sumhexa(text):upper()))
  o:close()
  io.stderr:write(string.format("florilegium-xe: %d drawings -> %s-flo.pdf\n", #list, base))
end
