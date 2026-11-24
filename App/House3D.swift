import SwiftUI
import SceneKit
import UIKit

/// La petite maison de DUO, en vraie 3D (SceneKit) : 4 pièces meublées, vue en maquette sans toit.
/// Une bulle lumineuse flotte au-dessus des pièces qui ont des tâches ; on touche une pièce pour l'ouvrir.
struct House3DView: UIViewRepresentable {
    var counts: [Int]
    var selected: Int?
    var interactive = false
    var onTap: (Int) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.rendersContinuously = false
        let scene = HouseScene.make(reduceMotion: UIAccessibility.isReduceMotionEnabled)
        view.scene = scene
        view.pointOfView = scene.rootNode.childNode(withName: "camera", recursively: false)
        view.allowsCameraControl = interactive
        if interactive {
            view.defaultCameraController.interactionMode = .orbitTurntable
            view.defaultCameraController.inertiaEnabled = true
            view.defaultCameraController.maximumVerticalAngle = 20
            view.defaultCameraController.minimumVerticalAngle = -8
            view.defaultCameraController.target = SCNVector3(0, 0.3, 0)
        }
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        view.addGestureRecognizer(tap)
        context.coordinator.view = view
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Maquette 3D de la maison"
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.onTap = onTap
        if let scene = view.scene { HouseScene.update(scene, counts: counts, selected: selected) }
        view.accessibilityValue = HouseScene.rooms.enumerated().map { "\($0.element.name) \(counts.indices.contains($0.offset) ? counts[$0.offset] : 0) tâche(s)" }.joined(separator: ", ")
    }

    final class Coordinator: NSObject {
        weak var view: SCNView?
        var onTap: (Int) -> Void = { _ in }
        @objc func tapped(_ g: UITapGestureRecognizer) {
            guard let view else { return }
            let hits = view.hitTest(g.location(in: view), options: [SCNHitTestOption.searchMode: SCNHitTestSearchMode.closest.rawValue])
            for hit in hits {
                var node: SCNNode? = hit.node
                while let n = node {
                    if let name = n.name, name.hasPrefix("room-"), let i = Int(name.dropFirst(5)) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onTap(i); return
                    }
                    node = n.parent
                }
            }
        }
    }
}

enum HouseScene {
    struct Room { let name: String; let color: UIColor; let x: Float; let z: Float }
    // Ordre identique à HouseV2.rooms : Cuisine, Salon, Chambre, Salle de bain.
    static let rooms: [Room] = [
        Room(name: "Cuisine", color: UIColor(red: 1.00, green: 0.89, blue: 0.66, alpha: 1), x: -0.82, z: -0.62),
        Room(name: "Salon", color: UIColor(red: 0.78, green: 0.71, blue: 1.00, alpha: 1), x: 0.82, z: -0.62),
        Room(name: "Chambre", color: UIColor(red: 0.97, green: 0.78, blue: 0.85, alpha: 1), x: -0.82, z: 0.62),
        Room(name: "Salle de bain", color: UIColor(red: 0.75, green: 0.84, blue: 1.00, alpha: 1), x: 0.82, z: 0.62)
    ]

    static func mat(_ c: UIColor, rough: CGFloat = 0.75, metal: CGFloat = 0, emit: UIColor? = nil) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = c
        m.roughness.contents = rough
        m.metalness.contents = metal
        if let emit { m.emission.contents = emit }
        return m
    }
    static func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ c: UIColor, r: CGFloat = 0.02, rough: CGFloat = 0.75) -> SCNNode {
        let g = SCNBox(width: w, height: h, length: l, chamferRadius: r)
        g.materials = [mat(c, rough: rough)]
        let n = SCNNode(geometry: g); n.castsShadow = true
        return n
    }
    static func put(_ n: SCNNode, _ x: Float, _ y: Float, _ z: Float, in parent: SCNNode) { n.position = SCNVector3(x, y, z); parent.addChildNode(n) }

    static let white = UIColor(red: 0.96, green: 0.95, blue: 0.98, alpha: 1)
    static let wall = UIColor(red: 0.93, green: 0.91, blue: 0.97, alpha: 1)
    static let wood = UIColor(red: 0.78, green: 0.62, blue: 0.48, alpha: 1)
    static let ink = UIColor(red: 0.16, green: 0.14, blue: 0.22, alpha: 1)

    static func make(reduceMotion: Bool) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        let root = scene.rootNode

        // Caméra
        let cam = SCNNode(); cam.name = "camera"
        cam.camera = SCNCamera(); cam.camera?.fieldOfView = 32; cam.camera?.zNear = 0.1; cam.camera?.zFar = 60
        cam.camera?.wantsHDR = true; cam.camera?.bloomIntensity = 0.6; cam.camera?.bloomThreshold = 0.8; cam.camera?.bloomBlurRadius = 10
        cam.camera?.vignettingIntensity = 0.25; cam.camera?.vignettingPower = 0.6
        cam.position = SCNVector3(0, 5.0, 6.6)
        cam.look(at: SCNVector3(0, 0.15, 0))
        root.addChildNode(cam)

        // Lumières
        let key = SCNNode(); key.light = SCNLight(); key.light?.type = .directional; key.light?.intensity = 1150
        key.light?.color = UIColor(red: 1, green: 0.95, blue: 0.9, alpha: 1)
        key.light?.castsShadow = true; key.light?.shadowMode = .deferred; key.light?.shadowRadius = 10; key.light?.shadowSampleCount = 16
        key.light?.shadowColor = UIColor(white: 0, alpha: 0.45); key.light?.orthographicScale = 5
        key.eulerAngles = SCNVector3(-Float.pi / 3.1, -Float.pi / 5, 0)
        root.addChildNode(key)
        let fill = SCNNode(); fill.light = SCNLight(); fill.light?.type = .ambient; fill.light?.intensity = 420
        fill.light?.color = UIColor(red: 0.72, green: 0.66, blue: 0.95, alpha: 1)
        root.addChildNode(fill)
        let rim = SCNNode(); rim.light = SCNLight(); rim.light?.type = .omni; rim.light?.intensity = 900
        rim.light?.color = UIColor(red: 1, green: 0.78, blue: 0.66, alpha: 1); rim.light?.attenuationEndDistance = 9
        rim.position = SCNVector3(-3, 2.2, -2.5); root.addChildNode(rim)

        // Île flottante
        let island = SCNNode(); island.name = "island"; root.addChildNode(island)
        let soil = SCNCone(topRadius: 2.55, bottomRadius: 0.35, height: 1.5)
        soil.materials = [mat(UIColor(red: 0.27, green: 0.22, blue: 0.36, alpha: 1), rough: 0.95)]
        put(SCNNode(geometry: soil), 0, -0.86, 0, in: island)
        let grass = SCNCylinder(radius: 2.6, height: 0.16)
        grass.materials = [mat(UIColor(red: 0.55, green: 0.80, blue: 0.68, alpha: 1), rough: 0.9)]
        let grassNode = SCNNode(geometry: grass); grassNode.castsShadow = false
        put(grassNode, 0, -0.06, 0, in: island)

        // Dalle de la maison
        put(box(3.5, 0.12, 2.7, wall, r: 0.04), 0, 0.06, 0, in: island)

        // Pièces : sol coloré (zone touchable) + meubles
        for (i, r) in rooms.enumerated() {
            let room = SCNNode(); room.name = "room-\(i)"
            put(room, r.x, 0.12, r.z, in: island)
            let floor = box(1.56, 0.04, 1.14, r.color.withAlphaComponent(1), r: 0.01, rough: 0.6)
            floor.name = "floor"; floor.castsShadow = false
            put(floor, 0, 0.02, 0, in: room)
            switch i {
            case 0: kitchen(room)
            case 1: living(room)
            case 2: bedroom(room)
            default: bathroom(room)
            }
            // Bulle des tâches
            let orb = SCNNode(geometry: SCNSphere(radius: 0.13)); orb.name = "orb"
            orb.geometry?.materials = [mat(r.color, rough: 0.2, emit: r.color)]
            orb.position = SCNVector3(0, 1.05, 0); orb.opacity = 0; orb.castsShadow = false
            if !reduceMotion {
                let up = SCNAction.moveBy(x: 0, y: 0.12, z: 0, duration: 1.4); up.timingMode = .easeInEaseOut
                orb.runAction(.repeatForever(.sequence([up, up.reversed()])))
            }
            room.addChildNode(orb)
        }

        // Murs (arrière et gauche hauts, cloisons basses : vue de maquette)
        let wt: CGFloat = 0.07
        put(box(3.5, 0.95, wt, wall), 0, 0.6, -1.32, in: island)
        put(box(wt, 0.95, 2.7, wall), -1.72, 0.6, 0, in: island)
        put(box(3.5, 0.28, wt, wall), 0, 0.27, 1.32, in: island)
        put(box(wt, 0.28, 2.7, wall), 1.72, 0.27, 0, in: island)
        put(box(wt, 0.55, 1.0, wall), 0, 0.4, -0.75, in: island)
        put(box(wt, 0.55, 1.0, wall), 0, 0.4, 0.75, in: island)
        put(box(1.1, 0.55, wt, wall), -1.15, 0.4, 0, in: island)
        put(box(1.1, 0.55, wt, wall), 1.15, 0.4, 0, in: island)
        // Fenêtres lumineuses sur le mur du fond
        for x in [-1.0, 0.7] as [Float] {
            let w = box(0.55, 0.34, 0.02, UIColor(red: 1, green: 0.86, blue: 0.6, alpha: 1), r: 0.01, rough: 0.3)
            w.geometry?.firstMaterial?.emission.contents = UIColor(red: 1, green: 0.8, blue: 0.5, alpha: 1)
            w.geometry?.firstMaterial?.emission.intensity = 0.7
            put(w, x, 0.72, -1.28, in: island)
        }

        // Arbres et lanterne
        for (x, z, s) in [(-2.15, 1.35, 1.0), (2.2, -1.25, 0.8), (2.05, 1.55, 0.65)] as [(Float, Float, Float)] {
            let t = SCNNode()
            let trunk = SCNNode(geometry: SCNCylinder(radius: 0.05, height: 0.4)); trunk.geometry?.materials = [mat(wood)]
            trunk.position = SCNVector3(0, 0.2, 0); t.addChildNode(trunk)
            let crown = SCNNode(geometry: SCNSphere(radius: 0.32)); crown.geometry?.materials = [mat(UIColor(red: 0.62, green: 0.86, blue: 0.72, alpha: 1), rough: 0.85)]
            crown.position = SCNVector3(0, 0.62, 0); crown.castsShadow = true; t.addChildNode(crown)
            t.scale = SCNVector3(s, s, s); put(t, x, 0.02, z, in: island)
        }
        let lamp = SCNNode(geometry: SCNSphere(radius: 0.07))
        lamp.geometry?.materials = [mat(UIColor(red: 1, green: 0.85, blue: 0.6, alpha: 1), emit: UIColor(red: 1, green: 0.8, blue: 0.5, alpha: 1))]
        lamp.light = SCNLight(); lamp.light?.type = .omni; lamp.light?.intensity = 300; lamp.light?.attenuationEndDistance = 2.2
        lamp.light?.color = UIColor(red: 1, green: 0.8, blue: 0.55, alpha: 1)
        put(lamp, -2.25, 0.75, -0.3, in: island)
        let post = SCNNode(geometry: SCNCylinder(radius: 0.02, height: 0.7)); post.geometry?.materials = [mat(ink)]
        put(post, -2.25, 0.36, -0.3, in: island)

        // Lucioles
        for k in 0..<10 {
            let f = SCNNode(geometry: SCNSphere(radius: 0.025))
            f.geometry?.materials = [mat(.white, emit: UIColor(red: 1, green: 0.92, blue: 0.7, alpha: 1))]
            let a = Float(k) / 10 * 2 * .pi
            f.position = SCNVector3(cos(a) * 2.9, 0.5 + Float(k % 3) * 0.35, sin(a) * 2.9); f.castsShadow = false
            if !reduceMotion {
                let d = 2.0 + Double(k % 4) * 0.5
                let m = SCNAction.moveBy(x: CGFloat(sin(a)) * 0.2, y: 0.25, z: CGFloat(cos(a)) * 0.2, duration: d); m.timingMode = .easeInEaseOut
                f.runAction(.repeatForever(.sequence([m, m.reversed()])))
            }
            island.addChildNode(f)
        }

        // Mouvement lent : l'île respire et pivote doucement
        if !reduceMotion {
            let turn = SCNAction.rotateBy(x: 0, y: 0.32, z: 0, duration: 7); turn.timingMode = .easeInEaseOut
            island.runAction(.repeatForever(.sequence([turn, turn.reversed()])))
            let bob = SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 2.6); bob.timingMode = .easeInEaseOut
            island.runAction(.repeatForever(.sequence([bob, bob.reversed()])))
        }
        island.eulerAngles.y = -0.16
        return scene
    }

    static func update(_ scene: SCNScene, counts: [Int], selected: Int?) {
        for (i, r) in rooms.enumerated() {
            guard let room = scene.rootNode.childNode(withName: "room-\(i)", recursively: true) else { continue }
            let n = counts.indices.contains(i) ? counts[i] : 0
            let on = selected == i
            if let floor = room.childNode(withName: "floor", recursively: false) {
                floor.geometry?.firstMaterial?.emission.contents = on ? r.color : UIColor.black
                floor.geometry?.firstMaterial?.emission.intensity = on ? 0.55 : 0
            }
            if let orb = room.childNode(withName: "orb", recursively: false) {
                SCNTransaction.begin(); SCNTransaction.animationDuration = 0.5
                orb.opacity = n > 0 ? 1 : 0
                let s = Float(min(1.6, 0.8 + Double(n) * 0.18))
                orb.scale = SCNVector3(s, s, s)
                SCNTransaction.commit()
            }
            SCNTransaction.begin(); SCNTransaction.animationDuration = 0.45
            room.position.y = on ? 0.2 : 0.12
            SCNTransaction.commit()
        }
    }

    // MARK: Meubles
    static func kitchen(_ r: SCNNode) {
        put(box(1.2, 0.36, 0.3, white, rough: 0.5), -0.05, 0.22, -0.38, in: r)
        put(box(1.22, 0.04, 0.33, wood, rough: 0.6), -0.05, 0.42, -0.38, in: r)
        put(box(0.3, 0.72, 0.3, UIColor(red: 0.85, green: 0.89, blue: 0.96, alpha: 1), r: 0.05, rough: 0.35), 0.6, 0.4, -0.38, in: r)
        let table = SCNNode(geometry: SCNCylinder(radius: 0.26, height: 0.04)); table.geometry?.materials = [mat(wood)]; table.castsShadow = true
        put(table, -0.15, 0.32, 0.2, in: r)
        let leg = SCNNode(geometry: SCNCylinder(radius: 0.03, height: 0.3)); leg.geometry?.materials = [mat(ink)]
        put(leg, -0.15, 0.16, 0.2, in: r)
        let pot = SCNNode(geometry: SCNCylinder(radius: 0.07, height: 0.08)); pot.geometry?.materials = [mat(UIColor(red: 0.91, green: 0.51, blue: 0.42, alpha: 1), rough: 0.4)]
        put(pot, -0.4, 0.48, -0.38, in: r)
    }
    static func living(_ r: SCNNode) {
        let sofa = UIColor(red: 0.62, green: 0.54, blue: 0.92, alpha: 1)
        put(box(0.95, 0.2, 0.36, sofa, r: 0.06), 0.05, 0.14, -0.32, in: r)
        put(box(0.95, 0.3, 0.12, sofa, r: 0.05), 0.05, 0.3, -0.46, in: r)
        put(box(0.14, 0.26, 0.36, sofa, r: 0.05), -0.45, 0.2, -0.32, in: r)
        put(box(0.14, 0.26, 0.36, sofa, r: 0.05), 0.55, 0.2, -0.32, in: r)
        let rug = SCNNode(geometry: SCNCylinder(radius: 0.42, height: 0.012)); rug.geometry?.materials = [mat(UIColor(red: 0.98, green: 0.86, blue: 0.78, alpha: 1), rough: 1)]
        put(rug, 0.05, 0.05, 0.15, in: r)
        put(box(0.4, 0.06, 0.26, wood), 0.05, 0.18, 0.15, in: r)
        let plantPot = SCNNode(geometry: SCNCylinder(radius: 0.08, height: 0.16)); plantPot.geometry?.materials = [mat(white)]
        put(plantPot, 0.62, 0.12, 0.35, in: r)
        let leaves = SCNNode(geometry: SCNSphere(radius: 0.16)); leaves.geometry?.materials = [mat(UIColor(red: 0.5, green: 0.78, blue: 0.62, alpha: 1))]; leaves.castsShadow = true
        put(leaves, 0.62, 0.34, 0.35, in: r)
    }
    static func bedroom(_ r: SCNNode) {
        put(box(0.72, 0.16, 0.95, wood, r: 0.03), -0.2, 0.12, 0.0, in: r)
        put(box(0.68, 0.1, 0.88, white, r: 0.05, rough: 0.9), -0.2, 0.25, 0.02, in: r)
        put(box(0.66, 0.06, 0.5, UIColor(red: 0.97, green: 0.72, blue: 0.82, alpha: 1), r: 0.03, rough: 0.9), -0.2, 0.31, 0.16, in: r)
        put(box(0.26, 0.08, 0.16, white, r: 0.04), -0.36, 0.33, -0.3, in: r)
        put(box(0.26, 0.08, 0.16, white, r: 0.04), -0.04, 0.33, -0.3, in: r)
        put(box(0.22, 0.24, 0.22, wood), 0.45, 0.16, -0.32, in: r)
        let lampe = SCNNode(geometry: SCNSphere(radius: 0.07)); lampe.geometry?.materials = [mat(.white, emit: UIColor(red: 1, green: 0.85, blue: 0.65, alpha: 1))]
        put(lampe, 0.45, 0.36, -0.32, in: r)
    }
    static func bathroom(_ r: SCNNode) {
        let tub = SCNNode(geometry: SCNCapsule(capRadius: 0.2, height: 0.9)); tub.geometry?.materials = [mat(white, rough: 0.25)]
        tub.eulerAngles.z = .pi / 2; tub.scale = SCNVector3(1, 1, 0.75); tub.castsShadow = true
        put(tub, -0.15, 0.2, -0.3, in: r)
        let water = SCNNode(geometry: SCNCylinder(radius: 0.16, height: 0.01)); water.geometry?.materials = [mat(UIColor(red: 0.62, green: 0.8, blue: 1, alpha: 1), rough: 0.1)]
        water.scale = SCNVector3(2.3, 1, 0.9); put(water, -0.15, 0.33, -0.3, in: r)
        put(box(0.34, 0.3, 0.24, white, r: 0.04, rough: 0.3), 0.5, 0.17, 0.25, in: r)
        put(box(0.3, 0.3, 0.02, UIColor(red: 0.8, green: 0.88, blue: 1, alpha: 1), rough: 0.05), 0.5, 0.55, 0.38, in: r)
    }
}
