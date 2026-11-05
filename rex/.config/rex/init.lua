-- Rex configuration: https://www.superlogical.com/rex/docs/customize/config
-- Reload with `rex config reload`.

local FLOATING_TERMINAL_LABEL = "floating"
local FLOATING_TERMINAL_BOUNDS = { 0.05, 0.05, 0.9, 0.9 }

local function find_floating_terminal()
  local view, err = rex.session.view{}
  if view == nil then error(err, 0) end
  for _, window in ipairs(view.windows or {}) do
    if window.window_id == view.active_window_id then
      for _, layer in ipairs(window.layers or {}) do
        if layer.kind == "floating" then
          for _, block in ipairs(layer.blocks or {}) do
            if block.label == FLOATING_TERMINAL_LABEL then
              return block.block_id
            end
          end
        end
      end
    end
  end
end

rex.action{
  name  = "toggle_floating_terminal",
  title = "Toggle Floating Terminal",
  run   = function(ctx, args)
    if find_floating_terminal() == nil then
      local _, err = rex.session.new_layer{
        bounds = FLOATING_TERMINAL_BOUNDS,
        layout = {
          block = {
            flavor = "com.superlogical.terminal.shell",
            label  = FLOATING_TERMINAL_LABEL,
          },
        },
        focus = true,
      }
      if err ~= nil then error(err, 0) end
      return
    end
    rex.client.queue("pane.minimize_floating")
  end,
}

rex.bind("cmd+o", "toggle_floating_terminal")
