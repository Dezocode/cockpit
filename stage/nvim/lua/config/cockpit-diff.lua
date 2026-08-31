-- Theme-aware diff surfaces for the Cockpit FILES tab.
-- Omarchy writes the active palette to colors.toml; reading that file keeps
-- this overlay in sync when the user changes themes without hardcoding a
-- second palette in the Neovim config.

local M = {}

local fallback = {
  background = "#101315",
  foreground = "#cacccc",
  bright_foreground = "#a5aeb4",
  muted = "#4b4e55",
  accent = "#798186",
  red = "#565d60",
  green = "#9fa5a9",
  yellow = "#d9dbdc",
  blue = "#798186",
  bright_red = "#de6145",
  bright_green = "#343d41",
}

local function read_colors()
  local colors = vim.deepcopy(fallback)
  local path = vim.env.COCKPIT_THEME_COLORS_FILE
    or vim.fn.expand("~/.local/state/omarchy/current/theme/colors.toml")

  if vim.fn.filereadable(path) == 1 then
    for _, line in ipairs(vim.fn.readfile(path)) do
      local key, value = line:match("^%s*([%w_]+)%s*=%s*[\"']?(#[%x]+)")
      if key and value:match("^#%x%x%x%x%x%x$") then
        colors[key] = value
      end
    end
  end

  return colors
end

local function luminance(hex)
  local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
  if not r then
    return 0
  end
  return (tonumber(r, 16) * 0.299 + tonumber(g, 16) * 0.587 + tonumber(b, 16) * 0.114) / 255
end

local function contrast(hex, colors)
  if luminance(hex) > 0.58 then
    return colors.background
  end
  return colors.foreground
end

local function saturated(hex)
  local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
  if not r then
    return false
  end
  r, g, b = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)
  local max, min = math.max(r, g, b), math.min(r, g, b)
  return max - min >= 28
end

local function diff_colors(colors)
  local add = vim.env.COCKPIT_DIFF_ADD_BG
  local delete = vim.env.COCKPIT_DIFF_DELETE_BG

  if not add or not add:match("^#%x%x%x%x%x%x$") then
    if saturated(colors.green) then
      add = colors.green
    elseif saturated(colors.bright_green) then
      add = colors.bright_green
    else
      add = "#2b6e4f"
    end
  end

  if not delete or not delete:match("^#%x%x%x%x%x%x$") then
    if saturated(colors.red) then
      delete = colors.red
    elseif saturated(colors.bright_red) then
      delete = colors.bright_red
    else
      delete = "#8f3f35"
    end
  end

  return add, delete
end

local function apply()
  local colors = read_colors()
  local diff_add, diff_delete = diff_colors(colors)
  local specs = {
    -- Solid themed bands make additions and removals visible in a transparent
    -- Omarchy Neovim. Neutral semantic colors get a dark, high-contrast hue.
    DiffAdd = { bg = diff_add, fg = contrast(diff_add, colors) },
    DiffDelete = { bg = diff_delete, fg = contrast(diff_delete, colors) },
    DiffChange = { bg = colors.accent, fg = contrast(colors.accent, colors) },
    DiffText = { bg = colors.yellow, fg = contrast(colors.yellow, colors), bold = true },

    Added = { fg = diff_add },
    Removed = { fg = diff_delete },
    Changed = { fg = colors.accent },
    GitSignsAdd = { fg = diff_add },
    GitSignsChange = { fg = colors.accent },
    GitSignsDelete = { fg = diff_delete },
    MiniDiffSignAdd = { fg = diff_add },
    MiniDiffSignChange = { fg = colors.accent },
    MiniDiffSignDelete = { fg = diff_delete },
  }

  for name, spec in pairs(specs) do
    vim.api.nvim_set_hl(0, name, spec)
  end
end

function M.setup()
  vim.opt.termguicolors = true

  local group = vim.api.nvim_create_augroup("CodexCockpitDiffTheme", { clear = true })
  vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
    group = group,
    callback = apply,
  })
  apply()
end

return M
