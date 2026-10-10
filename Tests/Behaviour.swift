
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let test = AppDelegate()
for count in [0, 1, 6, 10] {
    test.apps = Array(repeating: "/System/Applications/Calculator.app", count: count)
    test.expanded = true; test.rebuild()
    assert(test.iconPanels.count == count)
    let centre = test.panels[0].contentView as! BubbleView
    for (dx,dy): (CGFloat,CGFloat) in [(13.5,7.25),(-500,-400),(21,-3)] {
        centre.move?(dx,dy)
        let before = test.panels.map { $0.frame }
        centre.finishMove?()
        assert(test.panels.map { $0.frame } == before, "Release moved a window")
    }
    test.toggle(); test.reducedMotion = false
    test.advanceAnimation(at: test.animationBegan + 0.1)
    if count > 1 { assert(test.iconProgress.first! > test.iconProgress.last!) }
    test.advanceAnimation(at: test.animationBegan + 2)
    assert(test.iconPanels.allSatisfy { !$0.isVisible && $0.ignoresMouseEvents })
    test.toggle(); test.reducedMotion = false
    test.advanceAnimation(at: test.animationBegan + 0.15)
    let intermediate = test.iconProgress
    test.toggle(); assert(test.animationStarts == intermediate)
    test.advanceAnimation(at: test.animationBegan + 2)
    test.toggle(); test.advanceAnimation(at: test.animationBegan + 2)
    assert(test.iconPanels.allSatisfy { $0.isVisible && !$0.ignoresMouseEvents })
    test.toggle(); test.reducedMotion = true
    test.advanceAnimation(at: test.animationBegan + 0.2)
    assert(test.iconProgress.allSatisfy { $0 == 0 })
    test.panels.forEach { $0.close() }
}
// Reordering keeps the dragged app's panel/action identity and persists its order.
test.apps = ["/A.app", "/B.app", "/C.app", "/D.app"]
test.expanded = true; test.rebuild()
let originalPanels = test.iconPanels
let originalAnchor = test.anchor
func dragToSlot(_ path: String, _ slot: Int) {
    let angle = test.appAngle(slot)
    test.reorderApp(path, toward: NSPoint(x:test.anchor.x+82*cos(angle), y:test.anchor.y+82*sin(angle)))
}
dragToSlot("/A.app", 2)
assert(test.apps == ["/B.app", "/C.app", "/A.app", "/D.app"])
assert(test.iconPanels[2] === originalPanels[0])
assert(test.anchor == originalAnchor)
test.finishReordering()
assert(test.defaults.stringArray(forKey:"apps") == test.apps)
assert(test.draggingApp == nil)
dragToSlot("/D.app", 0); test.finishReordering()
assert(test.apps == ["/D.app", "/B.app", "/C.app", "/A.app"])
test.toggle(); test.advanceAnimation(at:test.animationBegan+2)
test.toggle(); test.advanceAnimation(at:test.animationBegan+2)
assert(test.apps == ["/D.app", "/B.app", "/C.app", "/A.app"])
test.rebuild()
assert(test.apps == test.defaults.stringArray(forKey:"apps"))
test.apps = ["/A.app"]; test.rebuild(); dragToSlot("/A.app",0); test.finishReordering()
assert(test.apps == ["/A.app"])
test.panels.forEach { $0.close() }
assert(BubbleView.coreArtwork != nil, "Artwork resource missing")
assert(BubbleView.glassBase != nil, "Core Image setup failed")
let menuTitles = test.makeMenu().items.map { $0.title }.joined(separator: " ").lowercased()
assert(!menuTitles.contains("alert") && !menuTitles.contains("notification"))
let image = NSImage(size: NSSize(width: 480, height: 320))
image.lockFocus()
NSColor(calibratedRed:0.94,green:0.96,blue:0.99,alpha:1).setFill()
NSRect(x:0,y:0,width:480,height:320).fill()
func drawPreview(_ view: BubbleView, _ center: NSPoint) {
    NSGraphicsContext.saveGraphicsState()
    let tr = NSAffineTransform(); tr.translateX(by:center.x-view.bounds.width/2,yBy:center.y-view.bounds.height/2);tr.concat()
    view.draw(view.bounds); NSGraphicsContext.restoreGraphicsState()
}
let core = BubbleView(label:"My AI Bubble",size:96);core.previewTime=0
drawPreview(core,NSPoint(x:240,y:160))
let names = ["ChatGPT", "Claude", "Granola", "Perplexity", "superwhisper", "Muse"]
for (index,name) in names.enumerated() {
    let path = "/Applications/\(name).app"
    guard FileManager.default.fileExists(atPath:path) else { continue }
    let view = BubbleView(label:name,icon:NSWorkspace.shared.icon(forFile:path),size:54)
    let angle = CGFloat.pi/2-CGFloat(index)*2*CGFloat.pi/6
    drawPreview(view,NSPoint(x:240+82*cos(angle),y:160+82*sin(angle)))
}
image.unlockFocus()
try NSBitmapImageRep(data:image.tiffRepresentation!)!.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
test.defaults.removePersistentDomain(forName:"local.myaibubble.behaviour-tests")
print("PASS: 0/1/6/10 apps; exact drag release; staggered folding; rapid reversal; hidden click targets; Reduce Motion; artwork; no alert controls")
