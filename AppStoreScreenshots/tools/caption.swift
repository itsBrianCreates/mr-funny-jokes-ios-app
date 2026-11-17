import AppKit

// caption.swift <in.png> <out.png> <caption>
let a = CommandLine.arguments
let src = NSImage(contentsOfFile: a[1])!
let rep0 = src.representations[0]
let W = rep0.pixelsWide, H = rep0.pixelsHigh
let caption = a[3]

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let w = CGFloat(W), h = CGFloat(H)
let landscape = W > H

// Brand yellow background, lighter toward the bottom
NSGradient(colors: [NSColor(srgbRed: 1.0, green: 0.882, blue: 0.208, alpha: 1),
                    NSColor(srgbRed: 1.0, green: 0.93, blue: 0.55, alpha: 1)])!
    .draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -90)

// Caption
let fontSize: CGFloat = landscape ? 128 : 104
let base = NSFont.systemFont(ofSize: fontSize, weight: .heavy)
let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: fontSize) } ?? base
let para = NSMutableParagraphStyle(); para.alignment = .center; para.lineHeightMultiple = 0.95
let attrs: [NSAttributedString.Key: Any] = [
    .font: font, .paragraphStyle: para,
    .foregroundColor: NSColor(srgbRed: 0.11, green: 0.11, blue: 0.12, alpha: 1)
]
let text = NSAttributedString(string: caption, attributes: attrs)
let margin: CGFloat = landscape ? 160 : 90
let textBox = text.boundingRect(with: NSSize(width: w - margin * 2, height: 2000), options: [.usesLineFragmentOrigin])
let band: CGFloat = landscape ? 330 : 400       // space reserved for the caption
let textY = h - band / 2 - textBox.height / 2 - (landscape ? 0 : 10)
text.draw(with: NSRect(x: margin, y: textY, width: w - margin * 2, height: textBox.height), options: [.usesLineFragmentOrigin])

// Screenshot: scaled to fit under the caption, rounded, with a soft shadow
let bottomPad: CGFloat = landscape ? 90 : 70
let availH = h - band - bottomPad
let scale = min(availH / h, (w - margin * 2) / w)
let sw = w * scale, sh = h * scale
let rect = NSRect(x: (w - sw) / 2, y: bottomPad + (availH - sh) / 2, width: sw, height: sh)
let radius: CGFloat = 70 * scale * (landscape ? 1.6 : 1.3)
let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
shadow.shadowBlurRadius = 60; shadow.shadowOffset = NSSize(width: 0, height: -24); shadow.set()
NSColor.white.setFill(); path.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
path.addClip()
NSGraphicsContext.current!.imageInterpolation = .high
src.draw(in: rect, from: NSRect(x: 0, y: 0, width: src.size.width, height: src.size.height), operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

NSColor.black.withAlphaComponent(0.12).setStroke(); path.lineWidth = 3; path.stroke()

NSGraphicsContext.current!.flushGraphics()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
