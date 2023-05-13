local M = {}

M.client_id = nil
M.classpaths_result = nil

local function init_with_config_notify(original_init)
   return function(...)
      local client = select(1, ...)

      -- https://github.com/SonarSource/sonarlint-language-server/pull/187#issuecomment-1399925116
      client.notify("workspace/didChangeConfiguration", {
         settings = {},
      })

      if original_init then
         original_init(...)
      end
   end
end

local function start_sonarlint_lsp(user_config)
   local config = {}
   config.name = "sonarlint.nvim"
   config.root_dir = user_config.root_dir or vim.fs.dirname(vim.fs.find({ ".git" }, { upward = true })[1])

   config.cmd = user_config.cmd

   config.init_options = {
      productKey = "sonarlint.nvim",
      productName = "SonarLint.nvim",
      productVersion = "0.1.0",
      -- TODO: get workspace name
      workspaceName = "some-workspace-name",
      firstSecretDetected = false,
      showVerboseLogs = true,
      platform = vim.loop.os_uname().sysname,
      architecture = vim.loop.os_uname().machine,
   }

   config.capabilities =
      vim.tbl_deep_extend("keep", user_config.capabilities or {}, vim.lsp.protocol.make_client_capabilities())

   config.handlers = {}
   config.handlers["sonarlint/isOpenInEditor"] = function(err, uri)
      for i, bufnr in ipairs(vim.api.nvim_list_bufs()) do
         if uri == vim.uri_from_bufnr(bufnr) then
            return true
         end
      end
      return false
   end
   config.handlers["sonarlint/isIgnoredByScm"] = function(...)
      -- TODO check if the file is ignored by the SCM
      return false
   end

   config.handlers["sonarlint/getJavaConfig"] = function(err, uri)
      local is_test_file = false
      if M.classpaths_result then
         local err, is_test_file_result = require("jdtls.util").execute_command({
            command = "java.project.isTestFile",
            arguments = { uri },
         })
         is_test_file = is_test_file_result
      end

      local classpaths_result = M.classpaths_result or {}

      return {
         projectRoot = classpaths_result.projectRoot
            or "file:" .. vim.lsp.get_client_by_id(M.client_id).config.root_dir,
         -- TODO: how to get source level from jdtls?
         sourceLevel = "11",
         classpath = classpaths_result.classpaths or {},
         isTest = is_test_file,
         -- TODO vmLocation
      }
   end

   config.handlers["sonarlint/needCompilationDatabase"] = function(err, uri)
      local locations = vim.fs.find("compile_commands.json", {
         upward = true,
         path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)),
      })
      if #locations > 0 then
         local client = vim.lsp.get_client_by_id(M.client_id)
         client.config.settings = vim.tbl_deep_extend("force", client.config.settings, {
            sonarlint = {
               pathToCompileCommands = locations[1],
            },
         })
         client.notify("workspace/didChangeConfiguration", {
            settings = {},
         })
      end
   end

   config.handlers["sonarlint/showRuleDescription"] = function(err, result, context)
      local markdown_lines = vim.lsp.util.convert_input_to_markdown_lines(result.htmlDescription)
      vim.lsp.util.open_floating_preview(markdown_lines, "markdown", {})
   end

   -- TODO: persist settings
   config.settings = {
      sonarlint = {},
   }
   config.commands = {
      ["SonarLint.DeactivateRule"] = function(action)
         local rule = action.arguments[1]
         if rule ~= nil then
            local client = vim.lsp.get_client_by_id(M.client_id)
            client.config.settings = vim.tbl_deep_extend("force", client.config.settings, {
               sonarlint = {
                  rules = {
                     [rule] = {
                        level = "off",
                     },
                  },
               },
            })
            client.notify("workspace/didChangeConfiguration", {
               settings = {},
            })
         end
      end,
      ["SonarLint.ShowAllLocations"] = function(result, ...)
         local list = {}
         for i, arg in ipairs(result.arguments) do
            local bufnr = vim.uri_to_bufnr(arg.fileUri)

            for j, flow in ipairs(arg.flows) do
               for k, location in ipairs(flow.locations) do
                  local text_range = location.textRange

                  table.insert(list, {
                     bufnr = bufnr,
                     lnum = text_range.startLine,
                     col = text_range.startLineOffset,
                     end_lnum = text_range.endLine,
                     end_col = text_range.endLineOffset,
                     text = arg.message,
                  })
               end
            end
         end

         vim.fn.setqflist(list, "r")
         vim.cmd("copen")
      end,
   }

   config.on_init = init_with_config_notify(config.on_init)

   return vim.lsp.start_client(config)
end

function M._handle_progress(err, msg, info)
   local client = vim.lsp.get_client_by_id(info.client_id)

   if client.name ~= "jdtls" then
      return
   end
   if msg.value.kind ~= "end" then
      return
   end

   -- TODO: checking the message text seems a little bit brittle. Is there a better way to
   -- determine if jdtls has classpath information ready
   if msg.value.message ~= "Synchronizing projects" then
      return
   end

   require("jdtls.util").with_classpaths(function(result)
      M.classpaths_result = result

      local sonarlint = vim.lsp.get_client_by_id(M.client_id)
      sonarlint.notify("sonarlint/didClasspathUpdate", {
         projectUri = result.projectRoot,
      })
   end)
end

function M.setup(config)
   if not config.filetypes then
      vim.notify("Please, provide filetypes as a list of filetype.", vim.log.levels.WARN)
      return
   end

   local pattern = {}
   local java = false
   for i, filetype in ipairs(config.filetypes) do
      if filetype == "java" then
         java = true
      end
      table.insert(pattern, filetype)
   end

   vim.api.nvim_create_autocmd("FileType", {
      pattern = table.concat(pattern, ","),
      callback = function(buf)
         bufnr = buf.buf

         if not M.client_id then
            M.client_id = start_sonarlint_lsp(config.server)
         end

         vim.lsp.buf_attach_client(bufnr, M.client_id)
      end,
   })

   if java then
      local ok, jdtls_util = pcall(require, "jdtls.util")
      if not ok then
         vim.notify(
            "nvim-jdtls isn't available and is required for analyzing Java files. Make sure to install it",
            vim.log.levels.ERROR
         )
         return
      end

      if vim.lsp.handlers["$/progress"] then
         local old_handler = vim.lsp.handlers["$/progress"]
         vim.lsp.handlers["$/progress"] = function(...)
            old_handler(...)
            M._handle_progress(...)
         end
      else
         vim.lsp.handlers["$/progress"] = M._handle_progress
      end
   end
end

return M
