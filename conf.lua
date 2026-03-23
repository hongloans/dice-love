-- Love2D configuration (https://love2d.org/wiki/Config_Files)
function love.conf(t)
  t.identity = "dice-love"
  t.appendidentity = true
  t.version = "11.4"
  t.console = false

  t.window.title = "Dice Love — Dice War (Lua port)"
  t.window.width = 1280
  t.window.height = 800
  t.window.minwidth = 960
  t.window.minheight = 600
  t.window.resizable = true
  t.window.vsync = 1
end
