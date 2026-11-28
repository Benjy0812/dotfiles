-- Hyprland half of the benjy.bar auto-hide (AutoHide.qml): peek the bar while
-- either Super key is held. The press is a bind; the release comes from the raw
-- key event, which fires before binds, so other Super binds (workspace switches)
-- can't swallow it. letGo() ignores a release with no peek.
-- Loaded from hypr/custom.lua.
for _, key in ipairs({ "Super_L", "Super_R" }) do
  o.bind("SUPER + " .. key, "Show bar while held", hl.dsp.global("benjy:bar-peek"),
    { ignore_mods = true, non_consuming = true })
end

-- xkb keycodes 133/134 are Super_L/Super_R; state 0 is released.
hl.on("input.keyboard.key", function(keycode, _, state)
  if state == 0 and (keycode == 133 or keycode == 134) then
    hl.dispatch(hl.dsp.global("benjy:bar-unpeek"))
  end
end)
