//
//  Renderer.swift
//  Seurat Shader
//

import Foundation
import MetalKit
import AVFoundation
import CoreVideo

// Must exactly match ShaderParams in Shaders.metal
struct ShaderParams {
    var shaderIndex: UInt32 = 0
    var time: Float         = 0.0
    var p0: Float           = 0.0
    var p1: Float           = 0.0
    var p2: Float           = 0.0
    var p3: Float           = 0.0
    var p4: Float           = 0.0
    var p5: Float           = 0.0
    var p6: Float           = 0.0
    var p7: Float           = 0.0
}

class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLRenderPipelineState!

    var player: AVPlayer?
    var playerItem: AVPlayerItem?
    var playerItemOutput: AVPlayerItemVideoOutput?
    var textureCache: CVMetalTextureCache?
    var lastTexture: MTLTexture?
    private var securityScopedURL: URL?
    private var readyToPlay = false

    // Video natural size — used for aspect ratio letterboxing
    private(set) var videoSize: CGSize = .zero

    var shaderParams = ShaderParams()
    private var frameTime: Float = 0.0

    // Aspect-correct quad — recomputed when videoSize or view size changes
    private var quadVertices: [Float] = []
    private var lastViewSize: CGSize = .zero

    init?(mtkView: MTKView, videoURL: URL?) {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        self.device = device
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly  = false
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.preferredFramesPerSecond = 60

        guard let cq = device.makeCommandQueue() else { return nil }
        self.commandQueue = cq

        super.init()

        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        guard buildPipeline(pixelFormat: .bgra8Unorm) else { return nil }
        mtkView.delegate = self
        if let url = videoURL { setupVideo(url: url) }
    }

    deinit {
        playerItem?.removeObserver(self, forKeyPath: "status")
        securityScopedURL?.stopAccessingSecurityScopedResource()
    }

    private func buildPipeline(pixelFormat: MTLPixelFormat) -> Bool {
        guard let lib = device.makeDefaultLibrary() else { return false }
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction   = lib.makeFunction(name: "vertex_main")
        desc.fragmentFunction = lib.makeFunction(name: "fragment_main")
        desc.colorAttachments[0].pixelFormat = pixelFormat
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: desc)
            return true
        } catch { print("❌ Pipeline: \(error)"); return false }
    }

    // Builds a fullscreen quad that letterboxes the video to correct aspect ratio
    private func buildQuad(viewSize: CGSize) {
        guard videoSize.width > 0, videoSize.height > 0,
              viewSize.width > 0, viewSize.height > 0 else {
            // fallback: fill screen
            quadVertices = [
                -1,  1,  0, 0,
                 1,  1,  1, 0,
                -1, -1,  0, 1,
                 1,  1,  1, 0,
                 1, -1,  1, 1,
                -1, -1,  0, 1,
            ]
            return
        }
        let videoAspect = videoSize.width / videoSize.height
        let viewAspect  = viewSize.width  / viewSize.height
        var sx: Float = 1.0
        var sy: Float = 1.0
        if videoAspect > viewAspect {
            sy = Float(viewAspect / videoAspect)
        } else {
            sx = Float(videoAspect / viewAspect)
        }
        quadVertices = [
            -sx,  sy,  0, 0,
             sx,  sy,  1, 0,
            -sx, -sy,  0, 1,
             sx,  sy,  1, 0,
             sx, -sy,  1, 1,
            -sx, -sy,  0, 1,
        ]
    }

    // MARK: - Video setup

    func setupVideo(url: URL) {
        playerItem?.removeObserver(self, forKeyPath: "status")
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
        player?.pause()
        player = nil; playerItem = nil; playerItemOutput = nil
        lastTexture = nil; readyToPlay = false; videoSize = .zero

        let accessed = url.startAccessingSecurityScopedResource()
        if accessed { securityScopedURL = url }

        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            kCVPixelBufferMetalCompatibilityKey as String: true
        ])
        playerItemOutput = output

        let item = AVPlayerItem(url: url)
        item.add(output)
        playerItem = item
        item.addObserver(self, forKeyPath: "status", options: [.new], context: nil)

        NotificationCenter.default.addObserver(self,
            selector: #selector(didReachEnd),
            name: .AVPlayerItemDidPlayToEndTime, object: item)

        player = AVPlayer(playerItem: item)
        player?.actionAtItemEnd = .none
        player?.play()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "status", let item = object as? AVPlayerItem else { return }
        if item.status == .readyToPlay {
            readyToPlay = true
            // Grab natural video size for aspect ratio
            if let track = item.asset.tracks(withMediaType: .video).first {
                let size = track.naturalSize.applying(track.preferredTransform)
                videoSize = CGSize(width: abs(size.width), height: abs(size.height))
                buildQuad(viewSize: lastViewSize)
            }
        }
    }

    @objc private func didReachEnd() {
        player?.seek(to: .zero); player?.play()
    }

    // MARK: - Playback controls (called from SwiftUI)

    var isPlaying: Bool { player?.timeControlStatus == .playing }
    var duration: Double { playerItem?.duration.seconds ?? 0 }
    var currentTime: Double { player?.currentTime().seconds ?? 0 }

    func togglePlayPause() {
        guard let player else { return }
        if player.timeControlStatus == .playing { player.pause() }
        else { player.play() }
    }

    func seek(to seconds: Double) {
        let t = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // Apply shader index + per-shader param values from SwiftUI (preserves time)
    func applyExternalParams(shaderIndex: UInt32, paramValues: [Float]) {
        shaderParams.shaderIndex = shaderIndex
        shaderParams.p0 = paramValues.count > 0 ? paramValues[0] : 0
        shaderParams.p1 = paramValues.count > 1 ? paramValues[1] : 0
        shaderParams.p2 = paramValues.count > 2 ? paramValues[2] : 0
        shaderParams.p3 = paramValues.count > 3 ? paramValues[3] : 0
        shaderParams.p4 = paramValues.count > 4 ? paramValues[4] : 0
        shaderParams.p5 = paramValues.count > 5 ? paramValues[5] : 0
        shaderParams.p6 = paramValues.count > 6 ? paramValues[6] : 0
        shaderParams.p7 = paramValues.count > 7 ? paramValues[7] : 0
    }

    // MARK: - Texture

    private func makeTexture(from pb: CVPixelBuffer) -> MTLTexture? {
        guard let cache = textureCache else { return nil }
        let w = CVPixelBufferGetWidth(pb)
        let h = CVPixelBufferGetHeight(pb)
        var cvTex: CVMetalTexture?
        let r = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault, cache, pb, nil, .bgra8Unorm, w, h, 0, &cvTex)
        guard r == kCVReturnSuccess, let t = cvTex else { return nil }
        return CVMetalTextureGetTexture(t)
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        lastViewSize = size
        buildQuad(viewSize: size)
    }

    func draw(in view: MTKView) {
        frameTime += 1.0 / 60.0
        shaderParams.time = frameTime

        // Rebuild quad if view size changed
        let viewSize = view.drawableSize
        if viewSize != lastViewSize {
            lastViewSize = viewSize
            buildQuad(viewSize: viewSize)
        }

        if readyToPlay, let out = playerItemOutput {
            let t = out.itemTime(forHostTime: CACurrentMediaTime())
            if t.isValid, out.hasNewPixelBuffer(forItemTime: t),
               let pb = out.copyPixelBuffer(forItemTime: t, itemTimeForDisplay: nil) {
                lastTexture = makeTexture(from: pb)
            }
        }

        guard !quadVertices.isEmpty,
              let cb  = commandQueue.makeCommandBuffer(),
              let rpd = view.currentRenderPassDescriptor,
              let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else { return }

        enc.setRenderPipelineState(pipelineState)
        var verts = quadVertices
        enc.setVertexBytes(&verts, length: verts.count * MemoryLayout<Float>.stride, index: 0)
        if let tex = lastTexture { enc.setFragmentTexture(tex, index: 0) }
        var sp = shaderParams
        enc.setFragmentBytes(&sp, length: MemoryLayout<ShaderParams>.stride, index: 1)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        enc.endEncoding()
        if let drawable = view.currentDrawable { cb.present(drawable) }
        cb.commit()
    }
}
