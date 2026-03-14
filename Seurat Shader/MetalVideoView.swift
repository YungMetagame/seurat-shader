//
//  MetalVideoView.swift
//  Seurat Shader
//

import SwiftUI
import MetalKit

struct MetalVideoView: NSViewRepresentable {
    let videoURL: URL?
    let shaderIndex: UInt32
    // Binding so ContentView can call play/pause/seek
    @Binding var renderer: Renderer?

    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        if let r = Renderer(mtkView: mtkView, videoURL: videoURL) {
            r.shaderParams.shaderIndex = shaderIndex
            context.coordinator.renderer = r
            context.coordinator.lastURL = videoURL
            DispatchQueue.main.async { renderer = r }
        }
        return mtkView
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        guard let r = context.coordinator.renderer else { return }
        r.shaderParams.shaderIndex = shaderIndex
        if let url = videoURL, url != context.coordinator.lastURL {
            context.coordinator.lastURL = url
            r.setupVideo(url: url)
            DispatchQueue.main.async { renderer = r }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var renderer: Renderer?
        var lastURL: URL?
    }
}
