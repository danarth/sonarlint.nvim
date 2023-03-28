<script src="https://liberapay.com/schrieveslaach/widgets/button.js"></script>
<noscript><a href="https://liberapay.com/schrieveslaach/donate"><img alt="Donate using Liberapay" src="https://liberapay.com/assets/widgets/donate.svg"></a></noscript>

# sonarlint.nvim

Extensions for the built-in [Language Server Protocol][1] support in [Neovim][2] (>= 0.8.0) for [sonarlint-language-server][3] (>= 2.16.0.65434).

[1]: https://microsoft.github.io/language-server-protocol/
[2]: https://neovim.io/
[3]: https://github.com/SonarSource/sonarlint-language-server

# Warning :warning:

This repository is work in progress and the API is likely to change.

# Setup

```lua
require('sonarlint').setup({
   server = {
      cmd = { 
         'java', '-jar', 'sonarlint-language-server-VERSION.jar',
         -- Ensure that sonarlint-language-server uses stdio channel
         '-stdio',
         '-analyzers', 'path/to/analyzer1.jar', 'path/to/analyzer2.jar',
      }
   },
   filetypes = {
      -- Tested and working
      'python',
      -- Requires nvim-jdtls, otherwise an error message will be printed
      'java',
   }
})
```

