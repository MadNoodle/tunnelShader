//
//  Uniforms.swift
//  Metal_exp
//
//  Created by User on 19.1.2024.
//

import simd
import UIKit

struct Uniforms {
    var iResolution: SIMD3<Float>           // viewport resolution (in pixels)
    var iTime: Float                        // shader playback time (in seconds)
    var iFrame: Int                         // shader playback frame
}

extension Uniforms {
    static func `default`(withTime currentTime: Double) -> Self {
        let screenBounds = UIScreen.main.bounds
        // Set up fragment buffer
        return Uniforms(
            iResolution: SIMD3<Float>(Float(screenBounds.size.width), Float(screenBounds.size.height), 1),
            iTime: Float(currentTime),
            iFrame: 0
        )
    }
}
