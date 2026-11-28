import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "AutoHideModel.js" as Model

// OLED auto-hide, active while the `bar-off` flag is on (`omarchy toggle bar`).
// Peeks set bar.barPeek in-process; the bar overlays windows meanwhile, so
// nothing reflows. Reveal: hold Super (binds in bar.lua next to this file),
// rest the cursor on the top edge, or switch workspace.
// shell.json `bar.autoHideMonitors`: "focused" (default) peeks only the focused
// monitor (or the one under the cursor for hover); "all" peeks every monitor.
// No peeks over fullscreen windows: the bar stays under them.
Item {
  id: root
  required property var bar

  readonly property bool active: bar.barOff
  property var st: ({ shown: false, edgeSince: 0, hideAt: 0, screen: "" })
  readonly property bool all: bar.barConfig && bar.barConfig.autoHideMonitors === "all"
  property bool held: false
  property real sentAt: 0   // when the cursor request was written

  onActiveChanged: { held = false; apply({ shown: false, edgeSince: 0, hideAt: 0, screen: "" }) }

  function apply(next) {
    st = next
    bar.peekScreen = all ? "" : (next.screen || "")
    bar.barPeek = active && next.shown
  }

  function focusedName() {
    var m = Hyprland.focusedMonitor
    return m ? m.name : ""
  }

  function fullscreen(m) {
    m = m || Hyprland.focusedMonitor
    return !!(m && m.activeWorkspace && m.activeWorkspace.hasFullscreen)
  }

  function monitorAt(x, y) {
    var list = Hyprland.monitors.values
    for (var i = 0; i < list.length; i++) {
      var m = list[i], k = m.scale || 1
      if (x >= m.x && x < m.x + m.width / k && y >= m.y && y < m.y + m.height / k) return m
    }
    return Hyprland.focusedMonitor
  }

  function panelOpen() {
    var layout = bar.barConfig && bar.barConfig.layout
    if (!layout || !bar.shell) return false
    for (var sec in layout) {
      var list = layout[sec] || []
      for (var k = 0; k < list.length; k++)
        if (list[k] && list[k].id && bar.shell.isPluginOpen(list[k].id)) return true
    }
    return false
  }

  function onCursor(x, y) {
    if (!active) return
    var m = monitorAt(x, y)
    var name = m ? m.name : ""
    apply(Model.step(st, {
      now: Date.now(), y: y - (m ? m.y : 0), mon: name, focused: focusedName(), all: all, held: held,
      // Super peeks the focused monitor, hover the one under the cursor.
      fullscreen: held ? fullscreen() : fullscreen(m), barSize: bar.barSizeFor(name) || 26, panelOpen: panelOpen()
    }))
  }

  function poll() {
    // Watchdog: a request with no reply would stop every hide; reconnect.
    if (cursorSock.connected && Date.now() - sentAt > 500) cursorSock.connected = false
    cursorSock.connected = true
  }

  // Super press and key-up arrive as two shortcuts (bar-peek, bar-unpeek): the
  // Lua bind in bar.lua never sends bar-peek's own release, so bar.lua sends
  // bar-unpeek from the raw Super key-up.
  GlobalShortcut {
    appid: "benjy"
    name: "bar-peek"
    description: "Show the bar while Super is held"
    onPressed: {
      if (!root.active) return
      root.held = true
      root.apply(Model.step(root.st, { now: Date.now(), y: 9999, held: true, fullscreen: root.fullscreen(), focused: root.focusedName() }))
    }
    onReleased: root.letGo()
  }

  GlobalShortcut {
    appid: "benjy"
    name: "bar-unpeek"
    description: "Hide the bar when Super is released"
    onPressed: root.letGo()
    onReleased: root.letGo()   // in case Hyprland sends the dispatch as a release
  }

  function letGo() {
    if (!held) return
    held = false
    st = Model.release(st, Date.now())
    poll()   // hides now unless the cursor is on the bar
  }

  // OLED safety net: never stay up on a missed Super release. Hides directly,
  // without waiting for a cursor reply.
  Timer {
    interval: 5000
    running: root.held
    onTriggered: { root.held = false; root.apply(Model.hide(root.st)) }
  }

  // Cursor position from Hyprland's request socket (no process per poll).
  Timer {
    interval: 100
    repeat: true
    running: root.active
    onTriggered: root.poll()
  }
  Socket {
    id: cursorSock
    path: Hyprland.requestSocketPath
    onConnectedChanged: if (connected) { root.sentAt = Date.now(); write("j/cursorpos"); flush() }
    parser: SplitParser {
      splitMarker: ""
      onRead: function(data) {
        cursorSock.connected = false   // close before Hyprland does, avoiding a warning per poll
        try { var c = JSON.parse(data); root.onCursor(c.x, c.y) } catch (e) { }
      }
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name !== "workspacev2" || !root.active || root.held || root.fullscreen()) return
      root.apply(Model.flash(root.st, Date.now(), root.focusedName()))
    }
  }
}
