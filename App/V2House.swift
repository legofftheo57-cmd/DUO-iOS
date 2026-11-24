import SwiftUI
import DUOCore

/// L'appartement en 3D isométrique : chaque pièce porte ses tâches.
struct HouseV2: View {
    @Environment(AppStore.self) private var store
    @AppStorage("duo.room") private var room = 1
    @State private var adding = false
    @State private var who = 0 // 0 tout le monde, 1 moi, 2 l'autre
    static let rooms: [(String, Color)] = [("Cuisine", P.butter), ("Salon", P.lav), ("Chambre", P.rose), ("Salle de bain", P.sky)]

    var body: some View {
        let tasks = store.taskRows
        let counts = (0..<4).map { i in tasks.filter { Brain.room(for: $0.1.title) == i && $0.1.completed == nil }.count }
        let inRoom = tasks.filter { Brain.room(for: $0.1.title) == room }
            .filter { row in
                let p = store.person(forAssignee: row.1.assignee)
                return who == 0 || (who == 1 && p == store.me) || (who == 2 && p == store.me.other)
            }
            .sorted { ($0.1.completed != nil ? 1 : 0, $0.1.due ?? .distantFuture) < ($1.1.completed != nil ? 1 : 0, $1.1.due ?? .distantFuture) }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Maison · touche une pièce").kicker()
                        Text("Chez vous").font(P.serif(32)).foregroundStyle(P.text)
                    }
                    Spacer()
                    Text("\(store.openTasks.count) à faire").font(.system(size: 13)).foregroundStyle(P.mut).padding(.top, 8)
                }

                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(RadialGradient(colors: [Self.rooms[room].1.opacity(0.22), Color(hex: 0x14111D)], center: UnitPoint(x: 0.5, y: 0.4), startRadius: 10, endRadius: 280))
                    House3DView(counts: counts, selected: room, interactive: true) { i in withAnimation(.snappy) { room = i } }
                    Label("Fais pivoter avec le doigt", systemImage: "hand.draw").font(.system(size: 11)).foregroundStyle(P.mut).padding(12)
                }
                .frame(height: 320)
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Color.white.opacity(0.09)))

                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        Button { withAnimation(.snappy) { room = i } } label: {
                            VStack(spacing: 3) {
                                Text(Self.rooms[i].0).font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.75)
                                Text("\(counts[i])").font(P.serif(18))
                            }
                            .foregroundStyle(room == i ? P.ink : P.text)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(room == i ? Self.rooms[i].1 : Color.white.opacity(0.05)))
                        }.buttonStyle(PressScale())
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text(Self.rooms[room].0).font(P.serif(22)).foregroundStyle(P.text)
                        Spacer()
                        Picker("Pour", selection: $who) { Text("Tous").tag(0); Text(store.me.rawValue).tag(1); Text(store.me.other.rawValue).tag(2) }
                            .pickerStyle(.segmented).frame(width: 170)
                    }.padding(.bottom, 6)
                    if inRoom.isEmpty { Text("Rien à faire ici. Bravo.").font(.system(size: 14)).foregroundStyle(P.mut).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12) }
                    ForEach(inRoom, id: \.0.id) { item in TaskLineV2(row: item.0, task: item.1) }
                    Button { adding = true } label: {
                        Label("Ajouter une tâche", systemImage: "plus").font(.system(size: 14, weight: .semibold)).foregroundStyle(Self.rooms[room].1)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }.padding(.top, 6)
                    if !inRoom.isEmpty { Text("Appui long sur une tâche pour la modifier ou la supprimer.").font(.system(size: 11)).foregroundStyle(P.mut) }
                    BalanceBar(theo: Brain.balance(store.snapshot.journal ?? [], now: Date())).padding(.top, 10)
                }
                .padding(16).glass()
            }
            .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .refreshable { await store.sync() }
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
