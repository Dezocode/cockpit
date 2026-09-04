-- Cockpit BENCH: ghui Miller drill on the FILES/nvim surface family.
-- Read-only Proctor mirror: L1 models → L2 runs → L3 run+backlinks.
local M = {}

local NAV_LEFT = "cockpit · MEMORY  COMPUTERS  MODELS  BENCH  FILES  PRS"
local NAV_RIGHT = "BENCH  ghui  read-only"
local NS = vim.api.nvim_create_namespace("CockpitBench")

local PUNCH_CYAN = "#5ccfe6"
local PUNCH_GOLD = "#e6c07b"
local PUNCH_GOLD_LABEL = "#f5c962"
local CHIP_BG = "#2a2418"

local state = {
  focus_col = 0,
  model_idx = 0,
  run_idx = 0,
  bl_idx = 0,
  jump_stack = {},
  models = {},
  runs = {},
  run = nil,
  backlinks = {},
  absent = false,
  wins = {},
  bufs = {},
  chip_rows = {},
}

local function db_path()
  return vim.env.COCKPIT_BENCH_DB or ""
end

local function display_root()
  return vim.env.COCKPIT_BENCH_ROOT or ""
end

local function display_data_path(path)
  local home = vim.fn.expand("~")
  if vim.startswith(path, home) then
    return "~" .. path:sub(#home + 1)
  end
  return path
end

local function sqlite_lines(query)
  local db = db_path()
  if db == "" or vim.fn.filereadable(db) ~= 1 then
    return nil
  end
  local cmd = string.format(
    'sqlite3 -readonly -noheader -separator "\t" %s %s',
    vim.fn.shellescape(db),
    vim.fn.shellescape(query)
  )
  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    return nil
  end
  local lines = {}
  for line in vim.gsplit(vim.trim(out), "\n", { plain = true, trimempty = true }) do
    table.insert(lines, line)
  end
  return lines
end

local function model_site(agent_class)
  if not agent_class or agent_class == "" then
    return "ABSENT"
  end
  if agent_class == "local" then
    return "local"
  end
  if agent_class:find("frontier", 1, true) then
    return "frontier"
  end
  return agent_class
end

local function fetch_models()
  local lines = sqlite_lines("SELECT model_id, agent_class FROM models ORDER BY model_id;")
  if not lines then
    return {}
  end
  local models = {}
  for _, line in ipairs(lines) do
    local model_id, agent_class = line:match("([^\t]*)\t(.*)")
    if model_id and model_id ~= "" then
      table.insert(models, { model_id, model_id, agent_class or "" })
    end
  end
  return models
end

local function fetch_runs(model_id)
  local esc = model_id:gsub("'", "''")
  local lines = sqlite_lines(string.format([[
SELECT run_id, model_id,
       COALESCE(role, '') AS role,
       COALESCE(campaign, '') AS campaign,
       COALESCE(disposition, 'ABSENT') AS status,
       COALESCE(scored_at, '') AS scored_at
FROM runs WHERE model_id = '%s' ORDER BY scored_at DESC, run_id;
]], esc))
  if not lines then
    return {}
  end
  local runs = {}
  for _, line in ipairs(lines) do
    local run_id, mid, role, campaign, status, scored_at = line:match(
      "([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)"
    )
    if run_id and run_id ~= "" then
      table.insert(runs, {
        run_id = run_id,
        model_id = mid,
        role = role,
        campaign = campaign,
        status = status,
        scored_at = scored_at,
      })
    end
  end
  return runs
end

local function fetch_run(run_id)
  local esc = run_id:gsub("'", "''")
  local lines = sqlite_lines(string.format([[
SELECT r.run_id, r.model_id, m.agent_class,
       COALESCE(r.role, '') AS role,
       COALESCE(r.campaign, '') AS campaign,
       COALESCE(r.disposition, 'ABSENT') AS status,
       COALESCE(r.scored_at, '') AS scored_at
FROM runs r JOIN models m ON m.model_id = r.model_id
WHERE r.run_id = '%s' LIMIT 1;
]], esc))
  if not lines or #lines == 0 then
    return nil
  end
  local line = lines[1]
  local rid, mid, agent_class, role, campaign, status, scored_at = line:match(
    "([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)"
  )
  if not rid or rid == "" then
    return nil
  end
  return {
    run_id = rid,
    model_id = mid,
    agent_class = agent_class,
    role = role,
    campaign = campaign,
    status = status,
    scored_at = scored_at,
  }
end

local function fetch_backlinks(run_id)
  local esc = run_id:gsub("'", "''")
  local lines = sqlite_lines(string.format([[
SELECT rl.to_run_id, rl.link_kind, r.model_id
FROM run_links rl JOIN runs r ON r.run_id = rl.to_run_id
WHERE rl.from_run_id = '%s' ORDER BY rl.link_kind, rl.to_run_id;
]], esc))
  if not lines then
    return {}
  end
  local links = {}
  for _, line in ipairs(lines) do
    local to_run_id, link_kind, model_id = line:match("([^\t]*)\t([^\t]*)\t(.*)")
    if to_run_id and to_run_id ~= "" then
      table.insert(links, {
        to_run_id = to_run_id,
        link_kind = link_kind,
        model_id = model_id,
      })
    end
  end
  return links
end

local function setup_highlights()
  local colors = {
    cyan = PUNCH_CYAN,
    gold = PUNCH_GOLD,
    gold_label = PUNCH_GOLD_LABEL,
    dim = "#6c7086",
    chrome = "#cdd6f4",
    chip_bg = CHIP_BG,
  }
  local path = vim.env.COCKPIT_THEME_COLORS_FILE
    or vim.fn.expand("~/.local/state/omarchy/current/theme/colors.toml")
  if vim.fn.filereadable(path) == 1 then
    for _, line in ipairs(vim.fn.readfile(path)) do
      local key, value = line:match("^%s*([%w_]+)%s*=%s*[\"']?(#[%x]+)")
      if key and value and value:match("^#%x%x%x%x%x%x$") then
        if key == "muted" or key == "bright_foreground" then
          colors.dim = value
        elseif key == "foreground" then
          colors.chrome = value
        elseif key == "yellow" then
          colors.gold_label = value
        end
      end
    end
  end
  vim.api.nvim_set_hl(0, "TabLine", { bg = "NONE", fg = colors.dim })
  vim.api.nvim_set_hl(0, "TabLineFill", { bg = "NONE" })
  vim.api.nvim_set_hl(0, "CockpitBenchSel", { fg = colors.cyan, bold = true })
  vim.api.nvim_set_hl(0, "CockpitBenchGoldLabel", { fg = colors.gold_label, bold = true })
  vim.api.nvim_set_hl(0, "CockpitBenchYellow", { fg = colors.gold, bold = true })
  vim.api.nvim_set_hl(0, "CockpitBenchDim", { fg = colors.dim })
  vim.api.nvim_set_hl(0, "CockpitBenchChrome", { fg = colors.chrome })
  vim.api.nvim_set_hl(0, "CockpitBenchNavLeft", { fg = colors.chrome })
  vim.api.nvim_set_hl(0, "CockpitBenchNavBench", { fg = colors.cyan, bold = true })
  vim.api.nvim_set_hl(0, "CockpitBenchNavRight", { fg = colors.cyan, bold = true })
  vim.api.nvim_set_hl(0, "CockpitBenchChip", { fg = colors.gold, bg = colors.chip_bg, bold = true })
  vim.api.nvim_set_hl(0, "CockpitBenchChipSel", { fg = colors.gold, bg = colors.chip_bg, bold = true, underline = true })
  vim.api.nvim_set_hl(0, "CockpitBenchChipBorder", { fg = colors.gold })
end

local function strwidth(text)
  return vim.fn.strdisplaywidth(text)
end

local function clip(text, width)
  if width <= 0 then
    return ""
  end
  if strwidth(text) <= width then
    return text
  end
  local out = ""
  local w = 0
  for i = 1, #text do
    local ch = vim.fn.strcharpart(text, i - 1, 1)
    local cw = vim.fn.strdisplaywidth(ch)
    if w + cw > width then
      break
    end
    out = out .. ch
    w = w + cw
  end
  return out
end

local function center_text(text, width)
  if strwidth(text) >= width then
    return clip(text, width)
  end
  local left = math.floor((width - strwidth(text)) / 2)
  return string.rep(" ", left) .. text .. string.rep(" ", width - strwidth(text) - left)
end

local function truncate_run_id(run_id, width)
  width = width or 12
  if strwidth(run_id) <= width then
    return run_id
  end
  return clip(run_id, 8) .. "..."
end

local function set_buffer_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function clear_ns(buf)
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
end

local function column_width(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return math.max(12, math.floor(vim.o.columns / 3) - 1)
  end
  return vim.api.nvim_win_get_width(win) - 1
end

function M.render_models_col()
  local win = state.wins[1]
  local buf = state.bufs[1]
  if not win or not buf then
    return
  end
  local width = column_width(win)
  local lines = { "Models", "" }
  for i, item in ipairs(state.models) do
    local mid = item[1]
    local agent_class = item[3] or ""
    local site = model_site(agent_class)
    local selected = state.focus_col == 0 and i - 1 == state.model_idx
    local cursor = selected and ">" or " "
    local name_w = math.max(8, width - strwidth(site) - 4)
    local name_part = clip(mid, name_w)
    local pad = math.max(1, width - strwidth(cursor .. " " .. name_part) - strwidth(site))
    local row = cursor .. " " .. name_part .. string.rep(" ", pad) .. site
    table.insert(lines, row)
  end
  if #state.models == 0 then
    table.insert(lines, "ABSENT")
  end
  set_buffer_lines(buf, lines)
  clear_ns(buf)
  local row = 2
  for i, item in ipairs(state.models) do
    local site = model_site(item[3] or "")
    local line = lines[row + 1] or ""
    local site_start = math.max(0, #line - #site)
    local selected = state.focus_col == 0 and i - 1 == state.model_idx
    if selected then
      vim.api.nvim_buf_add_highlight(buf, NS, "CockpitBenchSel", row, 0, -1)
    end
    if site == "ABSENT" then
      vim.api.nvim_buf_add_highlight(buf, NS, "CockpitBenchDim", row, site_start, #line)
    elseif selected then
      vim.api.nvim_buf_add_highlight(buf, NS, "CockpitBenchDim", row, site_start, #line)
    end
    row = row + 1
  end
  if #state.models == 0 then
    vim.api.nvim_buf_add_highlight(buf, NS, "CockpitBenchDim", 2, 0, -1)
  else
    vim.api.nvim_buf_add_highlight(buf, NS, "CockpitBenchChrome", 0, 0, -1)
  end
end

function M.render_runs_col()
  local win = state.wins[2]
  local buf = state.bufs[2]
  if not win or not buf then
    return
  end
  local width = column_width(win)
  local model = state.models[state.model_idx + 1]
  local model_id = model and model[1] or nil
  local title = model_id and ("Runs — " .. model_id) or "Runs"
  local lines = { clip(title, width), "" }
  if not model_id or #state.runs == 0 then
    table.insert(lines, "ABSENT")
  else
    for i, run in ipairs(state.runs) do
      local selected = state.focus_col == 1 and i - 1 == state.run_idx
      local cursor = selected and ">" or " "
      table.insert(lines, string.format("%s %s", cursor, clip(run.run_id, width - 3)))
      table.insert(lines, clip(run.status or "ABSENT", width - 2))
    end
  end
  set_buffer_lines(buf, lines)
  clear_ns(buf)
  vim.api.nvim_buf_add_highlight(buf, NS, "CockpitBenchChrome", 0, 0, -1)
  if not model_id or #state.runs == 0 then
    vim.api.nvim_buf_add_highlight(buf, NS, "CockpitBenchDim", 2, 0, -1)
    return
  end
  local row = 2
  for i in ipairs(state.runs) do
    if state.focus_col == 1 and i - 1 == state.run_idx then
      vim.api.nvim_buf_add_highlight(buf, NS, "CockpitBenchSel", row, 0, -1)
    end
    vim.api.nvim_buf_add_highlight(buf, NS, "CockpitBenchDim", row + 1, 0, -1)
    row = row + 2
  end
end

local function draw_backlink_chip_lines(kind, run_id, width)
  local inner = math.max(1, width - 2)
  local label = clip(kind or "backlink", inner)
  local rid = truncate_run_id(run_id, inner)
  local top = "+" .. string.rep("-", inner) .. "+"
  local mid1 = "|" .. center_text(label, inner) .. "|"
  local mid2 = "|" .. center_text(rid, inner) .. "|"
  local bot = "+" .. string.rep("-", inner) .. "+"
  return { top, mid1, mid2, bot }
end

function M.render_detail_col()
  local win = state.wins[3]
  local buf = state.bufs[3]
  if not win or not buf then
    return
  end
  local width = column_width(win)
  local lines = { "Run + backlinks", "" }
  state.chip_rows = {}
  if not state.run then
    table.insert(lines, "ABSENT")
  else
    table.insert(lines, "run_id (selected)")
    table.insert(lines, clip(state.run.run_id, width))
    local meta_parts = {}
    for _, value in ipairs({
      state.run.model_id,
      state.run.agent_class,
      state.run.role,
      state.run.campaign,
      state.run.status,
    }) do
      if value and value ~= "" then
        table.insert(meta_parts, value)
      end
    end
    local metadata = table.concat(meta_parts, " · ")
    if metadata ~= "" then
      table.insert(lines, clip(metadata, width))
    end
    table.insert(lines, "")
    table.insert(lines, "Backlinks (Enter → jump)")
    table.insert(lines, "")
    if #state.backlinks == 0 then
      table.insert(lines, "ABSENT")
    else
      for i, link in ipairs(state.backlinks) do
        local chip_w = math.min(22, math.max(14, width - 4))
        local chip_lines = draw_backlink_chip_lines(link.link_kind, link.to_run_id, chip_w)
        local chip_row = #lines
        for _, cl in ipairs(chip_lines) do
          table.insert(lines, cl)
        end
        table.insert(state.chip_rows, {
          start = chip_row,
          bl_idx = i - 1,
          selected = state.focus_col == 2 and i - 1 == state.bl_idx,
        })
        table.insert(lines, "")
      end
    end
  end
  set_buffer_lines(buf, lines)
  clear_ns(buf)
  vim.api.nvim_buf_add_highlight(buf, NS, "CockpitBenchChrome", 0, 0, -1)
  if not state.run then
    vim.api.nvim_buf_add_highlight(buf, NS, "CockpitBenchDim", 2, 0, -1)
    return
  end
  vim.api.nvim_buf_add_highlight(buf, NS, "CockpitBenchGoldLabel", 2, 0, -1)
  local bl_header = 0
  for i, line in ipairs(lines) do
    if line == "Backlinks (Enter → jump)" then
      bl_header = i - 1
      break
    end
  end
  if bl_header > 0 then
    vim.api.nvim_buf_add_highlight(buf, NS, "CockpitBenchGoldLabel", bl_header, 0, -1)
  end
  for _, chip in ipairs(state.chip_rows) do
    local border_group = "CockpitBenchChipBorder"
    local inner_group = chip.selected and "CockpitBenchChipSel" or "CockpitBenchChip"
    for r = chip.start, chip.start + 3 do
      local line = lines[r + 1] or ""
      if line:sub(1, 1) == "+" or line:sub(1, 1) == "|" then
        vim.api.nvim_buf_add_highlight(buf, NS, border_group, r, 0, 1)
        vim.api.nvim_buf_add_highlight(buf, NS, border_group, r, #line, #line + 1)
      end
      if r == chip.start + 1 or r == chip.start + 2 then
        vim.api.nvim_buf_add_highlight(buf, NS, inner_group, r, 1, #line)
      end
    end
  end
end

function M.draw_vrules()
  for _, win in ipairs(state.wins) do
    if vim.api.nvim_win_is_valid(win) then
      vim.wo[win].signcolumn = "no"
      vim.wo[win].statusline = ""
    end
  end
end

local function current_model_id()
  local model = state.models[state.model_idx + 1]
  return model and model[1] or nil
end

local function current_run_id()
  local run = state.runs[state.run_idx + 1]
  return run and run.run_id or nil
end

local function sync_data()
  if state.absent then
    state.models = {}
    state.runs = {}
    state.run = nil
    state.backlinks = {}
    return
  end
  state.models = fetch_models()
  if state.model_idx >= #state.models then
    state.model_idx = math.max(0, #state.models - 1)
  end
  local model_id = current_model_id()
  state.runs = model_id and fetch_runs(model_id) or {}
  if state.run_idx >= #state.runs then
    state.run_idx = math.max(0, #state.runs - 1)
  end
  local run_id = current_run_id()
  state.run = run_id and fetch_run(run_id) or nil
  state.backlinks = run_id and fetch_backlinks(run_id) or {}
  if state.bl_idx >= #state.backlinks then
    state.bl_idx = math.max(0, #state.backlinks - 1)
  end
end

local function select_run_by_id(run_id)
  local run = fetch_run(run_id)
  if not run then
    return false
  end
  for i, model in ipairs(state.models) do
    if model[1] == run.model_id then
      state.model_idx = i - 1
      break
    end
  end
  state.runs = fetch_runs(run.model_id)
  for i, r in ipairs(state.runs) do
    if r.run_id == run_id then
      state.run_idx = i - 1
      state.focus_col = 1
      return true
    end
  end
  return false
end

function M.render_absent()
  vim.cmd("only")
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  set_buffer_lines(buf, {
    "",
    "BENCH  ABSENT",
    "",
    "BENCH unavailable: Proctor bench receipt is missing or incomplete.",
    "Expected a readable ~/intercom/proctor/ mirror with db/runs.sqlite.",
    "Cockpit does not write scores; Proctor is the sole writer.",
  })
  vim.api.nvim_buf_add_highlight(buf, NS, "CockpitBenchNavRight", 1, 0, -1)
  vim.api.nvim_buf_add_highlight(buf, NS, "CockpitBenchYellow", 1, 7, -1)
end

function M.render_all()
  sync_data()
  if state.absent then
    M.render_absent()
    return
  end
  M.render_models_col()
  M.render_runs_col()
  M.render_detail_col()
  M.draw_vrules()
end

local function resize_columns()
  if state.absent or #state.wins < 3 then
    return
  end
  local width = vim.o.columns
  local c1 = math.max(12, math.floor(width / 3))
  local c2 = math.max(12, math.floor((width * 2) / 3) - c1)
  local c3 = math.max(12, width - c1 - c2)
  pcall(function()
    vim.api.nvim_win_set_width(state.wins[1], c1)
    vim.api.nvim_win_set_width(state.wins[2], c2)
    vim.api.nvim_win_set_width(state.wins[3], c3)
  end)
end

local function focus_window()
  local win = state.wins[state.focus_col + 1]
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
end

local function on_enter()
  if state.focus_col == 0 then
    state.focus_col = 1
  elseif state.focus_col == 1 then
    state.focus_col = 2
  elseif state.focus_col == 2 and #state.backlinks > 0 then
    local link = state.backlinks[state.bl_idx + 1]
    if link then
      local run_id = current_run_id()
      if run_id then
        table.insert(state.jump_stack, run_id)
      end
      select_run_by_id(link.to_run_id)
      state.bl_idx = 0
    end
  end
  M.render_all()
  focus_window()
end

local function on_escape()
  if #state.jump_stack > 0 then
    local prev = table.remove(state.jump_stack)
    select_run_by_id(prev)
  elseif state.focus_col > 0 then
    state.focus_col = state.focus_col - 1
  end
  M.render_all()
  focus_window()
end

local function move_up()
  if state.focus_col == 0 and state.model_idx > 0 then
    state.model_idx = state.model_idx - 1
    state.run_idx = 0
    state.bl_idx = 0
  elseif state.focus_col == 1 and state.run_idx > 0 then
    state.run_idx = state.run_idx - 1
    state.bl_idx = 0
  elseif state.focus_col == 2 and state.bl_idx > 0 then
    state.bl_idx = state.bl_idx - 1
  end
  M.render_all()
end

local function move_down()
  if state.focus_col == 0 and state.model_idx < #state.models - 1 then
    state.model_idx = state.model_idx + 1
    state.run_idx = 0
    state.bl_idx = 0
  elseif state.focus_col == 1 and state.run_idx < #state.runs - 1 then
    state.run_idx = state.run_idx + 1
    state.bl_idx = 0
  elseif state.focus_col == 2 and state.bl_idx < #state.backlinks - 1 then
    state.bl_idx = state.bl_idx + 1
  end
  M.render_all()
end

local function col_for_buf(buf)
  for i, b in ipairs(state.bufs) do
    if b == buf then
      return i - 1
    end
  end
  return nil
end

local function chip_at_line(line0)
  for _, chip in ipairs(state.chip_rows) do
    if line0 >= chip.start and line0 <= chip.start + 3 then
      return chip.bl_idx
    end
  end
  return nil
end

local function on_mouse(line0, col)
  if state.absent then
    return
  end
  line0 = math.max(0, line0)
  local prev_col = state.focus_col
  local prev_idx
  if col == 0 then
    prev_idx = state.model_idx
    if line0 < 2 or line0 - 2 >= #state.models then
      state.focus_col = 0
      focus_window()
      return
    end
    state.focus_col = 0
    state.model_idx = line0 - 2
    state.run_idx = 0
    state.bl_idx = 0
    M.render_all()
    if prev_col == 0 and prev_idx == state.model_idx then
      on_enter()
    else
      focus_window()
    end
  elseif col == 1 then
    prev_idx = state.run_idx
    if line0 < 2 then
      state.focus_col = 1
      focus_window()
      return
    end
    local idx = math.floor((line0 - 2) / 2)
    if idx >= #state.runs then
      state.focus_col = 1
      focus_window()
      return
    end
    state.focus_col = 1
    state.run_idx = idx
    state.bl_idx = 0
    M.render_all()
    if prev_col == 1 and prev_idx == state.run_idx then
      on_enter()
    else
      focus_window()
    end
  elseif col == 2 then
    state.focus_col = 2
    local bl = chip_at_line(line0)
    if bl ~= nil then
      state.bl_idx = bl
      M.render_all()
      on_enter()
      return
    end
    focus_window()
  end
end

local function setup_keymaps()
  local opts = { silent = true, nowait = true }
  local function map(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, opts)
  end
  map("j", move_down)
  map("<Down>", move_down)
  map("k", move_up)
  map("<Up>", move_up)
  map("<Tab>", function()
    state.focus_col = math.min(2, state.focus_col + 1)
    focus_window()
  end)
  map("<S-Tab>", function()
    state.focus_col = math.max(0, state.focus_col - 1)
    focus_window()
  end)
  map("<Left>", function()
    state.focus_col = math.max(0, state.focus_col - 1)
    focus_window()
  end)
  map("<Right>", function()
    state.focus_col = math.min(2, state.focus_col + 1)
    focus_window()
  end)
  map("<CR>", on_enter)
  map("<Esc>", on_escape)
  map("q", function()
    if vim.env.COCKPIT_BENCH_ONCE == "1" then
      vim.cmd("quitall!")
    end
  end)
end

local function setup_mouse()
  vim.o.mouse = "a"
  local group = vim.api.nvim_create_augroup("CodexCockpitBenchMouse", { clear = true })
  for _, buf in ipairs(state.bufs) do
    vim.keymap.set("n", "<LeftMouse>", function()
      local line0 = vim.api.nvim_win_get_cursor(0)[1] - 1
      local col = col_for_buf(vim.api.nvim_get_current_buf())
      if col ~= nil then
        on_mouse(line0, col)
      end
    end, { buffer = buf, silent = true, nowait = true })
  end
  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      if col_for_buf(buf) == nil then
        return
      end
      if vim.b[buf].cockpit_bench_mouse then
        return
      end
      vim.b[buf].cockpit_bench_mouse = true
      vim.keymap.set("n", "<LeftMouse>", function()
        local line0 = vim.api.nvim_win_get_cursor(0)[1] - 1
        local col = col_for_buf(vim.api.nvim_get_current_buf())
        if col ~= nil then
          on_mouse(line0, col)
        end
      end, { buffer = buf, silent = true, nowait = true })
    end,
  })
end

function M.tabline()
  local width = vim.o.columns
  local left = clip(NAV_LEFT, math.max(1, width - strwidth(NAV_RIGHT) - 2))
  local pad = math.max(0, width - strwidth(left) - strwidth(NAV_RIGHT))
  local bench_pos = left:find("BENCH", 1, true)
  if bench_pos then
    local before = left:sub(1, bench_pos - 1)
    local after = left:sub(bench_pos + 5)
    return table.concat({
      "%#CockpitBenchNavLeft#",
      before,
      "%#CockpitBenchNavBench#",
      "BENCH",
      "%#CockpitBenchNavLeft#",
      after,
      string.rep(" ", pad),
      "%#CockpitBenchNavRight#",
      NAV_RIGHT,
    })
  end
  return "%#CockpitBenchNavLeft#" .. left .. string.rep(" ", pad) .. "%#CockpitBenchNavRight#" .. NAV_RIGHT
end

function M.statusline()
  local footer = string.format(
    "t524u ghui · Esc=pop Enter=drill/backlink · data: %s/ · writer: Proctor",
    display_data_path(display_root())
  )
  return "%#CockpitBenchDim#" .. clip(footer, vim.o.columns)
end

local function create_layout()
  vim.cmd("enew")
  vim.cmd("vsplit")
  vim.cmd("vsplit")
  local wins = vim.api.nvim_list_wins()
  table.sort(wins, function(a, b)
    return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
  end)
  state.wins = wins
  state.bufs = {}
  for i, win in ipairs(wins) do
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, buf)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].signcolumn = "no"
    vim.wo[win].foldcolumn = "0"
    vim.wo[win].wrap = false
    vim.wo[win].statusline = ""
    state.bufs[i] = buf
  end
  resize_columns()
  focus_window()
end

function M.refresh()
  M.render_all()
end

function M.setup()
  state.absent = vim.env.COCKPIT_BENCH_ABSENT == "1" or db_path() == ""
  setup_highlights()
  vim.o.showtabline = 2
  vim.o.laststatus = 3
  vim.o.ruler = false
  vim.o.showmode = false
  vim.o.cmdheight = 0
  vim.o.mouse = "a"
  vim.g.CockpitBenchTabline = function()
    return M.tabline()
  end
  vim.g.CockpitBenchStatusline = function()
    return M.statusline()
  end
  vim.opt.tabline = "%!v:lua.vim.g.CockpitBenchTabline()"
  vim.opt.statusline = "%!v:lua.vim.g.CockpitBenchStatusline()"
  setup_keymaps()
  if state.absent then
    M.render_absent()
    return
  end
  create_layout()
  setup_mouse()
  M.render_all()
  local group = vim.api.nvim_create_augroup("CodexCockpitBenchLayout", { clear = true })
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      resize_columns()
      M.render_all()
    end,
  })
end

return M
