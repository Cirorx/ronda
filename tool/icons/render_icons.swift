// Renders every raster app icon, launch image and favicon from Ronda's mark: five dots in a ring
// on a 24-unit grid, the drawing in tool/icons/ronda_mark.svg. From the repo root:
//
//   swift tool/icons/render_icons.swift
//
// It also writes the iOS Icon Composer logos (Logo.svg). The Android vector drawables
// (ic_launcher_foreground, ic_launcher_monochrome, ic_notification, ic_launch_image) are written
// by hand with the same circles; change them together with this file and ronda_mark.svg.
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: The mark

/// Centres of the five dots on the 24-unit grid.
let dots: [(x: CGFloat, y: CGFloat)] = [(12, 4.6), (19, 9.7), (16.3, 17.9), (7.7, 17.9), (5, 9.7)]

/// The dots thicken a little when the icon is seen small, so they don't fade at 29 px or less.
func dotRadius(forDisplaySize size: CGFloat) -> CGFloat {
  if size <= 26 { return 2.9 }
  if size <= 29 { return 2.8 }
  return 2.7
}

// MARK: Colours (packages/ronda_ui/lib/src/theme/app_colors.dart)

func rgb(_ hex: UInt32) -> CGColor {
  CGColor(
    srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
    green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255,
    alpha: 1)
}

let paper = rgb(0xFFFEFA)
let birome = rgb(0x2341C0)
let ambar = rgb(0x985E00)

// MARK: Drawing

enum Shape {
  /// Edge to edge: Android adaptive layers, maskable web icons, the Play Store, iOS fallbacks.
  case square
  /// The artboard's tile, corners at 22.5%: legacy launcher icons and web "any" icons.
  case tile
  /// Legacy round launcher icons.
  case circle
  /// No background: the mark alone.
  case none
}

struct Icon {
  var size: Int
  var shape: Shape
  var background: CGColor = birome
  var mark: CGColor = paper
  /// The share of the canvas the 24-unit grid takes, centred.
  var markScale: CGFloat = 0.66
  /// The size the icon is seen at, which picks the dot radius; defaults to [size].
  var displaySize: CGFloat? = nil
  /// The development flavor's amber band with DEV across the bottom.
  var devBand = false
}

func context(_ size: Int) -> CGContext {
  let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  // Draw top-down, as SVG does.
  ctx.translateBy(x: 0, y: CGFloat(size))
  ctx.scaleBy(x: 1, y: -1)
  ctx.setAllowsAntialiasing(true)
  ctx.setShouldAntialias(true)
  return ctx
}

func outline(_ shape: Shape, _ side: CGFloat) -> CGPath {
  let rect = CGRect(x: 0, y: 0, width: side, height: side)
  switch shape {
  case .tile:
    return CGPath(
      roundedRect: rect, cornerWidth: side * 0.225, cornerHeight: side * 0.225, transform: nil)
  case .circle: return CGPath(ellipseIn: rect, transform: nil)
  case .square, .none: return CGPath(rect: rect, transform: nil)
  }
}

func drawDev(_ ctx: CGContext, side: CGFloat) {
  let top = side * 0.78
  ctx.setFillColor(ambar)
  ctx.fill(CGRect(x: 0, y: top, width: side, height: side - top))
  let band = side - top
  let font = CTFontCreateWithName("Helvetica-Bold" as CFString, band * 0.62, nil)
  let text = NSAttributedString(
    string: "DEV",
    attributes: [
      NSAttributedString.Key(kCTFontAttributeName as String): font,
      NSAttributedString.Key(kCTForegroundColorAttributeName as String): paper,
    ])
  let line = CTLineCreateWithAttributedString(text)
  let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
  ctx.saveGState()
  // Text draws bottom-up; flip back locally.
  ctx.translateBy(x: (side - bounds.width) / 2 - bounds.minX, y: top + (band + bounds.height) / 2 + bounds.minY)
  ctx.scaleBy(x: 1, y: -1)
  ctx.textPosition = .zero
  CTLineDraw(line, ctx)
  ctx.restoreGState()
}

func render(_ icon: Icon) -> CGImage {
  let side = CGFloat(icon.size)
  let ctx = context(icon.size)
  let clip = outline(icon.shape, side)
  ctx.addPath(clip)
  ctx.clip()
  if icon.shape != .none {
    ctx.setFillColor(icon.background)
    ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
  }
  let unit = side * icon.markScale / 24
  let origin = (side - 24 * unit) / 2
  let r = dotRadius(forDisplaySize: icon.displaySize ?? side) * unit
  ctx.setFillColor(icon.mark)
  for dot in dots {
    let cx = origin + dot.x * unit
    let cy = origin + dot.y * unit
    ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
  }
  if icon.devBand { drawDev(ctx, side: side) }
  return ctx.makeImage()!
}

// MARK: Output

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
guard FileManager.default.fileExists(atPath: root.appendingPathComponent("pubspec.yaml").path)
else {
  FileHandle.standardError.write("Run from the repo root: swift tool/icons/render_icons.swift\n".data(using: .utf8)!)
  exit(1)
}

var written = 0

func write(_ image: CGImage, _ path: String) {
  let url = root.appendingPathComponent(path)
  try! FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(dest, image, nil)
  guard CGImageDestinationFinalize(dest) else { fatalError("Could not write \(path)") }
  written += 1
}

func writeText(_ text: String, _ path: String) {
  try! text.write(to: root.appendingPathComponent(path), atomically: true, encoding: .utf8)
  written += 1
}

// Android: legacy launcher icons (Android 7 and older) and the Play Store icon, per flavor.
let densities = [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]
for (flavor, dev) in [("main", false), ("development", true)] {
  let res = "android/app/src/\(flavor)"
  for (density, size) in densities {
    write(render(Icon(size: size, shape: .tile, devBand: dev)), "\(res)/res/mipmap-\(density)/ic_launcher.png")
    write(render(Icon(size: size, shape: .circle, devBand: dev)), "\(res)/res/mipmap-\(density)/ic_launcher_round.png")
  }
  write(render(Icon(size: 512, shape: .square, devBand: dev)), "\(res)/ic_launcher-playstore.png")
}

// iOS: the launch image, birome dots on the paper of LaunchScreen.storyboard (120 pt), and the
// dark one on the night paper.
let launch = "ios/Runner/Assets.xcassets/LaunchImage.imageset"
for scale in 1...3 {
  let suffix = "@\(scale)x"
  write(render(Icon(size: 120 * scale, shape: .none, mark: birome, markScale: 1)), "\(launch)/LaunchImage\(suffix).png")
  write(
    render(Icon(size: 120 * scale, shape: .none, mark: rgb(0x93A6FF), markScale: 1)),
    "\(launch)/LaunchImageDark\(suffix).png")
}

// iOS: the development icon's corner flag. Environment.png carries DEV, Flag.png the triangle
// behind it; AppIcon-dev.icon/icon.json places both in the top-right corner.
func flag(text: Bool) -> CGImage {
  let side: CGFloat = 448
  let ctx = context(448)
  if text {
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 128, nil)
    let string = NSAttributedString(
      string: "DEV",
      attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): paper,
      ])
    let line = CTLineCreateWithAttributedString(string)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    ctx.translateBy(x: side * 0.64, y: side * 0.36)
    ctx.rotate(by: .pi / 4)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = CGPoint(x: -bounds.midX, y: -bounds.midY)
    CTLineDraw(line, ctx)
  } else {
    ctx.setFillColor(ambar)
    ctx.move(to: .zero)
    ctx.addLine(to: CGPoint(x: side, y: 0))
    ctx.addLine(to: CGPoint(x: side, y: side))
    ctx.closePath()
    ctx.fillPath()
  }
  return ctx.makeImage()!
}
write(flag(text: false), "ios/Runner/AppIcons/AppIcon-dev.icon/Assets/Flag.png")
write(flag(text: true), "ios/Runner/AppIcons/AppIcon-dev.icon/Assets/Environment.png")

// iOS: the Icon Composer logo, the 24-unit grid at 66% of the 1024 pt canvas. icon.json gives
// it the birome background and the dark and tinted colours.
let circles = dots.map { String(format: "<circle cx=\"%g\" cy=\"%g\" r=\"2.7\"/>", $0.x, $0.y) }.joined()
let logo = """
  <svg xmlns="http://www.w3.org/2000/svg" width="676" height="676" viewBox="0 0 24 24" fill="#FFFEFA">\(circles)</svg>

  """
for icon in ["AppIcon", "AppIcon-dev"] {
  writeText(logo, "ios/Runner/AppIcons/\(icon).icon/Assets/Logo.svg")
}

// Web: the favicon (seen at 16 px), the install icons with their own corners, maskable ones edge
// to edge (the mark sits well inside the 80% safe circle), and the iOS home-screen icon, which
// must be opaque.
let favicon = render(Icon(size: 32, shape: .tile, displaySize: 16))
let touch = render(Icon(size: 180, shape: .square))
write(favicon, "web/favicon.png")
write(render(Icon(size: 192, shape: .tile)), "web/icons/Icon-192.png")
write(render(Icon(size: 512, shape: .tile)), "web/icons/Icon-512.png")
write(render(Icon(size: 192, shape: .square)), "web/icons/Icon-maskable-192.png")
write(render(Icon(size: 512, shape: .square)), "web/icons/Icon-maskable-512.png")
write(touch, "web/icons/apple-touch-icon.png")

// Hosting: the public pages (/, /f/) outside the Flutter app.
write(favicon, "hosting/assets/favicon.png")
write(touch, "hosting/assets/apple-touch-icon.png")

print("Wrote \(written) files.")
