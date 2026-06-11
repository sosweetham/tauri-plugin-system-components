//
//  ImageUtil.swift
//  tauri-plugin-liquid-glass
//
//  base64 → UIImage decoding plus the avatar-style transforms used by tab
//  items and image components.
//

import UIKit

enum ImageUtil {
    /// Decodes a raw base64 string or a `data:` URL into a UIImage.
    static func decode(_ input: String) -> UIImage? {
        var b64 = Substring(input)
        if input.hasPrefix("data:"), let comma = input.firstIndex(of: ",") {
            b64 = input[input.index(after: comma)...]
        }
        guard
            let data = Data(
                base64Encoded: String(b64).trimmingCharacters(in: .whitespacesAndNewlines),
                options: .ignoreUnknownCharacters
            )
        else { return nil }
        return UIImage(data: data)
    }

    /// Aspect-fills `image` into a `side`×`side` square, optionally clipped
    /// to a circle — the avatar treatment.
    static func icon(_ image: UIImage, side: CGFloat, circular: Bool) -> UIImage {
        let size = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: size)
        let rendered = renderer.image { _ in
            if circular {
                UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
            }
            // Aspect-fill into the square.
            let scale = max(side / image.size.width, side / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(x: (side - drawSize.width) / 2, y: (side - drawSize.height) / 2)
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
        // Keep original colors (tab bars tint template images).
        return rendered.withRenderingMode(.alwaysOriginal)
    }
}
