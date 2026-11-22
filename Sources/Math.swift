import simd

extension simd_float4x4 {
    init(rotation m: simd_float3x3) {
        self.init(columns: (
            SIMD4<Float>(m.columns.0.x, m.columns.0.y, m.columns.0.z, 0),
            SIMD4<Float>(m.columns.1.x, m.columns.1.y, m.columns.1.z, 0),
            SIMD4<Float>(m.columns.2.x, m.columns.2.y, m.columns.2.z, 0),
            SIMD4<Float>(0, 0, 0, 1)))
    }

    static func translation(_ t: SIMD3<Float>) -> simd_float4x4 {
        return simd_float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(t.x, t.y, t.z, 1)))
    }

    /// Perspectiva mão direita, Y para cima, profundidade Metal 0...1
    static func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
        let ys = 1 / tan(fovY * 0.5)
        let xs = ys / aspect
        let zs = far / (near - far)
        return simd_float4x4(columns: (
            SIMD4<Float>(xs, 0, 0, 0),
            SIMD4<Float>(0, ys, 0, 0),
            SIMD4<Float>(0, 0, zs, -1),
            SIMD4<Float>(0, 0, zs * near, 0)))
    }

    /// Translação * Rotação(quaternion x,y,z,w) * Escala
    static func trs(t: SIMD3<Float>, q: SIMD4<Float>, s: SIMD3<Float>) -> simd_float4x4 {
        let len = max(sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w), 1e-6)
        let x = q.x / len, y = q.y / len, z = q.z / len, w = q.w / len
        let c0 = SIMD4<Float>(1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w), 0) * s.x
        let c1 = SIMD4<Float>(2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w), 0) * s.y
        let c2 = SIMD4<Float>(2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y), 0) * s.z
        return simd_float4x4(columns: (c0, c1, c2, SIMD4<Float>(t.x, t.y, t.z, 1)))
    }
}

func rotationY(_ a: Float) -> simd_float3x3 {
    let c = cos(a), s = sin(a)
    return simd_float3x3(columns: (
        SIMD3<Float>(c, 0, -s),
        SIMD3<Float>(0, 1, 0),
        SIMD3<Float>(s, 0, c)))
}

func rotationX(_ a: Float) -> simd_float3x3 {
    let c = cos(a), s = sin(a)
    return simd_float3x3(columns: (
        SIMD3<Float>(1, 0, 0),
        SIMD3<Float>(0, c, s),
        SIMD3<Float>(0, -s, c)))
}
