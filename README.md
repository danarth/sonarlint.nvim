# sonarlint.nvim

Extensions for the built-in [Language Server Protocol][1] support in [Neovim][2] (>= 0.8.0) for [sonarlint-language-server][3].

[1]: https://microsoft.github.io/language-server-protocol/
[2]: https://neovim.io/
[3]: https://github.com/SonarSource/sonarlint-language-server

# Setup

```lua
require('sonarlint').setup({
   server = {
      -- Basic command to start sonarlint-language-server. Will be enhanced with additional command line options 
      cmd = { "java", "-jar", "sonarlint-language-server-VERSION.jar" }
   },
   analyzers = {
      -- Tested and working
      python = "/path/to/sonarpython.jar",
      -- Not yet working but will be adressed soon
      java = "/path/to/sonarjava.jar"
   }
})
```

