import Cocoa
import CoreImage
import UniformTypeIdentifiers

final class BubblePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
final class BubbleView: NSView {
    let label: String
    let icon: NSImage?
    var isAddButton = false
    static let coreArtwork: NSImage? = {
        guard let path = Bundle.main.path(forResource: "BubbleArtwork", ofType: "png") else { return nil }
        return NSImage(contentsOfFile: path)
    }()
    // Draw and sample the same resolved icon representation. Native icon bundles
    // can use different artwork/colours at different sizes.
    lazy var resolvedIcon: NSImage? = {
        guard let icon = icon,
              let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return icon }
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        icon.draw(in: NSRect(x: 0, y: 0, width: 256, height: 256))
        NSGraphicsContext.restoreGraphicsState()
        let samples = [(64,64), (192,64), (64,192), (192,192)].compactMap { bitmap.colorAt(x: $0.0, y: $0.1)?.usingColorSpace(.deviceRGB) }
        if samples.count == 4 {
            let r = samples.reduce(CGFloat(0)) { $0+$1.redComponent }/4
            let g = samples.reduce(CGFloat(0)) { $0+$1.greenComponent }/4
            let b = samples.reduce(CGFloat(0)) { $0+$1.blueComponent }/4
            let fill = NSColor(deviceRed: r, green: g, blue: b, alpha: 1)
            // Remove only low-contrast tile shading; retain the contrasting logo.
            for y in 32..<224 { for x in 32..<224 {
                guard let pixel = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), pixel.alphaComponent > 0.98 else { continue }
                let distance = pow(pixel.redComponent-r,2)+pow(pixel.greenComponent-g,2)+pow(pixel.blueComponent-b,2)
                let colouredBackground = max(r,g,b)-min(r,g,b) > 0.12
                let paleBackground = min(r,g,b) > 0.80
                let palePixel = min(pixel.redComponent, pixel.greenComponent, pixel.blueComponent) > 0.80
                if (colouredBackground && distance < 0.012) || (paleBackground && palePixel && distance < 0.045) {
                    bitmap.setColor(fill, atX: x, y: y)
                }
            } }
        }
        let image = NSImage(size: NSSize(width: 256, height: 256)); image.addRepresentation(bitmap)
        return image
    }()
    lazy var iconBackground: NSColor = {
        guard let bitmap = resolvedIcon?.representations.first as? NSBitmapImageRep else { return .white }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        let points = [(64,64), (192,64), (64,192), (192,192)]
        for (x,y) in points {
            let colour = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) ?? .white
            red += colour.redComponent; green += colour.greenComponent; blue += colour.blueComponent
        }
        return NSColor(deviceRed: red/4, green: green/4, blue: blue/4, alpha: 1)
    }()
    var reveal: CGFloat = 1 { didSet { needsDisplay = true } }
    var hovered = false
    var hoverArea: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = hoverArea { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area); hoverArea = area
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }
    var action: (() -> Void)?
    var move: ((CGFloat, CGFloat) -> Void)?
    var finishMove: (() -> Void)?
    var context: (() -> NSMenu)?
    var lastPoint = NSPoint.zero
    var dragged = false
    init(label: String, icon: NSImage? = nil, size: CGFloat) {
        self.label = label; self.icon = icon
        super.init(frame: NSRect(x: 0, y: 0, width: size + (icon == nil ? 0 : 16), height: size + (icon == nil ? 0 : 16)))
        toolTip = icon == nil ? "Drag to move • Click to fold • Right-click for options" : label
        setAccessibilityElement(true)
        setAccessibilityLabel(label)
        setAccessibilityRole(.button)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let scale: CGFloat = icon == nil ? (hovered ? 1.025 : 1) : (0.35 + 0.65 * reveal) * (hovered ? 1.06 : 1)
        let transform = NSAffineTransform()
        transform.translateX(by: bounds.midX, yBy: bounds.midY)
        transform.scale(by: scale)
        transform.translateX(by: -bounds.midX, yBy: -bounds.midY); transform.concat()
        if isAddButton {
            let circle = NSBezierPath(ovalIn: bounds.insetBy(dx:12,dy:12))
            drawSoftShadow(under:circle,blur:5,offset:-1.5)
            NSColor(calibratedWhite:0.97,alpha:1).setFill();circle.fill()
            let plus = NSBezierPath()
            plus.move(to:NSPoint(x:bounds.midX-7,y:bounds.midY));plus.line(to:NSPoint(x:bounds.midX+7,y:bounds.midY))
            plus.move(to:NSPoint(x:bounds.midX,y:bounds.midY-7));plus.line(to:NSPoint(x:bounds.midX,y:bounds.midY+7))
            NSColor(calibratedRed:0.26,green:0.32,blue:0.44,alpha:1).setStroke()
            plus.lineWidth=2.2;plus.lineCapStyle = .round;plus.stroke()
        } else if let icon = resolvedIcon {
            let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 12, dy: 12))
            drawSoftShadow(under: circle, blur: 5, offset: -1.5)
            NSGraphicsContext.saveGraphicsState()
            circle.addClip()
            iconBackground.setFill(); circle.fill()
            let logoBounds = bounds.insetBy(dx: 17, dy: 17)
            NSBezierPath(ovalIn: logoBounds).addClip()
            // Crop the native icon's outer padding and rounded tile edges.
            let source = NSRect(x: icon.size.width * 0.13, y: icon.size.height * 0.13, width: icon.size.width * 0.74, height: icon.size.height * 0.74)
            icon.draw(in: logoBounds, from: source, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            drawCore()
        }
    }
    func drawSoftShadow(under shape: NSBezierPath, blur: CGFloat, offset: CGFloat) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        NSGraphicsContext.saveGraphicsState()
        // Paint only a diffuse shadow. No opaque duplicate under the antialiased edge.
        let shift: CGFloat = 10000
        let displaced = shape.copy() as! NSBezierPath
        let transform = NSAffineTransform(); transform.translateX(by: shift, yBy: 0)
        displaced.transform(using: transform as AffineTransform)
        context.setShadow(offset: CGSize(width: -shift, height: offset), blur: blur,
                          color: NSColor.black.withAlphaComponent(0.10).cgColor)
        NSColor.black.setFill(); displaced.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
    private var lightTimer: Timer?
    private let lightEpoch = ProcessInfo.processInfo.systemUptime
    var previewTime: Double?
    static let glassContext = CIContext(options: [.cacheIntermediates: false])
    static let glassBase: CIImage? = {
        guard let artwork = coreArtwork else { return nil }
        let image = NSImage(size: NSSize(width: 144, height: 144))
        image.lockFocus()
        let source = NSRect(x: artwork.size.width * 372/1200, y: artwork.size.height * 91/630,
                            width: artwork.size.width * 456/1200, height: artwork.size.height * 448/630)
        artwork.draw(in: NSRect(x: 0, y: 0, width: 144, height: 144), from: source, operation: .sourceOver, fraction: 1)
        image.unlockFocus()
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let input = CIImage(cgImage: cg)
        return input.transformed(by: CGAffineTransform(scaleX: 144/input.extent.width, y: 144/input.extent.height))
    }()
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        lightTimer?.invalidate(); lightTimer = nil
        guard icon == nil, window != nil else { return }
        let timer = Timer(timeInterval: 1.0/24, repeats: true) { [weak self] _ in
            guard let self = self, self.window?.isVisible == true else { return }
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { self.needsDisplay = true }
        }
        lightTimer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    deinit { lightTimer?.invalidate() }
    func drawCore() {
        guard let base = Self.glassBase else { return }
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let t = previewTime ?? (reduced ? 0 : ProcessInfo.processInfo.systemUptime-lightEpoch)
        // Distort only the inner glass. The outer silhouette, size and position stay fixed.
        var glass = base
        if !reduced || previewTime != nil {
            glass = glass.applyingFilter("CIBumpDistortion", parameters: [
                kCIInputCenterKey: CIVector(x: 72+16*sin(t*0.29), y: 72+14*cos(t*0.23)),
                kCIInputRadiusKey: 46, kCIInputScaleKey: 0.10*sin(t*0.41)])
            glass = glass.applyingFilter("CITwirlDistortion", parameters: [
                kCIInputCenterKey: CIVector(x: 72, y: 72), kCIInputRadiusKey: 62,
                kCIInputAngleKey: 0.13*sin(t*0.31)])
            glass = glass.applyingFilter("CIHueAdjust", parameters: [kCIInputAngleKey: 0.09*sin(t*0.19)])
        }
        let destination = bounds.insetBy(dx: 12, dy: 12)
        drawSoftShadow(under: NSBezierPath(ovalIn: destination), blur: 9, offset: -2.5)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSBezierPath(ovalIn: destination).addClip()
        let opaqueGlass = glass.composited(over: CIImage(color: CIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)))
        if let frame = Self.glassContext.createCGImage(opaqueGlass, from: CGRect(x:0,y:0,width:144,height:144)) {
            NSImage(cgImage: frame, size: NSSize(width:144,height:144)).draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1)
        }
        // Broad, faint reflections drift across the artwork rather than pulsing its scale.
        if let context = NSGraphicsContext.current?.cgContext {
            context.setBlendMode(.screen)
            for (phase, tint) in [(0.0, NSColor.white), (2.4, NSColor(calibratedRed:0.50,green:0.88,blue:1,alpha:1))] {
                let x = bounds.midX + 17*sin(t*0.24+phase)
                let y = bounds.midY + 19*cos(t*0.18+phase)
                let colours = [tint.withAlphaComponent(0.13).cgColor, tint.withAlphaComponent(0).cgColor] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours, locations: [0,1]) {
                    context.drawRadialGradient(gradient, startCenter: CGPoint(x:x,y:y), startRadius:0, endCenter:CGPoint(x:x,y:y), endRadius:22, options: [])
                }
            }
        }
    }
    override func mouseDown(with event: NSEvent) { lastPoint = NSEvent.mouseLocation; dragged = false }
    override func mouseDragged(with event: NSEvent) {
        guard move != nil else { return }
        let point = NSEvent.mouseLocation
        let dx = point.x-lastPoint.x, dy = point.y-lastPoint.y
        if abs(dx)+abs(dy) > 1 { dragged = true }
        move?(dx,dy); lastPoint = point
    }
    override func mouseUp(with event: NSEvent) { if dragged { finishMove?() } else { action?() } }
    override func menu(for event: NSEvent) -> NSMenu? { context?() }
    override func accessibilityPerformPress() -> Bool { action?(); return true }
}
final class AppDelegate: NSObject, NSApplicationDelegate {
    var panels: [BubblePanel] = []
    var apps: [String] = []
    var anchor = NSPoint(x: 160, y: 350)
    var expanded = true
    var iconPanels: [BubblePanel] = []
    var addPanel: BubblePanel?
    var orbitRadius: CGFloat { max(82, CGFloat(apps.count+1)*8.5) }
    func appAngle(_ index: Int) -> CGFloat { -.pi/2 + CGFloat(index+1)*2 * .pi/CGFloat(apps.count+1) }
    var iconProgress: [CGFloat] = []
    var animation: Timer?
    var animationStarts: [CGFloat] = []
    var animationBegan: TimeInterval = 0
    var reducedMotion = false
    var status: NSStatusItem!
    var appViews: [String: BubbleView] = [:]
    let defaults = UserDefaults.standard
    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.removeObject(forKey: "dockAlerts")
        let names = ["ChatGPT", "Claude", "Granola", "Perplexity", "ChatGPT Atlas", "superwhisper"]
        let roots = [URL(fileURLWithPath: "/Applications"), FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        let initial = names.compactMap { name in
            roots.map { $0.appendingPathComponent(name + ".app").path }.first { FileManager.default.fileExists(atPath: $0) }
        }
        apps = (defaults.stringArray(forKey: "apps") ?? initial).filter { FileManager.default.fileExists(atPath: $0) }
        if defaults.object(forKey: "x") != nil { anchor = NSPoint(x: defaults.double(forKey: "x"), y: defaults.double(forKey: "y")) }
        clamp(); rebuild()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = "◎"
        status.button?.toolTip = "My AI Bubble"
        status.menu = makeMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    func clamp() {
        let screen = NSScreen.screens.first { $0.visibleFrame.contains(anchor) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let margin: CGFloat = orbitRadius + 35
        anchor.x = max(frame.minX+margin, min(anchor.x, frame.maxX-margin))
        anchor.y = max(frame.minY+margin, min(anchor.y, frame.maxY-margin))
    }
    func save() { defaults.set(anchor.x, forKey: "x"); defaults.set(anchor.y, forKey: "y"); defaults.set(apps, forKey: "apps") }
    func panel(view: BubbleView, centre: NSPoint) -> BubblePanel {
        let size = view.frame.width
        let panel = BubblePanel(contentRect: NSRect(x: centre.x-size/2, y: centre.y-size/2, width: size, height: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .floating; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false; panel.contentView = view
        panel.orderFrontRegardless(); return panel
    }
    func rebuild() {
        animation?.invalidate(); animation = nil
        panels.forEach { $0.close() }; panels.removeAll(); appViews.removeAll(); iconPanels.removeAll()
        iconProgress = Array(repeating: expanded ? 1 : 0, count: apps.count)
        let centre = BubbleView(label: "My AI Bubble", size: 96)
        centre.action = { [weak self] in self?.toggle() }
        centre.move = { [weak self] dx,dy in
            guard let self = self else { return }
            self.anchor.x += dx; self.anchor.y += dy
            for panel in self.panels { panel.setFrameOrigin(NSPoint(x: panel.frame.minX+dx, y: panel.frame.minY+dy)) }
        }
        centre.finishMove = { [weak self] in
            guard let self = self, let core = self.panels.first else { return }
            // Persist the actual dropped position without clamping or relaying out windows.
            self.anchor = NSPoint(x: core.frame.midX, y: core.frame.midY)
            self.save()
        }
        centre.context = { [weak self] in self?.makeMenu() ?? NSMenu() }
        panels.append(panel(view: centre, centre: anchor))
        do {
            for (index,path) in apps.enumerated() {
                let angle = appAngle(index)
                let point = NSPoint(x: anchor.x+orbitRadius*cos(angle), y: anchor.y+orbitRadius*sin(angle))
                let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                let view = BubbleView(label: name, icon: NSWorkspace.shared.icon(forFile: path), size: 54)
                view.action = { [weak self] in self?.launch(path) }
                appViews[path] = view
                let satellite = panel(view: view, centre: point)
                panels.append(satellite); iconPanels.append(satellite)
            }
        }
        let addView = BubbleView(label: "Add an AI app", icon: NSImage(size: NSSize(width:32,height:32)), size:54)
        addView.isAddButton = true
        addView.action = { [weak self] in self?.addApp() }
        let add = panel(view:addView,centre:NSPoint(x:anchor.x,y:anchor.y-orbitRadius))
        addPanel = add;panels.append(add)
        layoutIcons()
        panels.first?.orderFrontRegardless()
        status?.menu = makeMenu()
    }
    func layoutIcons() {
        panels.first?.setFrameOrigin(NSPoint(x: anchor.x-48, y: anchor.y-48))
        if let add = addPanel {
            add.setFrameOrigin(NSPoint(x:anchor.x-add.frame.width/2,y:anchor.y-orbitRadius-add.frame.height/2))
        }
        for (index, panel) in iconPanels.enumerated() {
            let progress = iconProgress[index]
            let angle = appAngle(index)
            let distance: CGFloat = reducedMotion ? orbitRadius : orbitRadius * progress
            panel.setFrameOrigin(NSPoint(x: anchor.x+distance*cos(angle)-panel.frame.width/2, y: anchor.y+distance*sin(angle)-panel.frame.height/2))
            panel.alphaValue = progress
            panel.ignoresMouseEvents = progress < 0.98
            (panel.contentView as? BubbleView)?.reveal = reducedMotion ? 1 : progress
            if progress < 0.001 { panel.orderOut(nil) }
            else if !panel.isVisible {
                panel.orderFrontRegardless()
                if let core = panels.first { panel.order(.below, relativeTo: core.windowNumber) }
            }
        }
    }
    func advanceAnimation(at now: TimeInterval) {
        let elapsed = now-animationBegan
        var complete = true
        for index in iconProgress.indices {
            let rank = expanded ? index : iconProgress.count-1-index
            let delay = reducedMotion ? 0 : Double(rank) * 0.055
            let duration = reducedMotion ? 0.12 : 0.32
            let t = max(0, min(1, (elapsed-delay)/duration))
            let eased = CGFloat(t*t*(3-2*t))
            let target: CGFloat = expanded ? 1 : 0
            iconProgress[index] = animationStarts[index] + (target-animationStarts[index])*eased
            if t < 1 { complete = false }
        }
        layoutIcons()
        if complete { animation?.invalidate(); animation = nil }
    }
    func launch(_ path: String) {
        let config = NSWorkspace.OpenConfiguration(); config.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: config) { _,error in
            if let error = error { DispatchQueue.main.async { let alert = NSAlert(); alert.messageText = "Couldn’t open this app"; alert.informativeText = error.localizedDescription; alert.runModal() } }
        }
    }
    func item(_ title: String, _ action: Selector, in menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item); return item
    }
    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        _ = item(expanded ? "Hide app bubbles" : "Show app bubbles", #selector(toggle), in: menu)
        _ = item("Bring bubble into view", #selector(resetPosition), in: menu)
        menu.addItem(.separator())
        let add = item("Add an AI app…", #selector(addApp), in: menu); add.isEnabled = apps.count < 10
        let remove = NSMenuItem(title: "Remove an AI app", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for (index,path) in apps.enumerated() { let entry = item(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent, #selector(removeApp(_:)), in: submenu); entry.tag = index }
        remove.submenu = submenu; menu.addItem(remove)
        menu.addItem(.separator()); _ = item("Quit My AI Bubble", #selector(quit), in: menu)
        return menu
    }
    @objc func toggle() {
        animation?.invalidate()
        expanded.toggle()
        reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        clamp(); save()
        animationStarts = iconProgress
        animationBegan = ProcessInfo.processInfo.systemUptime
        // Reversals begin from the current positions, including during a stagger.
        let timer = Timer(timeInterval: 1.0/60, repeats: true) { [weak self] _ in
            self?.advanceAnimation(at: ProcessInfo.processInfo.systemUptime)
        }
        animation = timer; RunLoop.main.add(timer, forMode: .common)
        status?.menu = makeMenu()
    }
    @objc func screenChanged() { clamp(); rebuild(); save() }
    @objc func resetPosition() { if let frame = NSScreen.main?.visibleFrame { anchor = NSPoint(x: frame.minX+155, y: frame.midY) }; clamp(); rebuild(); save() }
    @objc func addApp() {
        guard apps.count < 10 else {
            let alert = NSAlert();alert.messageText="You have ten app bubbles"
            alert.informativeText="Remove an AI app from the centre bubble’s right-click menu to make room for another."
            NSApp.activate(ignoringOtherApps:true);alert.runModal();return
        }
        let picker = NSOpenPanel(); picker.title = "Choose an AI app for My AI Bubble"; picker.directoryURL = URL(fileURLWithPath: "/Applications")
        picker.allowedContentTypes = [.applicationBundle]; picker.allowsMultipleSelection = false; picker.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        if picker.runModal() == .OK, let url = picker.url, !apps.contains(url.path), apps.count < 10 { apps.append(url.path); expanded = true; clamp(); save(); rebuild() }
    }
    @objc func removeApp(_ sender: NSMenuItem) { apps.remove(at: sender.tag); save(); rebuild() }
    @objc func quit() { NSApp.terminate(nil) }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
