import CoreMotion
import simd

/// Giroscópio -> rotação da câmera virtual (espaço da cena: Y para cima, -Z para frente).
final class MotionController {
    private let manager = CMMotionManager()
    private var headingZero: Float = 0
    private var needsRecenter = true
    var enabled = true

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical)
    }

    func recenter() {
        needsRecenter = true
    }

    func rotation() -> simd_float3x3 {
        guard enabled, let att = manager.deviceMotion?.attitude else {
            return matrix_identity_float3x3
        }
        let m = att.rotationMatrix
        // R leva referência -> dispositivo; a transposta leva dispositivo -> referência
        let r = simd_float3x3(rows: [
            SIMD3<Float>(Float(m.m11), Float(m.m12), Float(m.m13)),
            SIMD3<Float>(Float(m.m21), Float(m.m22), Float(m.m23)),
            SIMD3<Float>(Float(m.m31), Float(m.m32), Float(m.m33))
        ])
        let deviceToRef = r.transpose
        // referência (Z para cima) -> cena (Y para cima)
        let refToScene = simd_float3x3(rows: [
            SIMD3<Float>(1, 0, 0),
            SIMD3<Float>(0, 0, 1),
            SIMD3<Float>(0, -1, 0)
        ])
        let cam = refToScene * deviceToRef
        if needsRecenter {
            let f = cam * SIMD3<Float>(0, 0, -1)
            if abs(f.x) + abs(f.z) > 0.15 {
                headingZero = atan2(f.x, -f.z)
                needsRecenter = false
            }
        }
        return rotationY(headingZero) * cam
    }
}
