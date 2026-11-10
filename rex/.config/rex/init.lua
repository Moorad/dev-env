-- Rex configuration: https://www.superlogical.com/rex/docs/customize/config
-- Reload with `rex config reload`.

local FLOATING_TERMINAL_BOUNDS = { 0.05, 0.05, 0.9, 0.9 }

local TERMINAL = "com.superlogical.terminal"

local function must(result, err)
  if result == nil then error(err, 0) end
  return result
end

local function has_floating_terminal()
  local view = must(rex.session.view{})
  for _, window in ipairs(view.windows or {}) do
    if window.window_id == view.active_window_id then
      for _, layer in ipairs(window.layers or {}) do
        if layer.kind == "floating" then
          return true
        end
      end
    end
  end
  return false
end

local function terminal_directory(block_id)
  if block_id == nil then return nil end
  local result = rex.block.call(TERMINAL, "pwd", { block_id = block_id })
  if result == nil or result.pwd == nil then return nil end
  local path = result.pwd:match("^file://[^/]*(/.*)$")
  if path == nil then return nil end
  return (path:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

rex.action{
  name  = "toggle_floating_terminal",
  title = "Toggle Floating Terminal",
  run   = function(ctx, args)
    if has_floating_terminal() then
      rex.client.queue("pane.minimize_floating")
      return
    end
    must(rex.session.new_layer{
      bounds = FLOATING_TERMINAL_BOUNDS,
      layout = {
        block = {
          flavor  = TERMINAL .. ".shell",
          options = { cwd = terminal_directory(ctx.block_id) },
        },
      },
      focus = true,
    })
  end,
}

rex.bind("cmd+o", "toggle_floating_terminal")

-- Cmd+1..9: go to tab N of the *current* session (Cmd+9 = last tab),
-- instead of the default absolute index across all sessions in the sidebar.
rex.action{
  name  = "session_tab_goto",
  title = "Go to Tab in Current Session",
  args  = { index = "number" },
  run   = function(ctx, args)
    local view, err = rex.session.view{}
    if view == nil then error(err, 0) end
    local windows = view.windows or {}
    local i = args.index
    if i == -1 then i = #windows end
    local w = windows[i]
    if w == nil then return end
    rex.client.queue("session.select", { session_id = ctx.session_id, window_id = w.window_id })
  end,
}

for n = 1, 8 do
  rex.bind("cmd+[Digit" .. n .. "]", "session_tab_goto", { index = n })
end
rex.bind("cmd+[Digit9]", "session_tab_goto", { index = -1 })
