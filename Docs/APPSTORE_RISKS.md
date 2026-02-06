# AlyPlayer — Risques App Store & Stratégie de Conformité

## 1. Risques identifiés & mitigations

### RISQUE 1 : Association avec le piratage IPTV (CRITIQUE)

**Guideline** : 5.2.3 — Apps should not facilitate illegal file sharing or piracy.

**Risque** : Apple rejette régulièrement les apps IPTV soupçonnées de faciliter l'accès à du contenu piraté.

**Mitigations** :
- ❌ JAMAIS de contenu, playlist, lien ou catalogue intégré
- ❌ JAMAIS de mention "Xtream Codes", "IPTV gratuit", "free channels"
- ❌ JAMAIS de suggestion de sources, de liste de fournisseurs, de liens
- ❌ JAMAIS de scraping web pour trouver des playlists
- ✅ Disclaimer obligatoire au premier lancement (voir texte ci-dessous)
- ✅ Wording neutre : "media player", "playlist manager", "stream player"
- ✅ Bouton "Report Abuse" visible dans les réglages
- ✅ Page Legal / DMCA avec procédure de signalement

### RISQUE 2 : Metadata App Store suspecte (ÉLEVÉ)

**Guideline** : 2.3 — Accurate Metadata

**Risque** : Utiliser des mots-clés comme "IPTV", "free TV", "live TV" dans le titre ou la description.

**Mitigations** :
- Titre App Store : **"AlyPlayer — Stream Player"** (pas "IPTV" dans le titre)
- Sous-titre : "M3U Playlist & EPG Manager"
- Description : focus sur les fonctionnalités techniques (parser, player, EPG)
- Keywords : "m3u player, playlist manager, stream player, epg guide, hls player"
- ❌ Éviter : "IPTV", "TV gratuite", "free channels", "live TV", "cable", "satellite"

### RISQUE 3 : Contenu User-Generated non modéré (MOYEN)

**Guideline** : 1.2 — User-Generated Content

**Risque** : L'app permet d'importer n'importe quelle URL, donc potentiellement du contenu illégal.

**Mitigations** :
- L'app ne stocke pas et ne redistribue pas le contenu — elle lit un flux
- Disclaimer clair que l'utilisateur est responsable de ses sources
- Pas de partage de playlists entre utilisateurs dans l'app
- Export config chiffré (pas de partage en clair d'URLs)
- "Report Abuse" pour signaler un usage abusif (email vers l'éditeur)

### RISQUE 4 : Rejection pour "limited functionality" (MOYEN)

**Guideline** : 4.2 — Minimum Functionality

**Risque** : Sans playlist, l'app est "vide". Apple peut juger qu'elle n'a pas assez de fonctionnalités.

**Mitigations** :
- Onboarding guidé qui mène rapidement à l'import
- Empty states travaillés avec aide contextuelle
- Features riches même en version gratuite (player, favoris, recherche)
- Pour la review Apple : fournir une playlist de test M3U valide dans les "Review Notes"
- Préparer un compte demo avec playlist de test (streams publics/légaux)

### RISQUE 5 : In-App Purchase implementation (FAIBLE)

**Guideline** : 3.1 — Payments

**Risque** : Mauvaise implémentation StoreKit, paywall trop agressif.

**Mitigations** :
- StoreKit 2 (API moderne recommandée par Apple)
- Restauration des achats facilement accessible
- Version gratuite fonctionnelle (pas juste un teaser)
- Paywall non bloquant au lancement (l'utilisateur peut utiliser l'app free d'abord)

### RISQUE 6 : Privacy & Data Collection (FAIBLE)

**Guideline** : 5.1 — Privacy

**Mitigations** :
- Pas de tracking, pas d'analytics tierces (v1)
- Pas de collecte de données personnelles
- Privacy Nutrition Label : "Data Not Collected"
- Privacy Policy URL obligatoire (à créer)
- Données stockées on-device + iCloud (user-controlled)

---

## 2. Textes pré-rédigés

### 2.1 Disclaimer Onboarding (EN)

```
IMPORTANT NOTICE

AlyPlayer is a media player application. It does not provide, host,
or distribute any media content, channels, or streams.

You are solely responsible for the content you access through this app.
By using AlyPlayer, you confirm that:

• You own or have legal rights to access the streams you add
• You will not use this app to access unauthorized or pirated content
• You understand that AlyPlayer has no control over third-party streams

By tapping "I Agree", you accept these terms and our Terms of Service.
```

### 2.2 Disclaimer Onboarding (FR)

```
NOTICE IMPORTANTE

AlyPlayer est une application de lecture multimédia. Elle ne fournit,
n'héberge ni ne distribue aucun contenu, chaîne ou flux.

Vous êtes seul responsable du contenu auquel vous accédez via cette app.
En utilisant AlyPlayer, vous confirmez que :

• Vous possédez ou avez les droits légaux d'accès aux flux que vous ajoutez
• Vous n'utiliserez pas cette app pour accéder à du contenu non autorisé ou piraté
• Vous comprenez qu'AlyPlayer n'a aucun contrôle sur les flux tiers

En appuyant sur « J'accepte », vous acceptez ces conditions et nos
Conditions d'utilisation.
```

### 2.3 App Store Description (EN)

```
AlyPlayer — Stream Player

Your premium M3U playlist manager and media stream player.

AlyPlayer lets you organize and play your own media playlists with a
beautiful, intuitive interface designed for iPhone and iPad.

FEATURES:
• Import M3U/M3U8 playlists from URL, files, or QR codes
• Organize channels by categories with instant search
• Powerful HLS player with Picture-in-Picture support
• Electronic Program Guide (EPG) with XMLTV support
• Favorites, collections, and watch history
• AirPlay streaming to Apple TV
• iCloud sync across your devices
• Parental controls with PIN protection
• Dark mode and accessibility support

AlyPlayer does not provide any media content. You must supply your own
playlists and have the legal right to access the streams they contain.

PREMIUM SUBSCRIPTION:
• Unlimited playlists
• Full EPG guide with timeline
• Picture-in-Picture
• iCloud sync
• Parental controls
• iOS Shortcuts integration

Subscriptions are billed monthly ($4.99/month) or annually ($29.99/year).
Payment is charged to your Apple ID account. Subscriptions automatically
renew unless cancelled at least 24 hours before the end of the current
period. Manage subscriptions in your Apple ID Account Settings.

Privacy Policy: [URL]
Terms of Service: [URL]
```

### 2.4 App Store Review Notes

```
Thank you for reviewing AlyPlayer.

This app is a media playlist manager and player. It does not provide
any content. Users import their own M3U playlists.

FOR TESTING:
Please use the following test playlist URL to evaluate the app:
[Insert public/legal test M3U URL here — e.g., a playlist of
freely available public domain streams]

The app requires the user to accept a legal disclaimer before use,
confirming they have rights to the streams they import.

If you have any questions, please contact us at: [support email]
```

### 2.5 Legal / DMCA Page (EN)

```
LEGAL NOTICE & DMCA

AlyPlayer is a media player application developed by [Company Name].
We do not host, store, or distribute any media content.

INTELLECTUAL PROPERTY:
AlyPlayer respects intellectual property rights. We expect our users
to do the same.

DMCA / COPYRIGHT CLAIMS:
If you believe that content accessed through our application infringes
your copyright, please note that AlyPlayer does not control, host,
or provide any media streams. Users are responsible for the content
they access.

However, if you wish to report an issue related to our application,
please contact us at:

Email: legal@[domain].com
Subject: DMCA Notice — AlyPlayer

Please include:
1. Description of the copyrighted work
2. Description of the infringing activity
3. Your contact information
4. A statement of good faith

REPORT ABUSE:
If you are aware of this app being used to access unauthorized content,
please report it to: abuse@[domain].com

TERMS OF SERVICE: [URL]
PRIVACY POLICY: [URL]
```

---

## 3. Checklist pré-soumission App Store

- [ ] Aucune mention de "IPTV" dans le titre ou sous-titre
- [ ] Description App Store neutre, focus fonctionnalités
- [ ] Keywords ne contiennent pas "free TV", "IPTV", "cable"
- [ ] Disclaimer onboarding affiché au premier lancement
- [ ] Bouton "I Agree" requis avant utilisation
- [ ] Page Legal / DMCA accessible depuis Settings
- [ ] Bouton "Report Abuse" visible
- [ ] Pas de playlist, chaîne ou contenu pré-chargé
- [ ] Pas de lien vers des sources de contenu
- [ ] Pas de scraping web
- [ ] Privacy Nutrition Label : "Data Not Collected"
- [ ] Privacy Policy URL valide
- [ ] Terms of Service URL valide
- [ ] Review Notes avec playlist de test légale
- [ ] Compte de test si nécessaire
- [ ] StoreKit 2 : restauration achats fonctionnelle
- [ ] Version gratuite fonctionnelle (pas un placeholder)
- [ ] Screenshots ne montrent pas de contenu sous copyright
- [ ] Screenshots utilisent des noms de chaînes fictifs

---

## 4. Stratégie en cas de rejet

### Premier rejet
1. Lire attentivement le motif de rejet
2. Répondre dans Resolution Center (pas d'appel immédiat)
3. Ajuster le wording/metadata si demandé
4. Re-soumettre avec une note expliquant les changements

### Si rejet persistant (guideline 5.2.3)
1. Demander un appel téléphonique avec l'équipe de review
2. Préparer un argumentaire :
   - L'app est un player neutre (comme VLC, Infuse, nPlayer)
   - VLC est sur l'App Store et lit les mêmes formats
   - L'app n'a aucune fonctionnalité de découverte de contenu
   - Comparaison avec des apps similaires approuvées
3. Si nécessaire, renommer l'app pour éviter toute connotation
4. Envisager l'App Review Board appeal en dernier recours

### Apps de référence approuvées (même catégorie)
- VLC for Mobile (lecture M3U, HLS)
- Infuse (lecteur multimédia premium)
- nPlayer (lecteur réseau)
- IINA (macOS, même concept)
- GSE Smart IPTV (a été sur l'App Store longtemps)
- Flex IPTV (actuellement sur l'App Store)
