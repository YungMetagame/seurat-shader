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
    ShaderOption(id: 18, name: "Yee64",         desc: "C64-style — Gaussian pixel blur + scanline dimming"),
]

struct ContentView: View {
    @State private var videoURL: URL? = nil
    @State private var isFileImporterPresented = false
    @State private var selectedShaderID: UInt32 = 0
    @State private var renderer: Renderer? = nil

    // Playback state polled from renderer
    @State private var isPlaying = true
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1
    @State private var isScrubbing = false

    let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var selectedShader: ShaderOption {
        shaderOptions.first { $0.id == selectedShaderID } ?? shaderOptions[0]
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

                // Shader sidebar
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
                    Spacer()
                }
                .frame(width: 200)
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
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "film")
                                    .font(.system(size: 40)).foregroundColor(.secondary)
                                Text("No video selected").foregroundColor(.secondary)
                            }
                        }
                    }
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
        .frame(minWidth: 820, minHeight: 560)
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
