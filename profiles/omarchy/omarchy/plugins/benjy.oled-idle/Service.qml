import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// OLED care: Omarchy's idle service never blanks the screen, so the lock
// screen stays lit. Mouse or keyboard input wakes it (misc:*_enables_dpms).
Item {
  id: root
  property var shell: null
  Component.onCompleted: console.info("benjy.oled-idle: loaded")

  // `hyprctl dispatch` silently ignores dpms on 0.56 Lua; eval works.
  readonly property string screenOff: "hyprctl eval \"hl.dispatch(hl.dsp.dpms({ action = 'disable' }))\""
  readonly property int lockSeconds: shell && shell.idleConfig && shell.idleConfig.lock > 0 ? shell.idleConfig.lock : 300

  // 3 min idle. Respects inhibitors (fullscreen video/games) and Omarchy's stay-awake toggle.
  IdleMonitor {
    timeout: 180
    respectInhibitors: true
    onIsIdleChanged: if (isIdle) idleOff.running = true
  }

  // 15 s after the last input while locked, including a manual lock.
  IdleMonitor {
    timeout: 15
    respectInhibitors: false
    onIsIdleChanged: if (isIdle) lockedOff.running = true
  }

  // Again 15 s after Omarchy's auto-lock, in case the lock screen woke the display.
  IdleMonitor {
    timeout: root.lockSeconds + 15
    respectInhibitors: false
    onIsIdleChanged: if (isIdle) lockedOff.running = true
  }

  Process {
    id: idleOff
    command: ["bash", "-c", "[[ -e $HOME/.local/state/omarchy/indicators/stay-awake ]] || " + root.screenOff]
  }
  Process {
    id: lockedOff
    command: ["bash", "-c", "[[ $(omarchy-shell lock isLocked 2>/dev/null) == true ]] && " + root.screenOff]
  }
}
