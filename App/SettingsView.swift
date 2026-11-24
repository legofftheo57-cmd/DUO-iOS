import SwiftUI
import UniformTypeIdentifiers
import DUOCore

struct SettingsView: View {
    @Environment(AppStore.self) private var store; @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("nightStart") private var nightStart = 1200; @AppStorage("nightEnd") private var nightEnd = 420
    @AppStorage("exclusions") private var exclusions = ""
    @AppStorage("duo.me") private var me = "Théo"
    @State private var email = ""; @State private var password = ""; @State private var invitation = ""; @State private var token: String?
    @State private var confirmDisconnect = false
    @State private var exportURL: URL?; @State private var deletionPhrase = ""; @State private var confirmDeletion = false
    @State private var showRestorePicker = false; @State private var confirmRestore = false
    @State private var stagedBackup: Snapshot?
    @State private var inviteURL: URL?; @State private var confirmRevocation = false; @State private var recoveryMode = false; @State private var recoveryCode = ""; @State private var recoveryPassword = ""
    var body: some View {
        Form {
            Section {
                NavigationLink { AccountView() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: store.linkState == .linked ? "checkmark.icloud.fill" : "iphone.radiowaves.left.and.right")
                            .foregroundStyle(store.linkState == .linked ? Color.green : Color.orange).font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nos deux téléphones").font(.headline)
                            Text(store.linkState == .linked ? store.lastSyncText : (store.linkState == .noHome ? "Compte ouvert · foyer à créer ou rejoindre" : (store.linkState == .noServer ? "Version sans serveur" : "Pas encore relié : créer mon compte"))).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: { Text("Connexion") }
            Section {
                Picker("Ce téléphone est celui de", selection: $me) { Text("Théo").tag("Théo"); Text("Lilou").tag("Lilou") }.pickerStyle(.segmented)
            } header: { Text("Qui suis-je ?") } footer: { Text("DUO adapte les horaires, la fatigue et les propositions à la personne qui tient ce téléphone.") }
            if DUORelease.soloOnly {
            Section("Mon iPhone") {
                Label("Version personnelle — hors ligne", systemImage: "iphone")
                Text("Mes tâches, mes courses, mes repas et mon planning sont conservés sur cet iPhone. Aucun compte, aucune invitation, aucune synchronisation.")
                    .font(.caption)
                Text("Avant une réinstallation, préparez une sauvegarde JSON dans Confidentialité, puis enregistrez-la dans Fichiers.")
                    .font(.caption)
            }
            }
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
                Text("L’export contient aussi le budget et les soldes manuels : gardez-le dans un emplacement privé. Une ancienne sauvegarde sans finances conserve vos finances actuelles.").font(.caption)
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
