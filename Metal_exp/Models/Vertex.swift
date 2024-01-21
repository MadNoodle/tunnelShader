//
//  Vertex.swift
//  Metal_exp
//
//  Created by User on 21.1.2024.
//

import Foundation
import simd

typealias Vertex = SIMD2<Float>

enum VertexConstants {
    static let `default` = [
        Vertex(-1, -1),
        Vertex(1, -1),
        Vertex(1, 1),
        Vertex(1, 1),
        Vertex(-1, 1),
        Vertex(-1, -1)
    ]
}
