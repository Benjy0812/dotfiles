-- Hyprland half of the benjy.bar auto-hide (AutoHide.qml): peek the bar while
-- either Super key is held. The shell gets the key-up as the shortcut's release.
-- Loaded from hypr/custom.lua.
for _, key in ipairs({ "Super_L", "Super_R" }) do
  o.bind("SUPER + " .. key, "Show bar while held", function() hl.dispatch(hl.dsp.global("benjy:bar-peek")) end,
    { ignore_mods = true, non_consuming = true })
end
