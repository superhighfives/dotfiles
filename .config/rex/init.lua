-- Migrated terminal setup for Rex

-- tmux prefix is ctrl+a; let programs that use the prefix themselves still receive it
rex.bind("ctrl+a>ctrl+a", "pane.send_key", { key = "ctrl+a" })

-- Repeat mode: emulates tmux `bind -r` (ctrl+a then ctrl+r enters; enter/escape leaves)
rex.mode("repeat", { exclusive = true })
rex.bind("ctrl+a>ctrl+r", "client.mode.enter", { name = "repeat" })
rex.bind("repeat/enter", "client.mode.exit")
rex.bind("repeat/escape", "client.mode.exit")

-- tmux bindings
rex.bind("ctrl+a>a", "pane.send_key", { key = "ctrl+a" })
rex.bind("ctrl+a>shift+'", "pane.split", { direction = "down" })
rex.bind("ctrl+a>shift+5", "pane.split", { direction = "right" })
rex.bind("ctrl+a>c", "client.tab.new")
rex.bind("ctrl+a>shift+h", "pane.resize", { amount = 5, direction = "left" })
rex.bind("repeat/shift+h", "pane.resize", { amount = 5, direction = "left" })
rex.bind("ctrl+a>shift+j", "pane.resize", { amount = 5, direction = "down" })
rex.bind("repeat/shift+j", "pane.resize", { amount = 5, direction = "down" })
rex.bind("ctrl+a>shift+l", "pane.resize", { amount = 5, direction = "right" })
rex.bind("repeat/shift+l", "pane.resize", { amount = 5, direction = "right" })
rex.bind("ctrl+a>r", "client.config.reload")
rex.bind("ctrl+a>h", "pane.focus", { direction = "left" })
rex.bind("ctrl+a>j", "pane.focus", { direction = "down" })
rex.bind("ctrl+a>k", "pane.focus", { direction = "up" })
rex.bind("ctrl+a>l", "pane.focus", { direction = "right" })
