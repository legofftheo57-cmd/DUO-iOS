import SwiftUI
import UniformTypeIdentifiers
import DUOCore

struct SettingsView: View {
    @Environment(AppStore.self) private var store; @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("nightStart") private var nightStart = 1200; @AppStorage("nightEnd") private var nightEnd = 420
    @AppStorage("exclusions") private var exclusions = ""
    @State private var email = ""; @State private var password = ""; @State private var invitation = ""; @State private var token: String?
    @State private var confirmDisconnect = false
    @State private var exportURL: URL?; @State private var deletionPhrase = ""; @State private var confirmDeletion = false
    @State private var showRestorePicker = false; @State private var confirmRestore = false
    @State private var stagedBackup: Snapshot?
    @State private var inviteURL: URL?; @State private var confirmRevocation = false; @State private var recoveryMode = false; @State private var recoveryCode = ""; @State private var recoveryPassword = ""
    var body: some View {
        Form {
            Section("Graphite & Ice") {
                Picker("Apparence", selection: $appearance) { Text("Système").tag("system"); Text("Clair").tag("light"); Text("Sombre").tag("dark"); Text("Horaire").tag("schedule") }
                if appearance == "schedule" {
                    DatePicker("Début de nuit", selection: timeBinding($nightStart), displayedComponents: [.hourAndMinute])
                    DatePicker("Fin de nuit", selection: timeBinding($nightEnd), displayedComponents: [.hourAndMinute])
                    if nightStart == nightEnd { Text("Horaires identiques : mode clair toute la journée.") }
                }
            }
            Section("Alimentation") {
                TextField("Exclusions séparées par des virgules", text: $exclusions).textInputAutocapitalization(.never)
                Text("Exemples : lait, gluten, œufs, soja, poisson, poulet. Correspondance sur les noms exacts ; pas de garantie contre les traces ou contaminations croisées.").font(.caption)
            }
            Section("Mon iPhone") {
                Label("Version personnelle — hors ligne", systemImage: "iphone")
                Text("Mes tâches, mes courses, mes repas et mon planning sont conservés sur cet iPhone. Aucun compte, aucune invitation, aucune synchronisation.")
                    .font(.caption)
                Text("Avant une réinstallation, préparez une sauvegarde JSON dans Confidentialité, puis enregistrez-la dans Fichiers.")
                    .font(.caption)
            }
            if !DUORelease.soloOnly {
            Section("Notre espace commun") {
                Text(store.status)
                Text("La connexion utilise le service Supabase configuré pour DUO. Seules les données créées dans le foyer connecté seront envoyées. Le mode local reste séparé.").font(.caption)
                if store.backend?.session == nil {
                    TextField("Adresse e-mail", text: $email).textContentType(.username).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Mot de passe", text: $password).textContentType(.password)
                    Button("Se connecter") { Task { await store.connect(email: email, password: password, createAccount: false); password = ""; await store.sync() } }.disabled(email.isEmpty || password.isEmpty)
                    Button("Créer mon compte") { Task { await store.connect(email: email, password: password, createAccount: true); password = "" } }.disabled(email.isEmpty || password.count < 12)
                    Button("Mot de passe oublié ?") { recoveryMode = true; Task { await store.requestPasswordReset(email: email) } }.disabled(email.isEmpty)
                    if recoveryMode {
                        Text("Saisissez le code contenu dans l’e-mail de récupération. Le modèle d’e-mail Supabase doit inclure le code {{ .Token }}.").font(.caption)
                        TextField("Code reçu par e-mail", text: $recoveryCode).keyboardType(.numberPad).textContentType(.oneTimeCode)
                        SecureField("Nouveau mot de passe (12 caractères min.)", text: $recoveryPassword).textContentType(.newPassword)
                        Button("Confirmer le nouveau mot de passe") {
                            Task {
                                await store.completePasswordReset(email: email, code: recoveryCode, password: recoveryPassword)
                                if store.error == nil { recoveryMode = false; recoveryCode = ""; recoveryPassword = "" }
                            }
                        }.disabled(recoveryCode.count < 6 || recoveryPassword.count < 12)
                    }
                    Button("Restaurer ma session sécurisée") { Task { await store.connect(email: "", password: "", createAccount: false); await store.sync() } }
                } else {
                    if store.backend?.session?.user.id != store.snapshot.userID {
                        Button("Créer notre foyer") { Task { await store.setupHome(invitation: nil) } }
                        TextField("Code d’invitation", text: $invitation).textInputAutocapitalization(.never).autocorrectionDisabled()
                        if store.pendingInvitation != nil {
                            Label("Invitation reçue : il reste à confirmer.", systemImage: "envelope.badge").font(.caption)
                        }
                        Button("Accepter l’invitation et rejoindre le foyer") {
                            Task { await store.setupHome(invitation: invitation.isEmpty ? store.pendingInvitation : invitation) }
                        }.disabled(invitation.isEmpty && store.pendingInvitation == nil)
                    } else {
                        Button("Inviter Lilou / mon partenaire") {
                            Task {
                                token = await store.invite()
                                inviteURL = token.flatMap { InviteLink.make(token: $0) }
                            }
                        }
                        if let token {
                            if let inviteURL {
                                ShareLink(item: inviteURL, subject: Text("Invitation DUO"), message: Text("Rejoins notre foyer DUO avec ton propre compte. Installe DUO puis ouvre ce lien :")) {
                                    Label("Partager l’invitation", systemImage: "square.and.arrow.up")
                                }
                            }
                            Text("Code de secours : " + token).textSelection(.enabled).font(.caption)
                            Text("Valable 24 h, une seule utilisation. L’autre personne doit d’abord installer DUO et se connecter à son propre compte. Si le lien ne s’ouvre pas, copier le code ci-dessus dans DUO.").font(.caption)
                        }
                        Button("Révoquer les invitations en attente", role: .destructive) {
                                confirmRevocation = true
                            }
                            .disabled(store.syncing)
                            .confirmationDialog("Invalider le code d’invitation ?", isPresented: $confirmRevocation) {
                                Button("Révoquer ce code", role: .destructive) {
                                    Task {
                                        if await store.revokeInvitation() {
                                            token = nil
                                            inviteURL = nil
                                        }
                                    }
                                }
                                Button("Annuler", role: .cancel) { }
                            } message: {
                                Text("Le lien et le code précédemment partagés ne permettront plus de rejoindre le foyer. Vous pourrez créer une nouvelle invitation.")
                            }
                        Button("Synchroniser maintenant") { Task { await store.sync() } }.disabled(store.syncing)
                        if store.syncing { ProgressView("Synchronisation en cours…") }
                        if !store.snapshot.conflicts.isEmpty {
                            Label("\(store.snapshot.conflicts.count) conflit(s) à résoudre avant l’envoi", systemImage: "exclamationmark.triangle").font(.caption)
                        }
                        if let last = store.lastSuccessfulSync {
                            Text("Dernière synchronisation réussie : " + last.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                        }
                        Text("\(store.snapshot.pending.count) modification(s) à envoyer. Synchronisation toutes les 30 secondes lorsque l’application est ouverte.").font(.caption)
                    }
                    Button("Se déconnecter") {
                        if store.snapshot.pending.isEmpty { Task { await store.disconnect() } }
                        else { confirmDisconnect = true }
                    }.disabled(store.syncing)
                    .confirmationDialog("Des modifications restent sur cet iPhone", isPresented: $confirmDisconnect, titleVisibility: .visible) {
                        Button("Synchroniser d’abord") { Task { await store.sync() } }
                        Button("Se déconnecter en conservant la copie locale") { Task { await store.disconnect() } }
                        Button("Annuler", role: .cancel) { }
                    } message: {
                        Text("Les modifications non envoyées restent dans le cache de ce compte sur cet iPhone. Reconnectez-vous au même foyer pour les reprendre. Votre partenaire ne les voit pas encore.")
                    }
                }
            }
            }
            Section("Confidentialité") {
                Text(DUORelease.soloOnly
                    ? "Aucune publicité, aucun compte, aucune analyse d’usage et aucune transmission en ligne. Joe fonctionne localement. Aucun accès Santé, Contacts ou calendrier Apple."
                    : "Aucune publicité ni analyse d’usage. L’assistant local fonctionne sans API externe. Le bouton IA en ligne transmet uniquement la question saisie, après votre action explicite, si ce service optionnel est configuré. Les séances et habitudes sont privées par défaut. Aucun accès Santé, Contacts ou calendrier Apple.")
                Text(DUORelease.soloOnly
                    ? "Export local JSON, sans mot de passe : sauvegardez-le dans Fichiers avant toute désinstallation. Gardez la même application lors des renouvellements de signature."
                    : "Export local JSON, sans mots de passe ni jetons. Pour un compte synchronisé, lancez d’abord une synchronisation ; le fichier reflète ensuite les données visibles sur cet iPhone.")
                    .font(.caption)
                Button("Préparer une copie de mes données") {
                    do { exportURL = try store.prepareExport() }
                    catch { store.error = error.localizedDescription }
                }.disabled(!store.ready || store.syncing)
                if let exportURL {
                    ShareLink(item: exportURL) { Label("Enregistrer ou partager l’export", systemImage: "square.and.arrow.up") }
                }
                if DUORelease.soloOnly {
                    if let backup = store.safetyBackupURL {
                        ShareLink(item: backup) { Label("Enregistrer la copie avant restauration", systemImage: "externaldrive.badge.checkmark") }
                    }
                    Text(store.status).font(.caption).accessibilityIdentifier("storageStatus")
                    Button {
                        showRestorePicker = true
                    } label: {
                        Label("Restaurer une sauvegarde DUO", systemImage: "arrow.counterclockwise.icloud")
                    }
                    Text("La restauration remplace les données actuelles après confirmation. Une copie de sécurité de l’état précédent est conservée sur cet iPhone et peut être enregistrée ci-dessus.")
                        .font(.caption)
                }
                if store.backend?.session != nil {
                    Text("Suppression irréversible du compte en ligne : vos données privées sont effacées ; vos éléments partagés dont DUO connaît l’auteur sont retirés chez votre partenaire. Les données créées par votre partenaire sont conservées. Les appareils hors ligne ne sont mis à jour qu’à leur reconnexion.").font(.caption)
                    TextField("Tapez SUPPRIMER", text: $deletionPhrase).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    Button("Supprimer définitivement mon compte", role: .destructive) { confirmDeletion = true }
                        .disabled(deletionPhrase != "SUPPRIMER" || store.syncing)
                }
            }
            Section("À propos") {
                if DUORelease.soloOnly {
                    Text("DUO Solo est une version de développement installée sur un seul iPhone. Les données restent locales ; la synchronisation sera étudiée ultérieurement.")
                        .font(.caption)
                } else {
                    Text("DUO est en version de développement. La suppression en ligne exige la migration SQL 002 et la fonction serveur delete-account déployées. Aucun effacement distant n’est simulé en l’absence de ce service.")
                        .font(.caption)
                }
            }
        }.fileImporter(isPresented: $showRestorePicker, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do {
                    stagedBackup = try store.previewLocalImport(from: url)
                    confirmRestore = true
                } catch {
                    store.error = "Sauvegarde non restaurée : " + error.localizedDescription
                }
            case .failure(let error):
                store.error = "Impossible d’ouvrir le fichier : " + error.localizedDescription
            }
        }.confirmationDialog("Remplacer les données sur cet iPhone ?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Remplacer par la sauvegarde", role: .destructive) {
                if let stagedBackup {
                    do { try store.restoreLocalImport(stagedBackup) }
                    catch { store.error = "Restauration impossible : " + error.localizedDescription }
                }
                stagedBackup = nil
            }
            Button("Annuler", role: .cancel) { stagedBackup = nil }
        } message: {
            Text("La sauvegarde contient \(stagedBackup?.records.count ?? 0) éléments, suppressions historiques comprises. Les données actuelles seront remplacées.")
        }.onAppear {
            if let token = store.pendingInvitation { invitation = token }
        }.onChange(of: store.pendingInvitation) { _, newToken in
            if let newToken { invitation = newToken }
        }.confirmationDialog("Supprimer le compte et ses données ?", isPresented: $confirmDeletion, titleVisibility: .visible) {
            Button("Oui, supprimer définitivement", role: .destructive) { Task { await store.deleteAccount(); deletionPhrase = ""; exportURL = nil } }
            Button("Annuler", role: .cancel) { }
        } message: {
            Text("La suppression du compte en ligne est irréversible. Un export préalable est conseillé. Les données de votre partenaire restent les siennes.")
        }.navigationTitle("Réglages").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Terminé") { dismiss() } } }
    }
    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(get: { Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60, second: 0, of: Date()) ?? Date() }, set: { value in let c = Calendar.current.dateComponents([.hour, .minute], from: value); minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0) })
    }
}
