import AppKit
import Foundation

// Le calque de premier plan de l'icône, pour Icon Composer.
//
//   swift tools/IconComposerArtwork.swift App/AppIcon.icon/Assets/artwork.png
//
// Depuis macOS 26, le système dessine lui-même la tuile arrondie, son fond et son matériau :
// on ne lui fournit plus une image finie mais un calque sur fond transparent. La géométrie est
// celle de `tools/AppIcon.swift`, remise à l'échelle — la tuile qui y occupait 82,4 % du canevas
// occupe ici tout le canevas.

let side: CGFloat = 1024
let u = side / 168                            // une unité de la maquette

let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return true }
    let centre = CGPoint(x: side / 2, y: side / 2)

    let blue = NSColor(srgbRed: 0x00 / 255, green: 0xA3 / 255, blue: 0xE4 / 255, alpha: 1).cgColor
    let light = NSColor(srgbRed: 0xA9 / 255, green: 0xDC / 255, blue: 0xF5 / 255, alpha: 1).cgColor

    // L'anneau : diamètre 90/168, épaisseur 11/168.
    let ringDiameter = 90 * u
    let thickness = 11 * u
    let ring = CGRect(x: centre.x - ringDiameter / 2, y: centre.y - ringDiameter / 2,
                      width: ringDiameter, height: ringDiameter)
    ctx.setStrokeColor(blue)
    ctx.setLineWidth(thickness)
    ctx.strokeEllipse(in: ring.insetBy(dx: thickness / 2, dy: thickness / 2))

    // La flèche d'import : hampe à sommet arrondi, puis tête triangulaire, vers le bas.
    let shaftW = 10 * u, shaftH = 22 * u, headW = 26 * u, headH = 14 * u
    let totalH = shaftH + headH
    let top = centre.y + totalH / 2
    ctx.setFillColor(light)
    let shaft = CGRect(x: centre.x - shaftW / 2, y: top - shaftH, width: shaftW, height: shaftH)
    ctx.addPath(CGPath(roundedRect: shaft, cornerWidth: 5 * u, cornerHeight: 5 * u, transform: nil))
    ctx.addRect(CGRect(x: shaft.minX, y: shaft.minY, width: shaftW, height: shaftH / 2))
    ctx.fillPath()
    ctx.move(to: CGPoint(x: centre.x - headW / 2, y: top - shaftH))
    ctx.addLine(to: CGPoint(x: centre.x + headW / 2, y: top - shaftH))
    ctx.addLine(to: CGPoint(x: centre.x, y: top - totalH))
    ctx.closePath()
    ctx.fillPath()

    // Les perforations de pellicule, de part et d'autre.
    let p = 10 * u
    let gap = 8 * u
    let distance = ringDiameter / 2 + 10 * u + p / 2
    ctx.setFillColor(NSColor(white: 1, alpha: 0.30).cgColor)
    for sign in [-1.0, 1.0] {
        for row in -1...1 {
            let box = CGRect(x: centre.x + sign * distance - p / 2,
                             y: centre.y + CGFloat(row) * (p + gap) - p / 2,
                             width: p, height: p)
            ctx.addPath(CGPath(roundedRect: box, cornerWidth: 3 * u, cornerHeight: 3 * u,
                               transform: nil))
        }
    }
    ctx.fillPath()
    return true
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: out)
print("écrit \(out.path)")
