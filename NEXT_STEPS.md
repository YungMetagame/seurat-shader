# What to work on next

## 1. Per-shader parameters (NEXT UP)
Each shader has hardcoded values right now. These should be exposed as real-time sliders in the UI.

**What's needed:**
- Expand `ShaderParams` struct in both `Renderer.swift` and `Shaders.metal` to include per-shader float parameters (warpX, warpY, scanlineHard, maskDark, maskLight, bloomAmount, brightness, etc.)
- Each shader function should read from the params struct instead of hardcoded values
- Add a parameter panel in `ContentView.swift` — shows sliders specific to the selected shader
- Sliders should have the same min/max/default values as the original `#pragma parameter` lines in the slang source

**Reference:** Each `.slang` file in `slang-shaders/crt/shaders/` has `#pragma parameter` lines defining all tunable values.

---

## 2. Multi-pass shader support
Many of the highest-quality shaders (crt-royale, crt-guest-advanced, cathode-retro) require multiple render passes where each pass feeds into the next.

**What's needed:**
- Add a multi-pass render pipeline to `Renderer.swift` using `MTLTexture` ping-pong buffers
- Each pass renders offscreen into a texture, which becomes the input for the next pass
- Parse or hardcode the pass chain for each multi-pass shader preset
- Priority shaders to port: `crt-royale` (8 passes), `crt-guest-advanced` (6 passes), `newpixie-crt` (4 passes)

---

## 3. Video export
Process and export the video file with the selected shader baked in.

**What's needed:**
- Use `AVAssetWriter` + `AVAssetWriterInput` + `AVAssetWriterInputPixelBufferAdaptor`
- Render each frame offscreen through the Metal shader pipeline
- Write processed frames to an output `.mov` or `.mp4`
- Add progress bar to the UI during export
- Export button is already in the UI but currently disabled

---

## 4. Shader presets / favorites
Let users save a shader + parameter combination as a named preset and recall it later.

---

## 5. Upscaling shaders
The repo also has edge-smoothing and upscaling shaders (xBR, NEDI, hqx, scalefx). These could be added as a separate "Upscale" category in the sidebar separate from CRT effects.

---

## 6. App icon + polish
- Add a proper app icon
- Window title bar shows "Seurat Shader"
- Drag-and-drop video files onto the window
- Remember last used shader between launches (UserDefaults)
