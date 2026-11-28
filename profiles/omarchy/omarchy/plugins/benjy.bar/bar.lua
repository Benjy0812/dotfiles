-- Hyprland half of the benjy.bar auto-hide (AutoHide.qml): peek the bar while
-- either Super key is held. A Lua bind never sends a global shortcut's release,
-- so the key-up dispatches a second shortcut, bar-unpeek.
-- Loaded from hypr/custom.lua.
for _, key in ipairs({ "Super_L", "Super_R" }) do
  o.bind_hold("SUPER + " .. key,
    "Show bar while held", function() hl.dispatch(hl.dsp.global("benjy:bar-peek")) end,
    "Hide bar on release", function() hl.dispatch(hl.dsp.global("benjy:bar-unpeek")) end,
    { ignore_mods = true, non_consuming = true })
end
