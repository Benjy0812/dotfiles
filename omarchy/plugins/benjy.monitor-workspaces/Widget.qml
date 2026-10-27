import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// Workspaces for the monitor this bar sits on, numbered 1..N per monitor.
// The workspace ids each monitor owns come straight from Hyprland's workspace
// rules (set by monitor-workspaces.lua), so the monitor order lives in one
// place and this widget never needs to know it.
BarWidget {
  id: root
  moduleName: "benjy.monitor-workspaces"

  // Slots always shown even when empty, like omarchy.workspaces shows 1-5.
  readonly property int minimumSlots: root.setting("minimumSlots", 5)

  readonly property string monitorName: QsWindow.window && QsWindow.window.screen ? QsWindow.window.screen.name : ""

  // { "<monitor>": [ids...] } in slot order, read from `hyprctl workspacerules`.
  property var pinnedIds: ({})
  readonly property var ownIds: root.pinnedIds[root.monitorName] || []

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  // Slot numbers to draw: the first minimumSlots, plus any later one in use.
  function visibleSlots() {
    var slots = []
    for (var slot = 1; slot <= root.ownIds.length; slot++) {
      if (slot <= root.minimumSlots || root.workspaceById(root.ownIds[slot - 1]) !== null) slots.push(slot)
    }

    return slots
  }

  // Focusing by id is enough: the workspace rule creates it on this monitor.
  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  function readRules(text) {
    var rules
    try {
      rules = JSON.parse(text || "[]")
    } catch (e) {
      return
    }

    var byMonitor = {}
    for (var i = 0; i < rules.length; i++) {
      var id = Number(rules[i].workspaceString)
      var monitor = rules[i].monitor
      if (!monitor || !Number.isInteger(id) || id <= 0) continue
      if (!byMonitor[monitor]) byMonitor[monitor] = []
      if (byMonitor[monitor].indexOf(id) === -1) byMonitor[monitor].push(id)
    }

    for (var name in byMonitor) byMonitor[name].sort(function(left, right) { return left - right })
    root.pinnedIds = byMonitor
  }

  function refreshRules() {
    if (!rulesProc.running) rulesProc.running = true
  }

  Component.onCompleted: root.refreshRules()

  Connections {
    target: Hyprland

    // Rules change when the config reloads or a monitor is plugged in.
    function onRawEvent(event) {
      var name = event && event.name ? String(event.name) : ""
      if (name === "configreloaded" || name.indexOf("monitoradded") === 0) root.refreshRules()
    }
  }

  Process {
    id: rulesProc
    command: ["hyprctl", "-j", "workspacerules"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.readRules(text)
    }
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.visibleSlots().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.visibleSlots()

      WidgetButton {
        required property int modelData

        readonly property int workspaceId: root.ownIds[modelData - 1]
        readonly property var workspace: root.workspaceById(workspaceId)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        // Shown on this monitor; `focused` additionally means it has keyboard focus.
        readonly property bool shown: workspace !== null && workspace.active
        readonly property bool focused: shown && Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === workspaceId

        bar: root.bar
        text: shown ? "󱓻" : (modelData === 10 ? "0" : String(modelData))
        opacity: focused || occupied ? 1 : (shown ? 0.75 : 0.5)
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(workspaceId) }
      }
    }
  }
}
