-- Narrow, dynamic Neo-tree sizing for the Cockpit FILES tab.
-- This only touches the neo-tree buffer and runs on resize events, so it
-- adds no idle polling cost to Neovim.
local M = {}

local function wanted_width()
  return math.max(22, math.min(32, math.floor(vim.o.columns * 0.30)))
end

function M.resize()
  local wanted = wanted_width()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "neo-tree" then
      pcall(function()
        vim.wo[win].winfixwidth = false
        if vim.api.nvim_win_get_width(win) ~= wanted then
          vim.api.nvim_win_set_width(win, wanted)
        end
      end)
    end
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("CodexCockpitFilesLayout", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "neo-tree",
    callback = function()
      vim.schedule(M.resize)
    end,
  })
  vim.api.nvim_create_autocmd({ "VimEnter", "VimResized" }, {
    group = group,
    callback = function()
      vim.schedule(M.resize)
    end,
  })
  vim.schedule(M.resize)
end

return M
