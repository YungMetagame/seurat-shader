//
//  ContentView.swift
//  Seurat Shader
//

import SwiftUI

struct ShaderOption: Identifiable {
    let id: UInt32; let name: String; let desc: String
}

let shaderOptions: [ShaderOption] = [
    ShaderOption(id: 0,  name: "None",          desc: "Raw video passthrough"),
    ShaderOption(id: 1,  name: "CRT-Lottes",    desc: "Timothy Lottes arcade CRT — warp, scanlines, RGB mask, bloom"),
    ShaderOption(id: 2,  name: "CRT-Royale",    desc: "Kurozumi Trinitron — aperture grille, halation, vignette"),
    ShaderOption(id: 3,  name: "Scanlines",     desc: "Simple sine scanline darkening"),
    ShaderOption(id: 4,  name: "VHS",           desc: "Chroma shift, horizontal wobble, luma noise"),
    ShaderOption(id: 5,  name: "EasyMode",      desc: "Flat CRT — adaptive scanlines, staggered RGB dot mask"),
    ShaderOption(id: 6,  name: "FakeLottes",    desc: "Sine scanlines + aperture grille + gamma — fast"),
    ShaderOption(id: 7,  name: "CRT-Pi",        desc: "Raspberry Pi CRT — multisampled scanlines, trinitron mask"),
    ShaderOption(id: 8,  name: "Caligari",      desc: "Phosphor spot shader — soft per-pixel glow bleed"),
    ShaderOption(id: 9,  name: "CRT-Geom",      desc: "Spherical curvature, corner rounding, Lanczos filter"),
    ShaderOption(id: 10, name: "CRT-Mattias",   desc: "Gaussian bloom + crawling scanlines + film noise"),
    ShaderOption(id: 11, name: "CRT-Frutbunn",  desc: "Gaussian blur + vignette + cosine scanlines"),
    ShaderOption(id: 12, name: "CRT-cgwg",      desc: "cgwg classic — Lanczos filter + beam width + green/magenta mask"),
    ShaderOption(id: 13, name: "CRT-Simple",    desc: "DOLLS/cgwg — Gaussian beam scanlines + dot mask + barrel"),
    ShaderOption(id: 14, name: "CRT-Sines",     desc: "DariusG — sharp bilinear + chroma ghost + sine scanlines"),
    ShaderOption(id: 15, name: "Gizmo-CRT",     desc: "Subpixel RGB shift + brightness scanlines + noise"),
    ShaderOption(id: 16, name: "ZFast-CRT",     desc: "Greg Hogan — composite convergence + sine scanlines, fast"),
    ShaderOption(id: 17, name: "Yeetron",       desc: "Per-pixel scanline dimming + RGB channel weighting"),
    ShaderOption(id: 18, name: "Yee64",             desc: "C64-style — Gaussian pixel blur + scanline dimming"),
    ShaderOption(id: 19, name: "Fluid Iridescence", desc: "fBm turbulence distortion + oil-slick YIQ hue shift"),
    ShaderOption(id: 20, name: "VGA 256",           desc: "P22 phosphor glow, brick dot-pitch mask, convergence error, 9300K"),
]

// ─── Per-shader parameter definitions ────────────────────────────────────────

struct ShaderParam {
    let name: String
    let min: Float
    let max: Float
    let defaultValue: Float
}

let shaderParamDefs: [UInt32: [ShaderParam]] = [
    1: [  // CRT-Lottes
        ShaderParam(name: "Warp X",    min: 0,    max: 0.15, defaultValue: 0.031),
        ShaderParam(name: "Warp Y",    min: 0,    max: 0.15, defaultValue: 0.041),
        ShaderParam(name: "Mask Dark", min: 0,    max: 1.0,  defaultValue: 0.25),
        ShaderParam(name: "Bloom",     min: 0,    max: 0.3,  defaultValue: 0.08),
    ],
    2: [  // CRT-Royale
        ShaderParam(name: "Warp X",        min: 0,   max: 0.12, defaultValue: 0.025),
        ShaderParam(name: "Warp Y",        min: 0,   max: 0.12, defaultValue: 0.035),
        ShaderParam(name: "Mask Dark",     min: 0,   max: 0.5,  defaultValue: 0.08),
        ShaderParam(name: "Mask Strength", min: 0,   max: 1.0,  defaultValue: 0.7),
    ],
    3: [  // Scanlines
        ShaderParam(name: "Strength", min: 0, max: 0.6, defaultValue: 0.35),
    ],
    4: [  // VHS
        ShaderParam(name: "Chroma Shift", min: 0,     max: 0.02,  defaultValue: 0.003),
        ShaderParam(name: "Wobble",       min: 0,     max: 0.008, defaultValue: 0.002),
        ShaderParam(name: "Saturation",   min: 0,     max: 1.0,   defaultValue: 0.85),
    ],
    5: [  // EasyMode
        ShaderParam(name: "Mask Dark", min: 0,   max: 1.0, defaultValue: 0.7),
        ShaderParam(name: "Gamma",     min: 1.0, max: 3.0, defaultValue: 1.8),
    ],
    6: [  // FakeLottes
        ShaderParam(name: "Warp X", min: 0, max: 0.15, defaultValue: 0.031),
        ShaderParam(name: "Warp Y", min: 0, max: 0.15, defaultValue: 0.041),
    ],
    7: [  // CRT-Pi
        ShaderParam(name: "Dist X", min: 0, max: 0.3, defaultValue: 0.10),
        ShaderParam(name: "Dist Y", min: 0, max: 0.3, defaultValue: 0.15),
    ],
    8: [  // Caligari
        ShaderParam(name: "Brightness", min: 0.5, max: 2.5, defaultValue: 1.45),
        ShaderParam(name: "H-Spread",   min: 0.3, max: 2.0, defaultValue: 0.9),
        ShaderParam(name: "V-Spread",   min: 0.3, max: 2.0, defaultValue: 0.65),
    ],
    9: [  // CRT-Geom
        ShaderParam(name: "Curvature", min: 0.5, max: 5.0,  defaultValue: 2.0),
        ShaderParam(name: "Corner",    min: 0.0, max: 0.1,   defaultValue: 0.03),
        ShaderParam(name: "Dot Mask",  min: 0.0, max: 1.0,   defaultValue: 0.3),
    ],
    10: [ // CRT-Mattias
        ShaderParam(name: "Noise",      min: 0,   max: 0.15, defaultValue: 0.04),
        ShaderParam(name: "Scan Speed", min: 0.5, max: 10.0, defaultValue: 3.5),
    ],
    11: [ // CRT-Frutbunn
        ShaderParam(name: "Curvature",     min: 0.85, max: 1.05, defaultValue: 0.935),
        ShaderParam(name: "Scan Strength", min: 0,    max: 0.5,  defaultValue: 0.25),
    ],
    13: [ // CRT-Simple
        ShaderParam(name: "Dist X", min: 0, max: 0.3, defaultValue: 0.12),
        ShaderParam(name: "Dist Y", min: 0, max: 0.3, defaultValue: 0.18),
    ],
    14: [ // CRT-Sines
        ShaderParam(name: "Chroma Pixels", min: 0,   max: 3.0, defaultValue: 0.5),
        ShaderParam(name: "Scan Strength", min: 0,   max: 1.5, defaultValue: 1.0),
    ],
    15: [ // Gizmo-CRT
        ShaderParam(name: "Dist X", min: 0, max: 0.3, defaultValue: 0.10),
        ShaderParam(name: "Dist Y", min: 0, max: 0.3, defaultValue: 0.15),
    ],
    16: [ // ZFast-CRT
        ShaderParam(name: "Warp X",  min: 0, max: 0.1,  defaultValue: 0.03),
        ShaderParam(name: "Warp Y",  min: 0, max: 0.1,  defaultValue: 0.05),
        ShaderParam(name: "Flicker", min: 0, max: 0.05, defaultValue: 0.01),
    ],
    19: [ // Fluid Iridescence
        ShaderParam(name: "Speed",       min: 0.05, max: 2.0,  defaultValue: 0.4),
        ShaderParam(name: "Strength",    min: 0.0,  max: 0.08, defaultValue: 0.025),
        ShaderParam(name: "Scale",       min: 0.5,  max: 6.0,  defaultValue: 2.5),
        ShaderParam(name: "Iridescence", min: 0.0,  max: 2.0,  defaultValue: 0.8),
    ],
    20: [ // VGA 256
        ShaderParam(name: "Curve",     min: 0.0, max: 0.5,  defaultValue: 0.12),
        ShaderParam(name: "Glow",      min: 0.0, max: 2.0,  defaultValue: 0.80),
        ShaderParam(name: "Scanlines", min: 0.0, max: 1.0,  defaultValue: 0.70),
        ShaderParam(name: "Mask",      min: 0.0, max: 1.0,  defaultValue: 0.55),
    ],
]

// ─── ContentView ─────────────────────────────────────────────────────────────

struct ContentView: View {
    @State private var videoURL: URL? = nil
    @State private var isFileImporterPresented = false
    @State private var selectedShaderID: UInt32 = 0
    @State private var renderer: Renderer? = nil
    // Per-shader saved param values (keyed by shader ID)
    @State private var allParamValues: [UInt32: [Float]] = [:]

    // Zoom / pan for phosphor inspection
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero
    @GestureState private var liveZoom: CGFloat = 1.0

    // Playback state polled from renderer
    @State private var isPlaying = true
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1
    @State private var isScrubbing = false

    let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var selectedShader: ShaderOption {
        shaderOptions.first { $0.id == selectedShaderID } ?? shaderOptions[0]
    }

    var currentParamDefs: [ShaderParam] {
        shaderParamDefs[selectedShaderID] ?? []
    }

    func paramValues(for id: UInt32) -> [Float] {
        if let saved = allParamValues[id] { return saved }
        return (shaderParamDefs[id] ?? []).map { $0.defaultValue }
    }

    func applyParams(shaderID: UInt32) {
        renderer?.applyExternalParams(shaderIndex: shaderID, paramValues: paramValues(for: shaderID))
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Top bar ──────────────────────────────────────────────────────
            HStack(spacing: 12) {
                Button("Choose Video…") { isFileImporterPresented = true }
                    .fileImporter(isPresented: $isFileImporterPresented,
                                  allowedContentTypes: [.movie, .video],
                                  allowsMultipleSelection: false) { result in
                        if case .success(let urls) = result { videoURL = urls.first }
                    }
                if let name = videoURL?.lastPathComponent {
                    Text(name).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
                Button("Export…") { }
                    .disabled(videoURL == nil)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // ── Main area ────────────────────────────────────────────────────
            HStack(spacing: 0) {

                // Shader sidebar + parameter panel
                VStack(alignment: .leading, spacing: 0) {
                    Text("SHADERS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 6)
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(shaderOptions) { shader in
                                ShaderRow(shader: shader, isSelected: shader.id == selectedShaderID)
                                    .onTapGesture { selectedShaderID = shader.id }
                            }
                        }
                    }

                    // ── Parameter panel ──────────────────────────────────────
                    if !currentParamDefs.isEmpty {
                        Divider()
                        ParamPanel(
                            defs: currentParamDefs,
                            values: paramValues(for: selectedShaderID),
                            onValueChange: { index, value in
                                var vals = paramValues(for: selectedShaderID)
                                vals[index] = value
                                allParamValues[selectedShaderID] = vals
                                renderer?.applyExternalParams(shaderIndex: selectedShaderID, paramValues: vals)
                            },
                            onReset: {
                                allParamValues.removeValue(forKey: selectedShaderID)
                                applyParams(shaderID: selectedShaderID)
                            }
                        )
                    } else {
                        Spacer()
                    }
                }
                .frame(width: 220)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Preview + controls
                VStack(spacing: 0) {
                    // Video preview
                    ZStack {
                        Color.black
                        if let url = videoURL {
                            MetalVideoView(videoURL: url,
                                           shaderIndex: selectedShaderID,
                                           renderer: $renderer)
                                .scaleEffect(zoomScale * liveZoom, anchor: .center)
                                .offset(panOffset)
                                // Pinch to zoom (trackpad two-finger pinch)
                                .gesture(
                                    MagnificationGesture()
                                        .updating($liveZoom) { val, state, _ in state = val }
                                        .onEnded { val in
                                            zoomScale = max(1.0, min(20.0, lastZoomScale * val))
                                            lastZoomScale = zoomScale
                                        }
                                )
                                // Drag to pan when zoomed in
                                .gesture(
                                    DragGesture()
                                        .onChanged { val in
                                            guard zoomScale > 1.0 else { return }
                                            panOffset = CGSize(
                                                width:  lastPanOffset.width  + val.translation.width,
                                                height: lastPanOffset.height + val.translation.height
                                            )
                                        }
                                        .onEnded { _ in lastPanOffset = panOffset }
                                )
                                // Double-click to reset
                                .onTapGesture(count: 2) {
                                    withAnimation(.spring(response: 0.3)) {
                                        zoomScale = 1.0; lastZoomScale = 1.0
                                        panOffset = .zero; lastPanOffset = .zero
                                    }
                                }
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "film")
                                    .font(.system(size: 40)).foregroundColor(.secondary)
                                Text("No video selected").foregroundColor(.secondary)
                            }
                        }
                    }
                    .clipped()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    // ── Player controls ──────────────────────────────────────
                    VStack(spacing: 6) {
                        // Scrub bar
                        Slider(
                            value: Binding(
                                get: { isScrubbing ? currentTime : currentTime },
                                set: { val in
                                    currentTime = val
                                    renderer?.seek(to: val)
                                }
                            ),
                            in: 0...max(duration, 1)
                        )
                        .padding(.horizontal, 14)
                        .disabled(videoURL == nil)

                        // Buttons + time
                        HStack(spacing: 16) {
                            // Rewind 10s
                            Button { renderer?.seek(to: max(0, currentTime - 10)) } label: {
                                Image(systemName: "gobackward.10")
                            }
                            .buttonStyle(.plain).disabled(videoURL == nil)

                            // Play / Pause
                            Button { renderer?.togglePlayPause(); isPlaying.toggle() } label: {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18))
                            }
                            .buttonStyle(.plain).disabled(videoURL == nil)

                            // Forward 10s
                            Button { renderer?.seek(to: min(duration, currentTime + 10)) } label: {
                                Image(systemName: "goforward.10")
                            }
                            .buttonStyle(.plain).disabled(videoURL == nil)

                            Spacer()

                            // Time display
                            Text("\(formatTime(currentTime)) / \(formatTime(duration))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)

                            // Active shader label
                            Text(selectedShader.name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 10)
                    }
                    .background(Color(NSColor.windowBackgroundColor))
                }
            }
        }
        .frame(minWidth: 840, minHeight: 560)
        .onChange(of: selectedShaderID) { newID in
            applyParams(shaderID: newID)
        }
        .onChange(of: renderer) { _ in
            applyParams(shaderID: selectedShaderID)
        }
        .onReceive(timer) { _ in
            guard !isScrubbing, let r = renderer else { return }
            isPlaying   = r.isPlaying
            currentTime = r.currentTime
            let d = r.duration
            if d.isFinite && d > 0 { duration = d }
        }
    }

    func formatTime(_ s: Double) -> String {
        guard s.isFinite else { return "0:00" }
        let t = Int(s)
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

// ─── Parameter panel ─────────────────────────────────────────────────────────

struct ParamPanel: View {
    let defs: [ShaderParam]
    let values: [Float]
    let onValueChange: (Int, Float) -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PARAMETERS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button("Reset") { onReset() }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)

            ForEach(Array(defs.enumerated()), id: \.offset) { i, param in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(param.name)
                            .font(.system(size: 11))
                        Spacer()
                        Text(formatParamValue(values[i]))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(values[i]) },
                            set: { onValueChange(i, Float($0)) }
                        ),
                        in: Double(param.min)...Double(param.max)
                    )
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }

            Spacer(minLength: 8)
        }
    }

    func formatParamValue(_ v: Float) -> String {
        if abs(v) < 0.01 && v != 0 { return String(format: "%.4f", v) }
        if abs(v) < 1    { return String(format: "%.3f", v) }
        return String(format: "%.2f", v)
    }
}

// ─── ShaderRow ───────────────────────────────────────────────────────────────

struct ShaderRow: View {
    let shader: ShaderOption
    let isSelected: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(shader.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                Text(shader.desc)
                    .font(.system(size: 10)).foregroundColor(.secondary).lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }
}

#Preview { ContentView() }
