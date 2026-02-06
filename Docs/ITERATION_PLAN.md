# AlyPlayer — Plan d'itérations

## Vue d'ensemble

```
MVP (4 semaines)     v1.0 (4 semaines)     v1.5 (4 semaines)
─────────────────    ─────────────────     ─────────────────
Import M3U basique   EPG complet           Smart features
Player AVPlayer      Parental control      Shortcuts iOS
Tabs navigation      Collections           Chromecast
Favoris              iCloud sync           Multi-profils
Onboarding           StoreKit 2            Notifications EPG
Recherche            Paywall               Export config
                     QR code import        Mode Match
                     Smart EPG matching
                     PiP
                     Accessibilité
```

---

## Itération 0 : MVP (Semaines 1-4)

### Objectif
App fonctionnelle minimale : importer une playlist M3U, naviguer les chaînes, lire un flux, gérer les favoris. Suffisant pour un test interne / TestFlight alpha.

### Semaine 1 : Fondations

| Tâche | Détail |
|-------|--------|
| Setup projet Xcode | Target iOS 17+, SwiftUI lifecycle, asset catalog |
| CoreData model v1 | Playlist, Channel (sans EPG) |
| PersistenceController | CRUD basique, preview context |
| M3UParser | Parser robuste : #EXTINF, group-title, tvg-id, tvg-name, tvg-logo, URL |
| Modèle de test M3U | Fichiers de test variés (bien formés + malformés) |
| Tests unitaires M3UParser | 10+ cas de test |

### Semaine 2 : Navigation & Import

| Tâche | Détail |
|-------|--------|
| Tab bar | Live, VOD, Favoris, Réglages (Guide masqué en MVP) |
| Import flow | Écran import : URL + fichier (.m3u) + validation |
| Playlist manager | Liste, renommer, supprimer |
| Live tab | Liste chaînes groupées par catégorie |
| Recherche | Barre de recherche incrémentale sur les chaînes |
| VOD tab | Liste des entrées non-live |
| Empty states | Pour chaque écran |

### Semaine 3 : Player

| Tâche | Détail |
|-------|--------|
| PlayerView | AVPlayer + contrôles custom overlay |
| Fullscreen player | Rotation, gestures volume/luminosité |
| Mini player | Barre en bas de l'app |
| Zapping | Navigation chaîne suivante/précédente |
| Gestion erreurs | Reconnexion auto, messages d'erreur |
| Historique | Dernières chaînes regardées |

### Semaine 4 : Onboarding & Polish

| Tâche | Détail |
|-------|--------|
| Onboarding flow | 3 écrans : Welcome → Disclaimer → Import |
| Favoris | Ajouter/retirer, onglet dédié |
| Dark mode | Thème sombre natif |
| Localisation FR/EN | Tous les strings |
| Settings basique | Liste playlists, À propos, Legal/DMCA |
| Réglages player | Ratio d'affichage basique |
| Bug fixes & stabilité | Tests manuels complets |

### Critères de sortie MVP
- [ ] Import M3U par URL et fichier fonctionne
- [ ] Parser gère 95% des formats M3U courants
- [ ] Player lit les flux HLS sans crash
- [ ] Favoris persistent entre sessions
- [ ] Onboarding + disclaimer affiché
- [ ] Fonctionne sur iPhone et iPad
- [ ] 0 crash sur les 10 playlists de test

---

## Itération 1 : v1.0 — App Store Ready (Semaines 5-8)

### Objectif
Version complète prête pour soumission App Store. EPG fonctionnel, paywall actif, parental control, PiP, accessibilité.

### Semaine 5 : EPG

| Tâche | Détail |
|-------|--------|
| CoreData model v2 | EPGSource, EPGChannel, EPGProgram |
| XMLTVParser | Parser streaming SAX-like pour gros fichiers |
| Tests XMLTVParser | 5+ cas de test |
| EPG import | Ajout source XMLTV par URL |
| EPG mapping | tvg-id exact → fuzzy matching → confidence score |
| Cache & refresh | Purge auto, refresh planifié |

### Semaine 6 : Guide TV & Collections

| Tâche | Détail |
|-------|--------|
| Guide tab | Grille horaire horizontale, navigation par date |
| Programme en cours | Affiché sur la carte chaîne (Live tab) |
| Détail programme | Sheet avec titre, description, horaires |
| Collections | Création, ajout chaînes cross-playlist |
| Mapping manuel EPG | UI de correction |
| QR code import | Scanner intégré (AVCaptureSession) |

### Semaine 7 : Premium & Monétisation

| Tâche | Détail |
|-------|--------|
| StoreKit 2 | Products, Purchase, Transaction listener |
| SubscriptionService | Vérification entitlements, cache status |
| Paywall screen | Comparaison Free vs Premium |
| Gating features | PiP, multi-playlist, EPG grille, parental |
| Restauration achats | Flow complet |
| PiP | AVPictureInPictureController |
| AirPlay | Activation native AVPlayer |

### Semaine 8 : Polish & Soumission

| Tâche | Détail |
|-------|--------|
| Parental control | PIN (Keychain), masquage catégories |
| iCloud sync | NSPersistentCloudKitContainer activation |
| Accessibilité | VoiceOver, Dynamic Type, contrastes |
| Clipboard monitor | Détection URL copiée → suggestion import |
| iPad split view | Sidebar + detail pour Live et Guide |
| OSLog + diagnostics | Logging structuré, export |
| App Store assets | Screenshots, description, keywords |
| Review Guidelines check | Vérification compliance point par point |
| TestFlight beta | Distribution externe |

### Critères de sortie v1.0
- [ ] EPG fonctionnel avec mapping intelligent
- [ ] Paywall + StoreKit 2 opérationnel
- [ ] PiP + AirPlay fonctionnels
- [ ] Parental control avec PIN
- [ ] iCloud sync playlists + favoris
- [ ] iPad layout optimisé
- [ ] Accessibilité VoiceOver complète
- [ ] 0 rejets App Store prévisibles
- [ ] Performance : < 3s ouverture, < 2s zapping
- [ ] 95%+ crash-free sessions

---

## Itération 2 : v1.5 — Killer Features (Semaines 9-12)

### Objectif
Différenciation concurrentielle. Features avancées qui justifient l'abonnement Premium.

### Semaine 9 : Shortcuts & Automatisation

| Tâche | Détail |
|-------|--------|
| AppIntents | "Play channel X", "Open favorites", "Switch to collection" |
| Shortcuts integration | Paramètres de chaîne, collection |
| CoreSpotlight | Indexation chaînes favorites pour recherche Spotlight |
| Quick Switch | Double tap → chaîne précédente |
| Favoris overlay | Accessible pendant la lecture |

### Semaine 10 : UX avancée

| Tâche | Détail |
|-------|--------|
| Mode Match | Interface épurée, gros contrôles |
| Multi-profils | Création profils (Famille/Enfants) |
| Thèmes visuels | 3-4 thèmes color + possibilité custom |
| Continue watching | Reprise VOD avec barre de progression |
| Audio/subtitles picker | Sélection piste audio + sous-titres |

### Semaine 11 : Robustesse & Data

| Tâche | Détail |
|-------|--------|
| Notifications EPG | Planification locale "début émission" |
| Export config | Chiffrement AES + partage |
| Détection doublons | Cross-playlist avec merge optionnel |
| Auto-refresh planifié | BackgroundTasks framework |
| Mode low data | Réduction refresh, compression logos |
| Vitesse lecture VOD | 0.5x → 2x |

### Semaine 12 : Polish final

| Tâche | Détail |
|-------|--------|
| Chromecast (si go) | Google Cast SDK intégration basique |
| Verrouillage écran | Lock tactile pendant lecture |
| Tests UI automatisés | XCUITest pour flows critiques |
| Performance profiling | Instruments : memory leaks, CPU, energy |
| Localisation review | Relecture FR/EN complète |
| Documentation interne | README, CONTRIBUTING, architecture ADRs |

### Critères de sortie v1.5
- [ ] Shortcuts iOS fonctionnels (3+ intents)
- [ ] Multi-profils opérationnel
- [ ] Notifications EPG fiables
- [ ] Continue watching VOD
- [ ] Performance stable sous charge (5+ playlists, 10k+ chaînes)
- [ ] Tests unitaires > 70% couverture parsers + services
- [ ] Tests UI pour onboarding + import + play

---

## Backlog post-v1.5

| Feature | Priorité | Notes |
|---------|----------|-------|
| Widget iOS | P2 | Programme en cours sur l'écran d'accueil |
| Live Activity | P2 | Programme en cours dans la Dynamic Island |
| watchOS companion | P3 | Contrôle lecture depuis Apple Watch |
| macOS (Catalyst/native) | P3 | Extension naturelle si demande |
| Catch-up / Timeshift | P3 | Si le flux le supporte |
| Recording (local) | P3 | Complexe légalement, à évaluer |
| Multi-screen | P3 | 2 flux simultanés sur iPad |
| Intégration HomeKit | P3 | Scènes "Soirée TV" |

---

## Métriques de succès

| Métrique | Cible MVP | Cible v1.0 | Cible v1.5 |
|----------|-----------|------------|------------|
| Crash-free sessions | > 95% | > 99% | > 99.5% |
| Time to first play | < 30s (depuis install) | < 20s | < 15s |
| Zapping time | < 3s | < 2s | < 1.5s |
| App Store rating | N/A | > 4.0 | > 4.5 |
| Premium conversion | N/A | > 5% | > 8% |
| MAU retention (30j) | N/A | > 40% | > 50% |
