import AppKit
import Foundation

// Dessine l'icône de QuiX d'après le bloc 4c du handoff, à toutes les tailles demandées.
// Les proportions sont exprimées en 168e, comme la maquette, puis mises à l'échelle.
//
//   swift tools/AppIcon.swift App/Assets.xcassets/AppIcon.appiconset
//
// Un fichier par emplacement, et jamais le même deux fois : Xcode abandonne en silence les
// emplacements qui partagent une image, et l'`.icns` produit se retrouve amputé de ses grandes
// tailles — ce qui ne se voit qu'au moment où macOS affiche une notification.

func draw(side: CGFloat, perforations: Bool, perforationSide: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
        guard let ctx = NSGraphicsContext.current?.cgContext else { return true }
        let u = side / 168                     // une unité de la maquette

        // La tuile n'occupe pas tout le canevas : macOS attend une marge autour de l'icône.
        let tile = side * 0.824
        let origin = (side - tile) / 2
        let rect = CGRect(x: origin, y: origin, width: tile, height: tile)
        let radius = tile * 0.2237             // squircle façon macOS

        let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius,
                              transform: nil)
        ctx.saveGState()
        ctx.addPath(squircle)
        ctx.clip()

        // Dégradé d'encre, 160°.
        let colors = [NSColor(srgbRed: 0x22/255, green: 0x21/255, blue: 0x2A/255, alpha: 1).cgColor,
                      NSColor(srgbRed: 0x10/255, green: 0x10/255, blue: 0x17/255, alpha: 1).cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors as CFArray, locations: [0, 1])!
        let angle = 160.0 * .pi / 180
        let half = tile / 2
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        ctx.drawLinearGradient(gradient,
            start: CGPoint(x: centre.x - cos(angle) * half, y: centre.y + sin(angle) * half),
            end:   CGPoint(x: centre.x + cos(angle) * half, y: centre.y - sin(angle) * half),
            // Sans ces deux options, rien n'est peint au-delà de l'axe du dégradé : les coins
            // opposés du squircle restaient transparents.
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

        let blue = NSColor(srgbRed: 0x00/255, green: 0xA3/255, blue: 0xE4/255, alpha: 1).cgColor
        let light = NSColor(srgbRed: 0xA9/255, green: 0xDC/255, blue: 0xF5/255, alpha: 1).cgColor

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
        // Le bas de la hampe doit rester droit : on le recouvre.
        ctx.addRect(CGRect(x: shaft.minX, y: shaft.minY, width: shaftW, height: shaftH / 2))
        ctx.fillPath()
        ctx.move(to: CGPoint(x: centre.x - headW / 2, y: top - shaftH))
        ctx.addLine(to: CGPoint(x: centre.x + headW / 2, y: top - shaftH))
        ctx.addLine(to: CGPoint(x: centre.x, y: top - totalH))
        ctx.closePath()
        ctx.fillPath()

        // Les perforations de pellicule, de part et d'autre.
        if perforations {
            let p = perforationSide * u
            let gap = 8 * u
            let distance = ringDiameter / 2 + 10 * u + p / 2
            ctx.setFillColor(NSColor(white: 1, alpha: 0.22).cgColor)
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
        }

        ctx.restoreGState()

        // Liseré interne blanc à 14 %.
        ctx.addPath(squircle)
        ctx.setStrokeColor(NSColor(white: 1, alpha: 0.14).cgColor)
        ctx.setLineWidth(max(1, side / 256))
        ctx.strokePath()
        return true
    }
    return image
}

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

// Les dix emplacements que macOS attend, chacun avec son propre fichier.
let slots: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for slot in slots {
    // Le handoff : composition complète à partir de 128, perforations réduites à 64,
    // supprimées à 32 et en dessous.
    let perforations = slot.pixels >= 64
    let perforationSide: CGFloat = slot.pixels == 64 ? 4 : 10
    let image = draw(side: slot.pixels, perforations: perforations, perforationSide: perforationSide)
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try! png.write(to: URL(fileURLWithPath: "\(out)/\(slot.name).png"))
    print("\(slot.name).png  \(Int(slot.pixels))px")
}
