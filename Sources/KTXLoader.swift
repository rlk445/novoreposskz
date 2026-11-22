import Metal
import Foundation

/// Leitor de KTX1 com ASTC (formato usado pelos cenários do Quest).
enum KTXLoader {
    struct Format {
        let pixel: MTLPixelFormat
        let bw: Int
        let bh: Int
    }

    static func format(for gl: Int) -> Format? {
        switch gl {
        case 0x93B0: return Format(pixel: .astc_4x4_ldr, bw: 4, bh: 4)
        case 0x93B1: return Format(pixel: .astc_5x4_ldr, bw: 5, bh: 4)
        case 0x93B2: return Format(pixel: .astc_5x5_ldr, bw: 5, bh: 5)
        case 0x93B3: return Format(pixel: .astc_6x5_ldr, bw: 6, bh: 5)
        case 0x93B4: return Format(pixel: .astc_6x6_ldr, bw: 6, bh: 6)
        case 0x93B5: return Format(pixel: .astc_8x5_ldr, bw: 8, bh: 5)
        case 0x93B6: return Format(pixel: .astc_8x6_ldr, bw: 8, bh: 6)
        case 0x93B7: return Format(pixel: .astc_8x8_ldr, bw: 8, bh: 8)
        case 0x93B8: return Format(pixel: .astc_10x5_ldr, bw: 10, bh: 5)
        case 0x93B9: return Format(pixel: .astc_10x6_ldr, bw: 10, bh: 6)
        case 0x93BA: return Format(pixel: .astc_10x8_ldr, bw: 10, bh: 8)
        case 0x93BB: return Format(pixel: .astc_10x10_ldr, bw: 10, bh: 10)
        case 0x93BC: return Format(pixel: .astc_12x10_ldr, bw: 12, bh: 10)
        case 0x93BD: return Format(pixel: .astc_12x12_ldr, bw: 12, bh: 12)
        case 0x93D0: return Format(pixel: .astc_4x4_srgb, bw: 4, bh: 4)
        case 0x93D1: return Format(pixel: .astc_5x4_srgb, bw: 5, bh: 4)
        case 0x93D2: return Format(pixel: .astc_5x5_srgb, bw: 5, bh: 5)
        case 0x93D3: return Format(pixel: .astc_6x5_srgb, bw: 6, bh: 5)
        case 0x93D4: return Format(pixel: .astc_6x6_srgb, bw: 6, bh: 6)
        case 0x93D5: return Format(pixel: .astc_8x5_srgb, bw: 8, bh: 5)
        case 0x93D6: return Format(pixel: .astc_8x6_srgb, bw: 8, bh: 6)
        case 0x93D7: return Format(pixel: .astc_8x8_srgb, bw: 8, bh: 8)
        case 0x93D8: return Format(pixel: .astc_10x5_srgb, bw: 10, bh: 5)
        case 0x93D9: return Format(pixel: .astc_10x6_srgb, bw: 10, bh: 6)
        case 0x93DA: return Format(pixel: .astc_10x8_srgb, bw: 10, bh: 8)
        case 0x93DB: return Format(pixel: .astc_10x10_srgb, bw: 10, bh: 10)
        case 0x93DC: return Format(pixel: .astc_12x10_srgb, bw: 12, bh: 10)
        case 0x93DD: return Format(pixel: .astc_12x12_srgb, bw: 12, bh: 12)
        default: return nil
        }
    }

    static func load(url: URL, device: MTLDevice) -> MTLTexture? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe), data.count > 68 else {
            return nil
        }
        return data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> MTLTexture? in
            guard let base = raw.baseAddress else { return nil }
            func u32(_ o: Int) -> Int {
                return Int(raw.loadUnaligned(fromByteOffset: o, as: UInt32.self))
            }
            // identificador "\xABKTX 11\xBB"
            guard raw[1] == 0x4B, raw[2] == 0x54, raw[3] == 0x58 else { return nil }
            guard u32(12) == 0x04030201 else { return nil }
            guard let fmt = format(for: u32(28)) else { return nil }
            let w = u32(36)
            let h = u32(40)
            let faces = max(1, u32(52))
            let mips = max(1, u32(56))
            let kv = u32(60)
            guard w > 0, h > 0, faces == 1 else { return nil }

            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: fmt.pixel, width: w, height: h, mipmapped: mips > 1)
            desc.mipmapLevelCount = mips
            desc.usage = .shaderRead
            desc.storageMode = .shared
            guard let tex = device.makeTexture(descriptor: desc) else { return nil }

            var off = 64 + kv
            for level in 0..<mips {
                guard off + 4 <= data.count else { break }
                let size = u32(off)
                off += 4
                guard off + size <= data.count else { break }
                let lw = max(1, w >> level)
                let lh = max(1, h >> level)
                let bytesPerRow = ((lw + fmt.bw - 1) / fmt.bw) * 16
                tex.replace(region: MTLRegionMake2D(0, 0, lw, lh),
                            mipmapLevel: level,
                            withBytes: base.advanced(by: off),
                            bytesPerRow: bytesPerRow)
                off += (size + 3) & ~3
            }
            return tex
        }
    }
}
