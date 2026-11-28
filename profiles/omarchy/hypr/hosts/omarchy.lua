-- Monitors and HDR for the host "omarchy" (/etc/hostname): ASUS OLED in the
-- middle, the AOC and the TV to its left. Loaded at the end of custom.lua.
-- A new machine gets hosts/<its hostname>.lua; without one, Omarchy's
-- monitors.lua defaults apply.

hl.monitor({
  output = "desc:AOC 2590G4 0x000210C1",
  mode = "1920x1080@144.00",
  position = "-1920x0",
  scale = 1,
  vrr = 0,
  bitdepth = 10,
  sdr_min_luminance = 0.2,
  sdr_max_luminance = 80,
})

hl.monitor({
  output = "desc:AOC C27G4ZXU 1O0Q7JA008205",
  mode = "1920x1080@240.00",
  position = "-1920x0",
  scale = 1,
  vrr = 0,
  bitdepth = 10,
  sdr_min_luminance = 0.2,
  sdr_max_luminance = 80,
})

hl.monitor({
  output = "desc:Vestel Elektronik Sanayi ve Ticaret A. S. 22W_LCD_TV",
  mode = "1920x1080@60.00",
  position = "-1920x0",
  scale = 1,
  vrr = 0,
  bitdepth = 10,
  sdr_min_luminance = 0.2,
  sdr_max_luminance = 80,
})

hl.monitor({
  output = "desc:ASUSTek COMPUTER INC XG27AQDMES W7LMTF246276",
  mode = "2560x1440@239.97",
  position = "0x0",
  scale = 1,
  vrr = 2,
  bitdepth = 10,
  min_luminance = 0,
  max_luminance = 400,
  max_avg_luminance = 250,
  sdr_min_luminance = 0.005,
  sdr_max_luminance = 200,
  sdrbrightness = 1.0,
  sdrsaturation = 1.0,
})

-- HDR only when a fullscreen game requests it; desktop stays SDR (OLED burn-in).
-- Overrides Omarchy's default of 0.
hl.config({ render = { cm_auto_hdr = 1 } })
