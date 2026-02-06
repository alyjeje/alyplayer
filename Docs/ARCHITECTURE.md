# AlyPlayer — Architecture Technique (Flutter)

## 1. Décisions techniques tranchées

### Pourquoi Flutter

- Développement depuis PC (Windows) → Swift/Xcode impossible.
- Flutter cible iOS + Android avec un seul codebase.
- Performance native via compilation AOT, rendu Impeller.
- Écosystème mature pour le media playback (media_kit, video_player).
- Hot reload pour itération rapide.

### Storage : SQLite via drift

**Choix : drift** (anciennement moor) — wrapper SQLite type-safe pour Dart.

**Justifications :**
- **Type-safe** : requêtes vérifiées à la compilation, pas de SQL brut fragile.
- **Réactif** : `watch()` retourne des `Stream<List<T>>` → parfait avec Riverpod.
- **Migrations** : système de migration intégré et versionné.
- **Performance** : SQLite natif via FFI, batch inserts pour parsing M3U/EPG massif.
- **Cross-platform** : fonctionne sur iOS, Android, desktop.

**Alternatives écartées :**
- Hive : NoSQL, pas adapté aux relations Playlist → Channel → EPG.
- Isar : abandonné.
- sqflite : trop bas niveau, pas de type-safety.

### State Management : Riverpod

**Choix : Riverpod v2** (flutter_riverpod).

**Justifications :**
- Compile-safe, pas de `BuildContext` requis pour accéder aux providers.
- Supporte async nativement (FutureProvider, StreamProvider).
- Auto-dispose des ressources.
- Testable (ProviderContainer pour override en test).

### Video Player : media_kit

**Choix : media_kit** — wrapper MPV/libmpv pour Flutter.

**Justifications :**
- Support HLS natif et robuste (meilleur que video_player pour IPTV).
- Gestion des pistes audio/sous-titres.
- Hardware decoding.
- Activement maintenu.

### EPG : Cache + refresh

- Stockage en SQLite via drift.
- Cache 7 jours, purge auto des programmes passés.
- Refresh : manuel + auto toutes les 6h.
- Parsing XML via `xml` package.

### Chromecast / AirPlay

- AirPlay : géré nativement côté iOS par media_kit.
- Chromecast : reporté v1.5.

### Xtream Codes : Non mentionné

- Pas de branding "Xtream Codes".
- Support M3U générique uniquement.

---

## 2. Architecture globale

```
┌─────────────────────────────────────────────────┐
│                 Flutter Widgets                   │
│  (Features: Live, Guide, VOD, Favorites, etc.)  │
├─────────────────────────────────────────────────┤
│              Riverpod Providers                   │
│  (StateNotifier, AsyncNotifier, StreamProvider)  │
├─────────────────────────────────────────────────┤
│                   Services                        │
│  PlaylistService · EPGService · PlayerService    │
│  SubscriptionService                             │
├─────────────────────────────────────────────────┤
│                 Data Layer                        │
│  drift Database (SQLite)                         │
├─────────────────────────────────────────────────┤
│                 Parsers                           │
│  M3UParser · XMLTVParser                         │
├─────────────────────────────────────────────────┤
│              Platform Plugins                     │
│  media_kit · in_app_purchase · file_picker       │
│  mobile_scanner · path_provider · share_plus     │
└─────────────────────────────────────────────────┘
```

---

## 3. Modèle de données

Tables drift : playlists, channels, epg_sources, epg_programs, collections, collection_channels.

Relations : Playlist 1→N Channel, EpgSource 1→N EpgProgram, Collection N→N Channel.

---

## 4. Dépendances

| Package | Usage |
|---------|-------|
| `flutter_riverpod` | State management |
| `go_router` | Navigation |
| `drift` + `sqlite3_flutter_libs` | Database |
| `media_kit` + platform libs | Video HLS |
| `in_app_purchase` | IAP |
| `file_picker` | Import fichier M3U |
| `mobile_scanner` | QR code |
| `xml` | XMLTV parsing |
| `cached_network_image` | Logos |
| `shared_preferences` | Prefs simples |
| `url_launcher` | Liens |
| `share_plus` | Export |
| `path_provider` | Chemins |
| `intl` | i18n |

Zéro Firebase, zéro GetX, zéro bloc.

---

## 5. Internationalisation

- Format ARB via `flutter_localizations` + `intl`.
- 2 langues : EN (défaut) + FR.
- Généré via `flutter gen-l10n`.
