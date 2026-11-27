// Pure show/hide decision for benjy.bar AutoHide.qml; tested by test_autohide.js.
// s: { shown, edgeSince, hideAt, screen }
// i: { now, y (local to the cursor's monitor), mon (cursor's monitor), focused,
//      all (bar shows on every monitor), held, fullscreen (block hover), barSize, panelOpen }
var DWELL_MS = 250   // cursor must rest on the top edge this long to reveal
var HIDE_MS = 1500   // hide this long after the cursor leaves the bar
var FLASH_MS = 1500  // reveal on workspace switch
var MARGIN = 4

function step(s, i) {
  var n = { shown: s.shown, edgeSince: s.edgeSince, hideAt: s.hideAt, screen: s.screen }
  if (i.held) {
    n.shown = true
    n.edgeSince = 0
    n.screen = i.focused
    return n
  }
  if (!n.shown) {
    if (i.y <= 0 && !i.fullscreen) {
      if (!n.edgeSince) n.edgeSince = i.now
      if (i.now - n.edgeSince >= DWELL_MS) {
        n.shown = true
        n.edgeSince = 0
        n.hideAt = i.now + HIDE_MS
        n.screen = i.mon
      }
    } else {
      n.edgeSince = 0
    }
    return n
  }
  var onBar = ((i.all || i.mon === n.screen) && i.y <= i.barSize + MARGIN) || i.panelOpen
  if (onBar) n.hideAt = Math.max(n.hideAt, i.now + HIDE_MS)
  if (i.now >= n.hideAt) n.shown = false
  return n
}

function flash(s, now, focused) {
  return { shown: true, edgeSince: 0, hideAt: Math.max(s.shown ? s.hideAt : 0, now + FLASH_MS), screen: focused }
}

// Super released: hide at the next step unless the cursor is on the bar.
function release(s, now) {
  return { shown: s.shown, edgeSince: 0, hideAt: now, screen: s.screen }
}

if (typeof module !== "undefined") module.exports = { step: step, flash: flash, release: release, DWELL_MS: DWELL_MS, HIDE_MS: HIDE_MS }
