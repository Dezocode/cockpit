-- Options are automatically loaded before lazy.nvim startup.
require("config.remote_clipboard").setup()
require("config.cockpit-diff").setup()

vim.opt.relativenumber = false
vim.g.autoformat = false
vim.opt.errorbells = false
vim.opt.visualbell = false
vim.opt.belloff = "all"

-- Codex edits files outside the current Neovim buffer. Keep loaded buffers
-- synchronized with those writes while preserving Neovim's conflict prompts
-- if this buffer also has unsaved changes.
vim.opt.autoread = true

vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  callback = function()
    pcall(vim.cmd.checktime)
  end,
})

--- Open a file written by Codex when the current buffer is safe to leave.
function _G.CodexCockpitOpen(path)
  if type(path) ~= "string" or path == "" then
    return ""
  end
  pcall(vim.cmd.checktime)
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].modified or vim.bo[buf].buftype ~= "" then
    return ""
  end
  local current = vim.api.nvim_buf_get_name(buf)
  if current == path then
    return ""
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
  return ""
end
