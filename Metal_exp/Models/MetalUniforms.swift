//
//  MetalUniforms.swift
//  Metal_exp
//
//  Created by User on 21.1.2024.
//

import Foundation
import simd

/// Struct to transform to unsafe mutable pointer
struct MetalUniforms {
    // MARK: - Properties
    var iResolution: simd_float3
    var iTime: Float
    var iFrame: Int

    // MARK: - Init
    init(uniforms: Uniforms) {
        iResolution = uniforms.iResolution
        iTime = uniforms.iTime
        iFrame = uniforms.iFrame
    }
}

extension MetalUniforms {
    static func `default`(withCurrentTime currentTime: Double) -> Self {
        return MetalUniforms(uniforms: .default(withTime: currentTime))
    }
}
