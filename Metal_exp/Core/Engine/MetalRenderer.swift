
import Foundation
import MetalKit

class Renderer: NSObject {
    
    var parent: MetalView!
    
    /// This is the current time in our app, starting at 0, in units of seconds
    let gpuLock = DispatchSemaphore(value: 1)
    
    // MARK: - time tracking properties
    var timer: Timer?
    /// stores current time to update every frame at 0.016 sec
    var currentTime: Double = 0
    /// This keeps track of the system time of the last render
    var lastRenderTime: CFTimeInterval? = nil
    
    
    // MARK: - Metal Renderer properties
    var metalDevice: MTLDevice!
    var metalCommandQueue: MTLCommandQueue!
    var vertexBuffer: MTLBuffer!
    var fragmentBuffer: MTLBuffer!
    var pipelineState: MTLRenderPipelineState?
    
    // MARK: - Screen properties
    /// You set two triangles that covers the whole screen coordinate system
    let vertices = VertexConstants.default
    
    // MARK: - Init
    init(_ parent: MetalView) {
        self.parent = parent
        if let device = MTLCreateSystemDefaultDevice() {
            self.metalDevice = device
        }
        super.init()
        
        setupPipeline()
        startTimer()
    }
    
    // MARK: - Selector
    @objc func updateAndDraw() {
        parent.mtkView.setNeedsDisplay()
    }
    
    /// Updates the time to process fragment shader animation
    func update(dt: CFTimeInterval) {
        currentTime += dt
    }
    
}

// MARK: - MTKViewdelegate

extension Renderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        // tell the gpu to wait for buffers
        gpuLock.wait()
        
        // Drawable
        guard let drawable = view.currentDrawable else { return }
        
        // Compute dt
        let systemTime = CACurrentMediaTime()
        
        var timeDifference: CFTimeInterval = 0
        if let lastTime = lastRenderTime {
            timeDifference = systemTime - lastTime
        }
        
        // Save this system time
        lastRenderTime = systemTime
        // Update state
        update(dt: timeDifference)
        
        // Command buffer
        let commandBuffer = metalCommandQueue.makeCommandBuffer()
        
        // Render
        guard
            let renderEncoder = self.makeEncoder(with: parent.mtkView, and: commandBuffer)
        else { return }
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // Convert to UnsafeMutablePointer
        var unsafeBytes: MetalUniforms = .default(withCurrentTime: currentTime)
        // update the buffer pointer to update animation
        memcpy(fragmentBuffer.contents(), &unsafeBytes, MemoryLayout<MetalUniforms>.stride)
        
        renderEncoder.setFragmentBuffer(fragmentBuffer, offset: 0, index: 0)
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
        
        renderEncoder.endEncoding()
        commandBuffer?.present(drawable)
        
        // Send info to gpu when computation is done
        commandBuffer?.addCompletedHandler { _ in
            self.gpuLock.signal()
        }
        
        commandBuffer?.commit()
        
    }
}
private extension Renderer {
    
    func setupPipeline() {
        self.metalCommandQueue = metalDevice.makeCommandQueue()
        
        // Define bundle files library to look for shaders
        let library = metalDevice.makeDefaultLibrary()
        
        // load the shader files
        guard let vertexFunction = library?.makeFunction(name: "vertex_main") else {
            fatalError("Unable to load vertex shader function")
        }
        
        guard let fragmentFunction = library?.makeFunction(name: "fragment_main") else {
            fatalError("Unable to load fragment shader function")
        }
        
        // Create the pipeline descriptor with vertex and fragment from metal files
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Create the pipeline
        do {
            try pipelineState =  metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Error loadingPipeline")
        }
        
        // Load the buffers in the device
        vertexBuffer = metalDevice.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<SIMD2<Float>>.stride,
            options: []
        )!
        
        fragmentBuffer = metalDevice.makeBuffer(
            length: MemoryLayout<MetalUniforms>.stride,
            options: []
        )
    }
    
    func makeEncoder(with view: MTKView, and commandBuffer: MTLCommandBuffer?) -> MTLRenderCommandEncoder? {
        // Create Render descriptor
        let renderPassDescriptor = view.currentRenderPassDescriptor
        renderPassDescriptor?.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1.0)
        renderPassDescriptor?.colorAttachments[0].loadAction = .clear
        renderPassDescriptor?.colorAttachments[0].storeAction = .store
        
        let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor!)
        
        guard let pipelineState else { fatalError("Failed to initialize pipeline state") }
        
        renderEncoder?.setRenderPipelineState(pipelineState)
        return renderEncoder
    }
    
    func startTimer() {
        // Invalidate the existing timer, if any
        timer?.invalidate()
        
        // Create a new timer that calls the updateAndDraw method every second
        timer = Timer.scheduledTimer(timeInterval: 0.016, target: self, selector: #selector(updateAndDraw), userInfo: nil, repeats: true)
    }
}
