// Verification for fix 001: does the screen-cast pipeline deliver frames
// continuously, or does the portal die and freeze like before?
//
// Runs the same stack Vesktop uses: Electron desktopCapturer -> xdg-desktop-portal
// -> PipeWire. A visible animated window forces continuous screen damage, so a
// stalled count means real breakage rather than a static desktop.
const { app, BrowserWindow, desktopCapturer } = require("electron");
const path = require("path");

const DURATION_MS = Number(process.env.CAPTURE_TEST_SECONDS || 15) * 1000;

app.whenReady().then(async () => {
  try {
    const sources = await desktopCapturer.getSources({
      types: ["screen"],
      thumbnailSize: { width: 160, height: 90 },
    });
    console.log("sources: " + sources.map((s) => `${s.id} "${s.name}"`).join(", "));
    if (!sources.length) {
      console.log("VERDICT: NO_SOURCES (portal not serving screens)");
      app.quit();
      return;
    }

    const win = new BrowserWindow({
      show: true,
      width: 480,
      height: 320,
      title: "fix-001 capture test",
      webPreferences: { backgroundThrottling: false },
    });
    win.setAlwaysOnTop(true);
    win.webContents.setBackgroundThrottling(false);
    win.webContents.session.setPermissionRequestHandler((wc, p, cb) => cb(true));
    await win.loadFile(path.join(__dirname, "blank.html"));

    // Continuous animation => continuous damage on the captured output.
    await win.webContents.executeJavaScript(`
      document.body.innerHTML = '<div id="anim" style="position:fixed;inset:0"></div>';
      const el = document.getElementById('anim');
      let h = 0;
      (function loop(){ h = (h + 3) % 360; el.style.background = 'hsl(' + h + ',90%,50%)'; requestAnimationFrame(loop); })();
      true;
    `);

    const srcId = sources[0].id;
    const result = await win.webContents.executeJavaScript(`(async () => {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: { mandatory: { chromeMediaSource: 'desktop', chromeMediaSourceId: ${JSON.stringify(srcId)} } }
      });
      const track = stream.getVideoTracks()[0];
      const settings = track.getSettings ? track.getSettings() : {};

      const stamps = [];
      const t0 = performance.now();
      const processor = new MediaStreamTrackProcessor({ track });
      const reader = processor.readable.getReader();
      let done = false;
      (async () => {
        while (!done) {
          const r = await reader.read();
          if (r.done) break;
          stamps.push(Math.round(performance.now() - t0));
          r.value.close();
        }
      })();

      await new Promise((res) => setTimeout(res, ${DURATION_MS}));
      done = true;
      try { await reader.cancel(); } catch (e) {}
      stream.getTracks().forEach((t) => t.stop());

      const gaps = stamps.slice(1).map((t, i) => t - stamps[i]);
      const tailStart = ${DURATION_MS} - 5000;
      return {
        frames: stamps.length,
        lastFrameAt: stamps.length ? stamps[stamps.length - 1] : null,
        maxGapMs: gaps.length ? Math.max(...gaps) : null,
        framesInLast5s: stamps.filter((t) => t > tailStart).length,
        avgFps: stamps.length && stamps[stamps.length-1] ? Math.round(stamps.length / (stamps[stamps.length-1] / 1000)) : 0,
        width: settings.width, height: settings.height,
      };
    })()`);

    console.log("result: " + JSON.stringify(result));
    const ok =
      result.frames > 50 &&
      result.lastFrameAt > DURATION_MS - 2000 &&
      result.framesInLast5s > 30;
    console.log("VERDICT: " + (ok ? "PASS - frames flowing continuously" : "FAIL - stream stalled"));
  } catch (e) {
    console.log("VERDICT: FAIL - " + e.message);
  }
  app.quit();
});
