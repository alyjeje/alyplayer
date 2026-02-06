# AlyPlayer — Product Specification

## 1. Vision produit

AlyPlayer est un lecteur IPTV premium pour iOS/iPadOS permettant à l'utilisateur d'importer et gérer ses propres flux M3U/M3U8 et guides EPG XMLTV. L'app ne fournit **aucun contenu** — elle est un outil de lecture neutre, conforme aux guidelines Apple.

**Positionnement :** Le lecteur IPTV le plus complet, stable et élégant de l'App Store.

---

## 2. Personas

| Persona | Description | Besoins clés |
|---------|-------------|--------------|
| **Technicien IPTV** | Utilise des playlists légitimes (opérateurs, auto-hébergés) | Import rapide, multi-playlists, EPG, stabilité |
| **Famille** | Partage un iPad, enfants présents | Multi-profils, parental control, UX simple |
| **Cord-cutter** | Abonné à des services IPTV légaux | Zapping rapide, favoris, PiP, AirPlay |
| **Power user** | Gère plusieurs sources, veut tout contrôler | Smart matching EPG, collections, Shortcuts iOS |

---

## 3. User Stories (par feature group)

### 3.1 Onboarding & Compliance

| ID | Story | Priorité |
|----|-------|----------|
| US-01 | En tant qu'utilisateur, je vois un écran d'accueil expliquant que l'app ne fournit aucun contenu | P0 |
| US-02 | Je dois accepter un disclaimer légal avant d'utiliser l'app | P0 |
| US-03 | Je peux accéder à une page "Legal / DMCA" depuis les réglages | P0 |
| US-04 | Je peux signaler un abus via "Report abuse" | P0 |
| US-05 | L'onboarding me guide en 3 étapes : Bienvenue → Disclaimer → Import première playlist | P0 |

### 3.2 Import & gestion des sources

| ID | Story | Priorité |
|----|-------|----------|
| US-10 | Je peux ajouter une playlist par URL (M3U/M3U8) | P0 |
| US-11 | Je peux importer un fichier .m3u/.m3u8 depuis Files/iCloud Drive | P0 |
| US-12 | Je peux coller une URL depuis le presse-papiers | P0 |
| US-13 | Je peux scanner un QR code contenant une URL playlist | P1 |
| US-14 | L'app valide la playlist (test connectivité, timeout 15s, retry 2x) | P0 |
| US-15 | Je peux gérer plusieurs playlists (ajouter, renommer, supprimer, réordonner) | P0 |
| US-16 | Je peux taguer mes playlists (couleur + label) | P1 |
| US-17 | L'app détecte les doublons entre playlists et propose un merge | P1 |
| US-18 | Je peux planifier la mise à jour automatique d'une playlist | P1 |
| US-19 | La mise à jour manuelle est disponible via pull-to-refresh | P0 |
| US-20 | Si je copie une URL M3U/EPG, l'app me suggère automatiquement de l'importer | P1 |
| US-21 | Premium : nombre illimité de playlists | P0 |

### 3.3 Chaînes / Navigation

| ID | Story | Priorité |
|----|-------|----------|
| US-30 | Les chaînes sont organisées par catégories (group-title du M3U) | P0 |
| US-31 | Je peux rechercher une chaîne instantanément (recherche incrémentale) | P0 |
| US-32 | Je peux trier : A-Z, récemment joué, favoris en premier | P0 |
| US-33 | Chaque chaîne affiche son logo (tvg-logo ou fallback) | P0 |
| US-34 | Je peux ajouter/retirer une chaîne des favoris (swipe ou bouton) | P0 |
| US-35 | Je vois le programme en cours (si EPG mappé) sur la carte de la chaîne | P1 |
| US-36 | Je peux importer manuellement un logo pour une chaîne | P2 |

### 3.4 VOD

| ID | Story | Priorité |
|----|-------|----------|
| US-40 | Les entrées VOD (non-live) du M3U sont séparées dans un onglet dédié | P0 |
| US-41 | Je vois un historique de lecture + reprise (continue watching) | P1 |
| US-42 | Je peux trier/filtrer les VOD par catégorie | P0 |

### 3.5 EPG / Guide TV

| ID | Story | Priorité |
|----|-------|----------|
| US-50 | Je peux ajouter une ou plusieurs sources EPG XMLTV par URL | P0 |
| US-51 | L'EPG est parsé et stocké localement avec cache intelligent | P0 |
| US-52 | Le guide affiche une grille horaire (timeline) par chaîne | P0 |
| US-53 | Je vois le programme en cours + suivant pour chaque chaîne | P0 |
| US-54 | Je peux voir le détail d'une émission (titre, description, horaires) | P1 |
| US-55 | Le mapping EPG ↔ chaînes utilise tvg-id/tvg-name + smart matching | P0 |
| US-56 | Je peux corriger manuellement un mapping EPG | P1 |
| US-57 | Je peux activer des notifications "début d'émission" | P2 |
| US-58 | Premium : EPG complet (grille, notifications) | P0 |

### 3.6 Lecteur vidéo

| ID | Story | Priorité |
|----|-------|----------|
| US-60 | Le lecteur utilise AVPlayer avec support HLS natif | P0 |
| US-61 | Zapping rapide : transition fluide entre chaînes (< 2s) | P0 |
| US-62 | Mini-player : je peux naviguer l'app avec le flux réduit | P0 |
| US-63 | Picture-in-Picture (PiP) natif iOS | P0 |
| US-64 | AirPlay vers Apple TV / enceintes | P0 |
| US-65 | Contrôles : play/pause, volume, luminosité (gestures) | P0 |
| US-66 | Sélection piste audio si plusieurs disponibles | P1 |
| US-67 | Sélection sous-titres si disponibles | P1 |
| US-68 | Ratio d'affichage : fit, fill, 4:3, 16:9 | P1 |
| US-69 | Vitesse de lecture (VOD) : 0.5x → 2x | P1 |
| US-70 | Reconnexion automatique en cas de coupure (3 tentatives) | P0 |
| US-71 | Messages d'erreur clairs + logs diagnostics | P0 |
| US-72 | Favorites overlay : liste des favoris accessible en 1 tap pendant la lecture | P1 |
| US-73 | Quick Switch : double tap pour revenir à la chaîne précédente | P1 |
| US-74 | Verrouillage rotation + verrouillage écran tactile | P1 |
| US-75 | Premium : PiP activé | P0 |

### 3.7 Parental Control

| ID | Story | Priorité |
|----|-------|----------|
| US-80 | Je peux activer un code PIN pour protéger certaines catégories | P1 |
| US-81 | Je peux masquer les catégories "adult" derrière le PIN | P1 |
| US-82 | Premium : parental control disponible | P1 |

### 3.8 Collections & Organisation

| ID | Story | Priorité |
|----|-------|----------|
| US-90 | Je peux créer des collections personnalisées ("Sport", "News", "Kids") | P1 |
| US-91 | Les collections agrègent des chaînes de différentes playlists | P1 |
| US-92 | Mode Match : interface épurée, gros bouton, zapping simplifié | P2 |

### 3.9 Réglages & Sync

| ID | Story | Priorité |
|----|-------|----------|
| US-100 | Sauvegarde/restauration iCloud (playlists, favoris, réglages) | P1 |
| US-101 | Mode "low data" (réduction refresh, pas de logos lourds) | P1 |
| US-102 | Export/import de configuration chiffré | P2 |
| US-103 | Intégration Shortcuts iOS ("Play channel X", "Open favorites") | P2 |
| US-104 | Thèmes visuels (Premium) | P2 |
| US-105 | Langue : FR / EN | P0 |

### 3.10 Monétisation

| ID | Story | Priorité |
|----|-------|----------|
| US-110 | Écran paywall clair montrant les avantages Premium | P0 |
| US-111 | Abonnement mensuel + annuel via StoreKit 2 | P0 |
| US-112 | Restauration des achats | P0 |
| US-113 | Gratuit : 1 playlist, pas d'EPG avancé, pas de PiP, pas multi-profils | P0 |

---

## 4. Écrans (Screen Map)

### 4.1 Onboarding Flow
```
[Welcome Screen] → [Disclaimer / Accept] → [Import First Playlist] → [Home]
```

### 4.2 Main Navigation (Tab Bar)
```
┌─────────────────────────────────────────────┐
│                 AlyPlayer                    │
├──────┬──────┬──────┬──────┬────────┤
│ Live │Guide │ VOD  │ Favs │Settings│
└──────┴──────┴──────┴──────┴────────┘
```

### 4.3 Screen Inventory

| # | Écran | Description |
|---|-------|-------------|
| S01 | Welcome | Logo + tagline + "Get Started" |
| S02 | Disclaimer | Legal text + checkbox "I agree" + Continue |
| S03 | First Import | URL field + "Or import file" + QR scan |
| S04 | Live Tab | Liste des chaînes par catégories, barre de recherche, programme en cours si EPG |
| S05 | Channel Detail | Info chaîne + logo + programme actuel/suivant + Play |
| S06 | Guide Tab | Grille EPG horizontale (timeline), navigation par date |
| S07 | Program Detail | Sheet : titre, description, horaire, bouton "Notify me" |
| S08 | VOD Tab | Grille/liste VOD par catégorie, recherche, continue watching |
| S09 | Favorites Tab | Liste des favoris, collections personnalisées |
| S10 | Settings Tab | Playlists, EPG, Apparence, Parental, iCloud, About, Legal |
| S11 | Playlist Manager | Liste des playlists + ajouter/éditer/supprimer |
| S12 | Add Playlist | URL / File / QR / Clipboard — validation + progress |
| S13 | EPG Manager | Liste sources EPG + ajouter/éditer |
| S14 | EPG Mapping | Liste chaînes sans mapping + correction manuelle |
| S15 | Player Fullscreen | Contrôles overlay, gestures, favoris overlay, quick switch |
| S16 | Mini Player | Barre en bas avec preview + contrôles min |
| S17 | Paywall | Feature comparison Free vs Premium + Subscribe |
| S18 | Parental Settings | PIN setup + sélection catégories à masquer |
| S19 | Legal / DMCA | Texte légal + Report abuse |
| S20 | About | Version, diagnostics export, liens |

### 4.4 iPad Layout

Sur iPad, les onglets Live et Guide utilisent un **split view** :
- **Colonne gauche** (sidebar) : catégories / liste de chaînes
- **Colonne droite** : player intégré ou détail chaîne

Le guide EPG est affiché en plein écran avec scroll horizontal (timeline).

---

## 5. États vides (Empty States)

Chaque écran sans données affiche un empty state travaillé :

| Écran | Illustration | Message | Action |
|-------|-------------|---------|--------|
| Live (pas de playlist) | 📺 icône | "No playlists yet" / "Aucune playlist" | "Add your first playlist" |
| Favorites (vide) | ⭐ icône | "No favorites yet" | "Browse channels and add some!" |
| Guide (pas d'EPG) | 📅 icône | "No TV guide configured" | "Add an EPG source in Settings" |
| VOD (vide) | 🎬 icône | "No VOD content" | "Your playlists don't contain VOD items" |
| Search (no results) | 🔍 icône | "No results for '...'" | "Try a different search term" |

---

## 6. Modèle économique détaillé

### Free Tier
- 1 playlist maximum
- Navigation chaînes + favoris
- Lecteur basique (pas de PiP)
- EPG : programme en cours uniquement (pas de grille)
- Pas de multi-profils
- Pas de parental control
- Pas de Shortcuts iOS
- Pas de sync iCloud

### Premium Tier (abonnement)
- Playlists illimitées
- EPG complet (grille, notifications)
- PiP
- Parental control + PIN
- Collections personnalisées
- Sync iCloud
- Shortcuts iOS
- Thèmes visuels
- Export configuration
- Support prioritaire

### Pricing (suggéré)
- Mensuel : 4,99 € / $4.99
- Annuel : 29,99 € / $29.99 (économie ~50%)
- Pas d'achat unique (revenu récurrent)
