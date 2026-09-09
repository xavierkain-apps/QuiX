import AppKit

/// Le glyphe de la barre de menus : l'anneau et la flèche de l'icône, sans les perforations.
///
/// Dessiné en code plutôt qu'importé : c'est une forme de dix lignes, et une image de plus dans le
/// dépôt serait une image de plus à régénérer au premier changement de proportion. Marqué
/// `template` pour que macOS l'inverse selon le thème de la barre.
enum MenuBarIcon {

    static let image: NSImage = {
        let side: CGFloat = 18
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return true }
            context.setFillColor(NSColor.black.cgColor)
            context.setStrokeColor(NSColor.black.cgColor)

            // L'anneau, aux proportions de l'icône : diamètre 90/168, épaisseur 11/168.
            let thickness = side * 11 / 168 * 1.6
            let diameter = side * 90 / 168 * 1.55
            let ring = CGRect(x: (side - diameter) / 2, y: (side - diameter) / 2,
                              width: diameter, height: diameter)
            context.setLineWidth(thickness)
            context.strokeEllipse(in: ring.insetBy(dx: thickness / 2, dy: thickness / 2))

            // La flèche : hampe puis tête, pointant vers le bas.
            let shaftWidth = diameter * 10 / 90
            let shaftHeight = diameter * 22 / 90
            let headWidth = diameter * 26 / 90
            let headHeight = diameter * 14 / 90
            let centre = CGPoint(x: side / 2, y: side / 2)
            let top = centre.y + (shaftHeight + headHeight) / 2

            context.fill(CGRect(x: centre.x - shaftWidth / 2, y: top - shaftHeight,
                                width: shaftWidth, height: shaftHeight))
            context.move(to: CGPoint(x: centre.x - headWidth / 2, y: top - shaftHeight))
            context.addLine(to: CGPoint(x: centre.x + headWidth / 2, y: top - shaftHeight))
            context.addLine(to: CGPoint(x: centre.x, y: top - shaftHeight - headHeight))
            context.closePath()
            context.fillPath()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
