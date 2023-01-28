local M = {}

M.client_id = nil

local function start_sonarlint_lsp(user_config, analyzer_paths)
   local config = {}
   config.name = 'sonarlint.nvim'
   config.root_dir = user_config.root_dir or vim.fs.dirname(vim.fs.find({'.git'}, { upward = true })[1])

   config.cmd = user_config.cmd
   table.insert(config.cmd, "-stdio")
   table.insert(config.cmd, "-analyzers")
   for _, analyzer_path in ipairs(analyzer_paths) do
      table.insert(config.cmd, analyzer_path)
   end
   
   config.init_options = {
      productKey = 'sonarlint.nvim',
      productName = 'SonarLint.nvim',
      productVersion = '0.1.0',
      -- TODO: get workspace name
      workspaceName = 'some-workspace-name',
      firstSecretDetected = false,
      showVerboseLogs = true,
      platform = vim.loop.os_uname().sysname,
      architecture = vim.loop.os_uname().machine
   }

   config.handlers = {}
   config.handlers['sonarlint/isOpenInEditor'] = function(...)
      -- TODO chech if file URI maps to any buffer
      vim.pretty_print(...)
      return true
   end
   config.handlers['sonarlint/isIgnoredByScm'] = function(...)
      -- TODO check if the file is ignored by the SCM
      vim.pretty_print(...)
      return false
   end

   -- https://github.com/SonarSource/sonarlint-language-server/pull/187#issuecomment-1399925116
   config.handlers['workspace/configuration'] = function()
      return {
         settings = {}
      }
   end

   local client_id = vim.lsp.start_client(config)

   -- https://github.com/SonarSource/sonarlint-language-server/pull/187#issuecomment-1399925116
   local client = vim.lsp.get_client_by_id(client_id)
   client.notify('workspace/didChangeConfiguration', {
      settings = {},
   })

   return client_id
end

function M.setup(config)
   if not config.analyzers then
      vim.notify("Please, provide analyzers as a map of filetype and path to the analyzer.", vim.log.levels.WARN)
      return
   end

   local pattern = {}
   local analyzers = {}
   for filetype, analyzer_path in pairs(config.analyzers) do
      table.insert(pattern, filetype)
      table.insert(analyzers, analyzer_path)
   end

   vim.api.nvim_create_autocmd(
      "FileType",
      {
         pattern = table.concat(pattern, ","),
         callback = function(buf)
            bufnr = buf.buf

            if not M.client_id then
               M.client_id = start_sonarlint_lsp(config.server, analyzers)
            end

            vim.lsp.buf_attach_client(bufnr, M.client_id)
         end
      }
   )
end

return M
