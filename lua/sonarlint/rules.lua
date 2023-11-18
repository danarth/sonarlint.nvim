local M = {}

function M.show_rule_handler(err, result, context)
   local buf = vim.api.nvim_create_buf(false, true)
   vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
   vim.api.nvim_buf_set_option(buf, "readonly", true)

   local htmlDescription = result.htmlDescription

   if htmlDescription == nil or htmlDescription == "" then
      local htmlDescriptionTab = result.htmlDescriptionTabs[1]
      local ruleDescriptionTabHtmlContent = htmlDescriptionTab.ruleDescriptionTabContextual.htmlContent
         or htmlDescriptionTab.ruleDescriptionTabNonContextual.htmlContent
      htmlDescription = ruleDescriptionTabHtmlContent
   end

   local markdown_lines = vim.lsp.util.convert_input_to_markdown_lines(htmlDescription)
   vim.api.nvim_buf_set_lines(buf, -1, -1, false, markdown_lines)

   vim.cmd("vsplit")
   local win = vim.api.nvim_get_current_win()
   vim.api.nvim_win_set_buf(win, buf)
end

return M
