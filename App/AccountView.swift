import SwiftUI
import UIKit
import DUOCore

/// « Nos deux téléphones » : compte, foyer, invitation et synchronisation, en étapes simples.
struct AccountView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage("duo.me") private var me = "Théo"
    @State private var creating = true
    @State private var email = ""
    @State private var password = ""
    @State private var invitation = ""
    @State private var token: String?
    @State private var inviteURL: URL?
    @State private var confirmLogout = false
    @State private var resetMode = false
    @State private var resetCode = ""
    @State private var resetPassword = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                switch store.linkState {
                case .noServer: noServer
                case .signedOut: signIn
                case .noHome: home
                case .linked: linked
                }
                if let e = store.error {
                    Label(e, systemImage: "exclamationmark.triangle.fill").font(.system(size: 13)).foregroundStyle(P.peach)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading).glass(16)
                }
                shared
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(DuoBackground())
        .preferredColorScheme(.dark)
        .navigationTitle("Nos deux téléphones")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
        .disabled(store.syncing)
        .overlay { if store.syncing { ProgressView().controlSize(.large).padding(24).glass(20) } }
        .onAppear { if let t = store.pendingInvitation { invitation = t; } }
        .onChange(of: store.pendingInvitation) { _, t in if let t { invitation = t } }
    }

    // MARK: En-tête avec les 3 étapes
    private var header: some View {
        let step: Int = { switch store.linkState { case .signedOut, .noServer: return 0; case .noHome: return 1; case .linked: return 2 } }()
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: -10) {
                Avatar(person: .theo, size: 54).overlay(Circle().strokeBorder(P.bg, lineWidth: 3))
                Avatar(person: .lilou, size: 54).overlay(Circle().strokeBorder(P.bg, lineWidth: 3))
                Image(systemName: step == 2 ? "checkmark" : "link").font(.system(size: 16, weight: .bold)).foregroundStyle(P.ink)
                    .frame(width: 34, height: 34).background(Circle().fill(step == 2 ? P.mint : P.peach)).offset(x: 18, y: 14)
            }
            Text(step == 2 ? "Vos téléphones sont reliés" : "Relier Théo et Lilou").font(P.serif(28)).foregroundStyle(P.text)
            HStack(spacing: 8) {
                stepPill(1, "Compte", done: step > 0, current: step == 0)
                stepPill(2, "Foyer", done: step > 1, current: step == 1)
                stepPill(3, "Partagé", done: step == 2, current: false)
            }
        }
    }
    private func stepPill(_ n: Int, _ t: String, done: Bool, current: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(n).circle").foregroundStyle(done ? P.mint : (current ? P.peach : P.mut))
            Text(t).foregroundStyle(current || done ? P.text : P.mut)
        }.font(.system(size: 13, weight: .semibold))
        .padding(.horizontal, 10).frame(minHeight: 34)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(current ? 0.1 : 0.04)))
    }

    private var noServer: some View {
        Text("Cette version de DUO a été installée sans serveur : elle fonctionne sur un seul téléphone. Une nouvelle installation est nécessaire pour relier vos deux iPhone.")
            .font(.system(size: 14)).foregroundStyle(P.mut).padding(16).glass(20)
    }

    // MARK: Étape 1 : compte
    private var signIn: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ce téléphone est celui de").kicker()
            Picker("Je suis", selection: $me) { Text("Théo").tag("Théo"); Text("Lilou").tag("Lilou") }.pickerStyle(.segmented)
            Picker("Mode", selection: $creating) { Text("Créer mon compte").tag(true); Text("J'ai déjà un compte").tag(false) }.pickerStyle(.segmented).padding(.top, 6)
            TextField("Adresse e-mail", text: $email).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                .padding(14).glass(16).foregroundStyle(P.text)
            SecureField(creating ? "Mot de passe (12 caractères minimum)" : "Mot de passe", text: $password).textContentType(creating ? .newPassword : .password)
                .padding(14).glass(16).foregroundStyle(P.text)
            if creating && !password.isEmpty && password.count < 12 { Text("Encore \(12 - password.count) caractère(s).").font(.system(size: 12)).foregroundStyle(P.peach) }
            PillButton(title: creating ? "Créer mon compte" : "Me connecter", fill: P.peach) {
                Task {
                    if creating { await store.createAccountAndSignIn(email: email.trimmingCharacters(in: .whitespaces), password: password) }
                    else { await store.connect(email: email.trimmingCharacters(in: .whitespaces), password: password, createAccount: false); await store.sync(showErrors: false) }
                    if store.error == nil { password = "" }
                }
            }
            .disabled(email.isEmpty || password.isEmpty || (creating && password.count < 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            if !creating {
                Button("Mot de passe oublié ?") { resetMode = true; Task { await store.requestPasswordReset(email: email) } }
                    .font(.system(size: 13)).foregroundStyle(P.mut).disabled(email.isEmpty)
                if resetMode {
                    TextField("Code reçu par e-mail", text: $resetCode).keyboardType(.numberPad).textContentType(.oneTimeCode).padding(14).glass(16).foregroundStyle(P.text)
                    SecureField("Nouveau mot de passe (12 caractères min.)", text: $resetPassword).textContentType(.newPassword).padding(14).glass(16).foregroundStyle(P.text)
                    PillButton(title: "Changer le mot de passe", fill: P.lav) {
                        Task { await store.completePasswordReset(email: email, code: resetCode, password: resetPassword); if store.error == nil { resetMode = false; resetCode = ""; resetPassword = "" } }
                    }.disabled(resetCode.count < 6 || resetPassword.count < 12)
                }
            }
            Text("Chacun crée son compte sur son propre téléphone, avec sa propre adresse e-mail. Le mot de passe reste sur ton iPhone et chez le serveur, jamais ailleurs.")
                .font(.system(size: 12)).foregroundStyle(P.mut)
        }
        .padding(16).glass(22)
    }

    // MARK: Étape 2 : foyer
    private var home: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Le premier qui arrive", systemImage: "house.fill").font(.system(size: 15, weight: .semibold)).foregroundStyle(P.text)
                Text("Crée le foyer, puis envoie l'invitation à l'autre. Tout ce qui est déjà sur ce téléphone y sera ajouté.").font(.system(size: 13)).foregroundStyle(P.mut)
                PillButton(title: "Créer notre foyer", fill: P.mint, fg: Color(hex: 0x12251D)) { Task { await store.setupHome(invitation: nil) } }
            }.padding(16).glass(22)
            VStack(alignment: .leading, spacing: 8) {
                Label("J'ai reçu une invitation", systemImage: "envelope.open.fill").font(.system(size: 15, weight: .semibold)).foregroundStyle(P.text)
                Text("Ouvre le lien reçu par Messages : le code se remplit tout seul. Sinon, colle le code ici.").font(.system(size: 13)).foregroundStyle(P.mut)
                TextField("Code d'invitation", text: $invitation).textInputAutocapitalization(.never).autocorrectionDisabled().font(.system(size: 12, design: .monospaced))
                    .padding(12).glass(14).foregroundStyle(P.text)
                PillButton(title: "Rejoindre le foyer", fill: P.lav) { Task { await store.setupHome(invitation: invitation) } }
                    .disabled(invitation.trimmingCharacters(in: .whitespaces).count < 72)
            }.padding(16).glass(22)
            Button("Me déconnecter de ce compte") { Task { await store.disconnect() } }.font(.system(size: 13)).foregroundStyle(P.mut)
        }
    }

    // MARK: Étape 3 : relié
    private var linked: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: store.syncInFlight ? "arrow.triangle.2.circlepath" : "checkmark.icloud.fill").font(.system(size: 22)).foregroundStyle(P.mint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.lastSyncText).font(.system(size: 15, weight: .semibold)).foregroundStyle(P.text)
                    Text(store.snapshot.pending.isEmpty ? "Tout est envoyé. Les changements arrivent chez l'autre en quelques secondes quand l'app est ouverte." : "\(store.snapshot.pending.count) modification(s) partiront dès que possible.")
                        .font(.system(size: 12)).foregroundStyle(P.mut)
                }
            }
            PillButton(title: "Synchroniser maintenant", fill: P.mint, fg: Color(hex: 0x12251D)) { Task { await store.sync() } }.disabled(store.syncInFlight)

            Divider().opacity(0.2).padding(.vertical, 4)
            Text("Inviter l'autre téléphone").font(.system(size: 15, weight: .semibold)).foregroundStyle(P.text)
            Text("Si l'autre n'a pas encore rejoint : crée l'invitation, envoie-la par Messages. Valable 24 h, une seule fois.").font(.system(size: 13)).foregroundStyle(P.mut)
            if let token {
                if let inviteURL {
                    ShareLink(item: inviteURL, subject: Text("Invitation DUO"), message: Text("Rejoins notre foyer DUO : ouvre ce lien sur ton iPhone (DUO doit être installé).")) {
                        Label("Envoyer l'invitation", systemImage: "square.and.arrow.up").font(.system(size: 14, weight: .semibold)).foregroundStyle(P.ink)
                            .padding(.horizontal, 16).frame(minHeight: 44).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(P.peach))
                    }
                }
                Text(token).font(.system(size: 11, design: .monospaced)).foregroundStyle(P.mut).textSelection(.enabled)
                Button("Copier le code") { UIPasteboard.general.string = token; store.toast = "Code copié" }.font(.system(size: 13, weight: .semibold)).foregroundStyle(P.lav)
                Button("Annuler cette invitation", role: .destructive) { Task { if await store.revokeInvitation() { self.token = nil; inviteURL = nil } } }.font(.system(size: 13))
            } else {
                PillButton(title: "Créer une invitation", fill: P.peach) {
                    Task { token = await store.invite(); inviteURL = token.flatMap { InviteLink.make(token: $0) } }
                }
            }
            Divider().opacity(0.2).padding(.vertical, 4)
            Button("Se déconnecter") {
                if store.snapshot.pending.isEmpty { Task { await store.disconnect() } } else { confirmLogout = true }
            }.font(.system(size: 13)).foregroundStyle(P.mut)
            .confirmationDialog("Des modifications n'ont pas encore été envoyées", isPresented: $confirmLogout, titleVisibility: .visible) {
                Button("Synchroniser d'abord") { Task { await store.sync() } }
                Button("Me déconnecter quand même", role: .destructive) { Task { await store.disconnect() } }
                Button("Annuler", role: .cancel) {}
            }
        }
        .padding(16).glass(22)
    }

    private var shared: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ce qui est partagé").kicker()
            Text("Tâches, courses, repas, frigo, rendez-vous et dépenses « communes » apparaissent sur les deux téléphones. Les opérations « perso » du budget restent visibles par toi seul.")
                .font(.system(size: 12)).foregroundStyle(P.mut)
        }.padding(.top, 4)
    }
}
