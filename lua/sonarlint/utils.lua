local M = {}

function M.is_open_in_editor(uri)
   for i, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if uri == vim.uri_from_bufnr(bufnr) then
         return true
      end
   end
   return false
end

return M
