// Run: node ~/.config/omarchy/plugins/benjy.bar/test_autohide.js
const assert = require("assert");
const M = require("./AutoHideModel.js");
const base = { y: 500, fullscreen: false, barSize: 26, panelOpen: false };
let s = { shown: false, edgeSince: 0, hideAt: 0 };
// Brief touch of the top edge (tab click) does not reveal.
s = M.step(s, { ...base, now: 0, y: 0 });
s = M.step(s, { ...base, now: 200, y: 0 });
assert.equal(s.shown, false);
s = M.step(s, { ...base, now: 400, y: 300 });
assert.equal(s.edgeSince, 0);
// Resting on the edge reveals.
s = M.step(s, { ...base, now: 1000, y: 0 });
s = M.step(s, { ...base, now: 1000 + M.DWELL_MS, y: 0 });
assert.equal(s.shown, true);
// Stays while on the bar or a panel is open.
s = M.step(s, { ...base, now: 9000, y: 10 });
s = M.step(s, { ...base, now: 20000, y: 400, panelOpen: true });
assert.equal(s.shown, true);
// Hides HIDE_MS after leaving.
s = M.step(s, { ...base, now: 20100, y: 400 });
assert.equal(s.shown, true);
s = M.step(s, { ...base, now: 20000 + M.HIDE_MS, y: 400 });
assert.equal(s.shown, false);
// Hover reveals again after a hide.
s = M.step(s, { ...base, now: 30000, y: 0 });
s = M.step(s, { ...base, now: 31000, y: 0 });
assert.equal(s.shown, true);
s = M.step(s, { ...base, now: 31000 + M.HIDE_MS });
assert.equal(s.shown, false);
// Workspace flash shows, then hides when cursor is away.
s = M.flash(s, 40000);
assert.equal(s.shown, true);
s = M.step(s, { ...base, now: 41000 });
assert.equal(s.shown, true);
s = M.step(s, { ...base, now: 42000 });
assert.equal(s.shown, false);
console.log("ok");
// Holding Super does not show the bar over fullscreen...
s = { shown: false, edgeSince: 0, hideAt: 0 };
s = M.step(s, { ...base, now: 50000, held: true, fullscreen: true });
assert.equal(s.shown, false);
// ...but does elsewhere, and keeps it up.
s = M.step(s, { ...base, now: 50000, held: true });
assert.equal(s.shown, true);
s = M.step(s, { ...base, now: 60000, held: true });
assert.equal(s.shown, true);
// Releasing hides at once when the cursor is away...
s = M.step(M.release(s, 60100), { ...base, now: 60100 });
assert.equal(s.shown, false);
// ...but not while the cursor is on the bar.
s = M.step(s, { ...base, now: 70000, held: true });
s = M.step(M.release(s, 70100), { ...base, now: 70100, y: 10 });
assert.equal(s.shown, true);
s = M.step(s, { ...base, now: 70100 + M.HIDE_MS, y: 400 });
assert.equal(s.shown, false);
// Safety net hides at once, keeping the screen.
assert.deepEqual(M.hide({ shown: true, edgeSince: 5, hideAt: 99, screen: "A" }),
  { shown: false, edgeSince: 0, hideAt: 0, screen: "A" });
console.log("ok held");
// Per monitor: Super shows on the focused monitor only.
const pm = { ...base, mon: "A", focused: "A", all: false };
s = { shown: false, edgeSince: 0, hideAt: 0, screen: "" };
s = M.step(s, { ...pm, now: 80000, held: true, focused: "B" });
assert.equal(s.screen, "B");
// Hover reveals on the monitor under the cursor.
s = { shown: false, edgeSince: 0, hideAt: 0, screen: "" };
s = M.step(s, { ...pm, now: 90000, y: 0, mon: "A", focused: "B" });
s = M.step(s, { ...pm, now: 90000 + M.DWELL_MS, y: 0, mon: "A", focused: "B" });
assert.equal(s.shown, true);
assert.equal(s.screen, "A");
// The top of another monitor is not "on the bar".
s = M.step(s, { ...pm, now: 90000 + M.DWELL_MS + M.HIDE_MS, y: 10, mon: "B" });
assert.equal(s.shown, false);
// ...unless the bar shows on every monitor.
s = M.step(M.flash(s, 100000, "A"), { ...pm, now: 100000 });
s = M.step(s, { ...pm, now: 100000 + 5000, y: 10, mon: "B", all: true });
assert.equal(s.shown, true);
// Workspace flash follows the focused monitor.
assert.equal(M.flash(s, 110000, "B").screen, "B");
console.log("ok monitors");
// No hover reveal over fullscreen.
s = { shown: false, edgeSince: 0, hideAt: 0, screen: "" };
s = M.step(s, { ...pm, now: 120000, y: 0, fullscreen: true });
s = M.step(s, { ...pm, now: 121000, y: 0, fullscreen: true });
assert.equal(s.shown, false);
console.log("ok fullscreen");
