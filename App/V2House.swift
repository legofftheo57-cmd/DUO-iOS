import SwiftUI
import DUOCore

/// L'appartement en 3D isométrique : chaque pièce porte ses tâches.
struct HouseV2: View {
    @Environment(AppStore.self) private var store
    @State private var room = 1
    @State private var adding = false
    static let rooms: [(String, Color)] = [("Cuisine", P.butter), ("Salon", P.lav), ("Chambre", P.rose), ("Salle de bain", P.sky)]

    var body: some View {
        let tasks = store.taskRows
        let inRoom = tasks.filter { Brain.room(for: $0.1.title) == room }
            .sorted { ($0.1.completed != nil ? 1 : 0, $0.1.due ?? .distantFuture) < ($1.1.completed != nil ? 1 : 0, $1.1.due ?? .distantFuture) }
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Maison · touche une pièce").kicker()
                    Text("Chez vous").font(P.serif(32)).foregroundStyle(P.text)
                }
                Spacer()
                Text("\(store.openTasks.count) à faire").font(.system(size: 13)).foregroundStyle(P.mut).padding(.top, 8)
            }.padding(.horizontal, 20).padding(.top, 8)

            IsoHouse(selected: $room, counts: (0..<4).map { i in tasks.filter { Brain.room(for: $0.1.title) == i && $0.1.completed == nil }.count })
                .frame(height: 260)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(Self.rooms[room].0).font(P.serif(22)).foregroundStyle(P.text)
                    Spacer()
                    Button { adding = true } label: { Label("Ajouter", systemImage: "plus").font(.system(size: 13, weight: .semibold)) }
                        .foregroundStyle(Self.rooms[room].1).frame(minHeight: 44)
                }
                ScrollView {
                    VStack(spacing: 0) {
                        if inRoom.isEmpty { Text("Rien à faire ici. Bravo.").font(.system(size: 14)).foregroundStyle(P.mut).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12) }
                        ForEach(inRoom, id: \.0.id) { item in TaskLineV2(row: item.0, task: item.1) }
                    }
                }.scrollIndicators(.hidden)
                BalanceBar(theo: Brain.balance(store.snapshot.journal ?? [], now: Date())).padding(.top, 8)
            }
            .padding(16).glass().padding(.horizontal, 14).padding(.bottom, 6)
        }
        .sheet(isPresented: $adding) { NavigationStack { ItemEditor(kind: "task").navigationTitle("Nouvelle tâche") } }
    }
}

/// Losanges empilés avec épaisseur : effet 3D léger, sans moteur 3D.
struct IsoHouse: View {
    @Binding var selected: Int
    let counts: [Int]
    @Environment(\.accessibilityReduceMotion) private var reduce
    var body: some View {
        GeometryReader { g in
            let cx = g.size.width / 2, cy = g.size.height / 2 + 24
            let w: CGFloat = 108
            // Positions isométriques d'une grille 2×2.
            let grid: [(CGFloat, CGFloat)] = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
            ZStack {
                ForEach([0, 1, 2, 3], id: \.self) { i in
                    let gx = grid[i].0
                    let gy = grid[i].1
                    let x = cx + (gx - gy) * w * 0.5
                    let y = cy + (gx + gy) * w * 0.29
                    let on = selected == i
                    let color = HouseV2.rooms[i].1
                    Button { withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { selected = i } } label: {
                        ZStack {
                            Tile().fill(color.opacity(0.35)).offset(y: 12)                     // épaisseur
                            Tile().fill(LinearGradient(colors: [color, color.opacity(0.35), Color(hex: 0x2A2538)], startPoint: .top, endPoint: .bottom))
                            Tile().stroke(Color.white.opacity(on ? 0.6 : 0.15), lineWidth: 1)
                        }
                        .frame(width: w * 0.98, height: w * 0.57)
                        .shadow(color: on ? color.opacity(0.6) : .clear, radius: 24)
                        .contentShape(Tile())
                    }
                    .buttonStyle(.plain)
                    .offset(y: on ? -12 : 0)
                    .position(x: x, y: y)
                    .zIndex(Double(gx + gy))
                    .accessibilityLabel("\(HouseV2.rooms[i].0), \(counts[i]) tâche(s)")
                    .accessibilityAddTraits(on ? .isSelected : [])

                    Pin(text: "\(HouseV2.rooms[i].0) · \(counts[i])", float: !reduce)
                        .position(x: x, y: y - (on ? 62 : 48))
                        .zIndex(10)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
    }
    struct Tile: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.midX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.midY)); p.closeSubpath()
            return p
        }
    }
    struct Pin: View {
        let text: String; let float: Bool
        @State private var up = false
        var body: some View {
            VStack(spacing: 0) {
                Text(text).font(.system(size: 11, weight: .bold)).foregroundStyle(P.ink)
                    .padding(.horizontal, 9).padding(.vertical, 5).background(Capsule().fill(P.text))
                Rectangle().fill(LinearGradient(colors: [P.text, .clear], startPoint: .top, endPoint: .bottom)).frame(width: 2, height: 16)
            }
            .offset(y: up ? -5 : 0)
            .onAppear { if float { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { up = true } } }
        }
    }
}
