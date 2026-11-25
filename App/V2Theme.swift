import SwiftUI
import DUOCore

/// Palette « nuit et pastels » validée sur la maquette du 24/11/2026.
enum P {
    static let bg = Color(hex: 0x0B0A10)
    static let card = Color(hex: 0x1E1B29)
    static let text = Color(hex: 0xF4F1FA)
    static let mut = Color(hex: 0xABA4BE)
    static let lav = Color(hex: 0xC8B6FF)
    static let peach = Color(hex: 0xFFC8A8)
    static let mint = Color(hex: 0xB8F0D8)
    static let rose = Color(hex: 0xF7C6D9)
    static let sky = Color(hex: 0xBFD7FF)
    static let butter = Color(hex: 0xFFE3A8)
    static let ink = Color(hex: 0x15111E)
    static func person(_ p: DuoPerson?) -> Color { p == .theo ? lav : (p == .lilou ? peach : mint) }
    static let tints: [Color] = [lav, butter, mint, rose]
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font { .system(size: size, weight: weight, design: .serif) }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

struct Glass: ViewModifier {
    var radius: CGFloat = 24
    @Environment(\.accessibilityReduceTransparency) private var reduce
    func body(content: Self.Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background { if reduce { shape.fill(P.card) } else { shape.fill(.ultraThinMaterial).overlay(shape.fill(P.card.opacity(0.55))) } }
            .overlay(shape.strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
    }
}
extension View {
    func glass(_ radius: CGFloat = 24) -> some View { modifier(Glass(radius: radius)) }
    func kicker() -> some View { self.font(.system(size: 11, weight: .semibold)).tracking(1.6).textCase(.uppercase).foregroundStyle(P.mut) }
}

struct DuoBackground: View {
    var body: some View {
        ZStack {
            P.bg
            RadialGradient(colors: [Color(hex: 0x231D33), .clear], center: UnitPoint(x: 0.8, y: -0.05), startRadius: 0, endRadius: 520)
        }.ignoresSafeArea()
    }
}

struct Avatar: View {
    let person: DuoPerson?; var size: CGFloat = 26
    var body: some View {
        Text(person?.initial ?? "2")
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(P.ink)
            .frame(width: size, height: size)
            .background(Circle().fill(person == nil ? AnyShapeStyle(LinearGradient(colors: [P.lav, P.peach], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(P.person(person))))
            .accessibilityLabel(person?.rawValue ?? "À deux")
    }
}

struct CheckBox: View {
    let on: Bool; let action: () -> Void; let label: String
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(on ? P.mint : .clear)
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(on ? P.mint : Color.white.opacity(0.28), lineWidth: 1.5))
                .overlay(Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: 0x12251D)).opacity(on ? 1 : 0))
                .frame(width: 26, height: 26)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: on)
        .accessibilityLabel(on ? "Rouvrir \(label)" : "Terminer \(label)")
    }
}

struct PillButton: View {
    let title: String; var fill: Color = P.lav; var fg: Color = P.ink; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(fg)
                .padding(.horizontal, 16).frame(minHeight: 44).background(Capsule().fill(fill))
        }.buttonStyle(.plain)
    }
}

/// Barre d'onglets flottante en verre.
struct TabBarV2: View {
    @Binding var tab: Int
    private let items: [(String, String)] = [("Accueil", "circle.circle"), ("Journée", "clock"), ("Maison", "house"), ("Cuisine", "fork.knife"), ("Budget", "drop")]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                Button { withAnimation(.snappy) { tab = i } } label: {
                    VStack(spacing: 4) {
                        Image(systemName: items[i].1).font(.system(size: 19, weight: .regular)).foregroundStyle(tab == i ? P.lav : P.mut)
                        Text(items[i].0).font(.system(size: 10.5, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8).foregroundStyle(tab == i ? P.text : P.mut)
                    }.frame(maxWidth: .infinity, minHeight: 52).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityAddTraits(tab == i ? .isSelected : [])
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 6)
        .glass(26)
    }
}

struct ToastView: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 14, weight: .semibold)).foregroundStyle(P.ink)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(P.text))
            .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// Ligne de tâche commune à l'accueil et à la maison.
struct TaskLineV2: View {
    @Environment(AppStore.self) private var store
    @State private var editing = false
    let row: Record; let task: HouseTask
    var body: some View {
        let who = store.person(forAssignee: task.assignee)
        HStack(spacing: 6) {
            CheckBox(on: task.completed != nil, action: { withAnimation(.snappy) { store.complete(row) } }, label: task.title)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).font(.system(size: 15)).foregroundStyle(task.completed == nil ? P.text : P.mut).strikethrough(task.completed != nil)
                if let due = task.due, task.completed == nil {
                    Text(Calendar.current.isDateInToday(due) ? "aujourd'hui" : due.formatted(.dateTime.weekday(.wide))).font(.system(size: 12)).foregroundStyle(P.mut)
                }
            }
            Spacer(minLength: 4)
            if task.repeatDays > 0 { Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 11)).foregroundStyle(P.mut).accessibilityLabel("Revient tous les \(task.repeatDays) jours") }
            Avatar(person: who, size: 24)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Modifier", systemImage: "pencil") { editing = true }
            Button("Supprimer", systemImage: "trash", role: .destructive) { withAnimation { store.remove(row) }; if store.error == nil { store.toast = "Tâche supprimée" } }
        }
        .sheet(isPresented: $editing) { NavigationStack { ItemEditor(kind: "task", row: row) } }
    }
}
