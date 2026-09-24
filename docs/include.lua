-- include.lua - a pandoc Lua filter that splices one Markdown file into
-- another at build time.
--
-- PROVENANCE: written 2026-09-24 by Claude Code (model Claude Fable 5.1) at
-- Steve Shafer's request, so that the data-handling statement appears as a
-- section of the user guide WITHOUT a second copy of its text. The master
-- of that statement is docs/data-handling.md (README and the API guide
-- link to it, and its own HTML ships in the package); the guide asks for
-- it with one line. Pandoc has no include directive of its own, and
-- concatenating input files on the command line can only append at the
-- end, after References.
--
-- USE. A paragraph consisting solely of
--
--     {{include: docs/data-handling.md}}
--
-- is replaced by that file, parsed as pandoc Markdown, with any raw HTML
-- comment blocks (the file's own header comment) dropped. The path is
-- relative to the working directory, which for the commands in the two
-- files' header comments is the repository root. Headings are spliced at
-- the level they carry: a "# Heading" in the included file is a top-level
-- section of the guide, which is what the table of contents needs.
--
-- Pass it as:  --lua-filter docs/include.lua

function Para(el)
  local text = pandoc.utils.stringify(el)
  local path = text:match("^{{include:%s*(.-)%s*}}$")
  if not path then return nil end
  local f = io.open(path, "r")
  if not f then error("include.lua: cannot open " .. path) end
  local src = f:read("a")
  f:close()
  local blocks = pandoc.read(src, "markdown").blocks
  local kept = {}
  for _, b in ipairs(blocks) do
    local isComment = b.t == "RawBlock" and b.format == "html" and
                      b.text:match("^%s*<!%-%-") ~= nil
    if not isComment then table.insert(kept, b) end
  end
  return kept
end
