# Seurat Shader

A macOS app for applying RetroArch-style CRT and video processing shaders to video files in real time, built with Swift + Metal on Apple Silicon.

## What it does

- Load any video file and preview it through a live Metal shader
- 19 CRT/video shaders ported from the RetroArch slang-shaders repository
- Play/pause, scrub, and skip controls
- Aspect-ratio-correct letterboxed preview

## Shaders included

| # | Name | Description |
|---|------|-------------|
| 0 | None | Raw passthrough |
| 1 | CRT-Lottes | Timothy Lottes arcade CRT — warp, scanlines, RGB mask, bloom |
| 2 | CRT-Royale | Kurozumi Trinitron — aperture grille, halation, vignette |
| 3 | Scanlines | Simple sine scanline darkening |
| 4 | VHS | Chroma shift, horizontal wobble, luma noise |
| 5 | EasyMode | Flat CRT — adaptive scanlines, staggered RGB dot mask |
| 6 | FakeLottes | Sine scanlines + aperture grille + gamma — fast |
| 7 | CRT-Pi | Raspberry Pi CRT — multisampled scanlines, trinitron mask |
| 8 | Caligari | Phosphor spot shader — soft per-pixel glow bleed |
| 9 | CRT-Geom | Spherical curvature, corner rounding, Lanczos filter |
| 10 | CRT-Mattias | Gaussian bloom + crawling scanlines + film noise |
| 11 | CRT-Frutbunn | Gaussian blur + vignette + cosine scanlines |
| 12 | CRT-cgwg | Classic cgwg — Lanczos filter + beam width + green/magenta mask |
| 13 | CRT-Simple | DOLLS/cgwg — Gaussian beam scanlines + dot mask + barrel |
| 14 | CRT-Sines | DariusG — sharp bilinear + chroma ghost + sine scanlines |
| 15 | Gizmo-CRT | Subpixel RGB shift + brightness scanlines + noise |
| 16 | ZFast-CRT | Greg Hogan — composite convergence + sine scanlines, fast |
| 17 | Yeetron | Per-pixel scanline dimming + RGB channel weighting |
| 18 | Yee64 | C64-style — Gaussian pixel blur + scanline dimming |

## Architecture

```
Seurat Shader/
├── SeuratShaderApp.swift       # App entry point
├── ContentView.swift           # Main UI — shader picker, player controls
├── MetalVideoView.swift        # NSViewRepresentable wrapping MTKView
├── Renderer.swift              # Metal renderer, AVFoundation video pipeline
└── Shaders.metal               # All 19 shaders in one Metal file
```

**Video pipeline:** `AVPlayer` → `AVPlayerItemVideoOutput` → `CVPixelBuffer` → `CVMetalTextureCache` → `MTLTexture` → fragment shader → `MTKView`

**Shader dispatch:** A single `fragment_main` function switches on `shaderIndex` from a `ShaderParams` buffer, routing to the correct shader function.

## Requirements

- macOS 13+
- Apple Silicon (M1/M2/M3) recommended
- Xcode 15+

## Building

1. Open `Seurat Shader.xcodeproj`
2. Select the `Seurat Shader` scheme
3. Hit ⌘R

## Shader sources

All shaders are ported from the [libretro/slang-shaders](https://github.com/libretro/slang-shaders) repository (GPL licensed). The original `.slang` files are included in the project as reference only — they are not compiled or bundled into the app.
