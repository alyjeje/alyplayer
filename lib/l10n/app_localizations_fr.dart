// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'AlyPlayer';

  @override
  String get liveTV => 'TV en direct';

  @override
  String get guide => 'Guide';

  @override
  String get vod => 'VOD';

  @override
  String get favorites => 'Favoris';

  @override
  String get settings => 'Paramètres';

  @override
  String get channels => 'Chaînes';

  @override
  String get collections => 'Collections';

  @override
  String get all => 'Tout';

  @override
  String get search => 'Rechercher';

  @override
  String get searchChannels => 'Rechercher des chaînes...';

  @override
  String get searchVod => 'Rechercher films et séries...';

  @override
  String get noChannels => 'Aucune chaîne';

  @override
  String get noVodContent => 'Aucun contenu VOD';

  @override
  String get noFavorites => 'Aucun favori';

  @override
  String get noFavoritesHint =>
      'Appuyez sur le cœur d\'une chaîne pour l\'ajouter ici';

  @override
  String get noCollections => 'Aucune collection';

  @override
  String get noEpgSources => 'Aucune source EPG configurée';

  @override
  String get addEpgSource => 'Ajouter une source EPG';

  @override
  String get error => 'Erreur';

  @override
  String get retry => 'Réessayer';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get done => 'Terminé';

  @override
  String get back => 'Retour';

  @override
  String get next => 'Suivant';

  @override
  String get getStarted => 'Commencer';

  @override
  String get welcomeTitle => 'Bienvenue sur AlyPlayer';

  @override
  String get welcomeSubtitle =>
      'Votre lecteur multimédia personnel pour la TV en direct et le contenu à la demande';

  @override
  String get disclaimerTitle => 'Avis important';

  @override
  String get disclaimerBody =>
      'AlyPlayer est uniquement un lecteur multimédia. Il ne fournit, n\'héberge ni ne distribue aucun contenu. Vous êtes seul responsable du contenu auquel vous accédez. Veuillez vous assurer que vous avez le droit légal de visionner tout contenu que vous ajoutez à cette application.';

  @override
  String get disclaimerAccept =>
      'Je confirme que j\'utiliserai uniquement du contenu auquel j\'ai légalement le droit d\'accéder';

  @override
  String get quickStartTitle => 'Ajoutez votre contenu';

  @override
  String get quickStartSubtitle =>
      'Importez votre playlist via URL, fichier ou QR code pour commencer';

  @override
  String get importPlaylist => 'Importer une playlist';

  @override
  String get importFromUrl => 'Importer depuis une URL';

  @override
  String get importFromFile => 'Importer depuis un fichier';

  @override
  String get importFromQr => 'Importer depuis un QR Code';

  @override
  String get importButton => 'Importer';

  @override
  String get importSuccess => 'Playlist importée avec succès';

  @override
  String get importError => 'Échec de l\'import';

  @override
  String get selectFile => 'Sélectionner un fichier';

  @override
  String get scanQrCode => 'Scanner un QR Code';

  @override
  String get paste => 'Coller';

  @override
  String get managePlaylists => 'Gérer les playlists';

  @override
  String get epg => 'EPG';

  @override
  String get epgSources => 'Sources EPG';

  @override
  String get appearance => 'Apparence';

  @override
  String get theme => 'Thème';

  @override
  String get systemDefault => 'Système par défaut';

  @override
  String get light => 'Clair';

  @override
  String get dark => 'Sombre';

  @override
  String get subscription => 'Abonnement';

  @override
  String get upgradePremium => 'Passer à Premium';

  @override
  String get premium => 'Premium';

  @override
  String get unlockPremium => 'Débloquer Premium';

  @override
  String get premiumDescription =>
      'Profitez au maximum d\'AlyPlayer avec les fonctionnalités premium';

  @override
  String get monthly => 'Mensuel';

  @override
  String get yearly => 'Annuel';

  @override
  String get perMonth => 'par mois';

  @override
  String get perYear => 'par an';

  @override
  String get save50 => '-50%';

  @override
  String get restorePurchases => 'Restaurer les achats';

  @override
  String get subscriptionDisclaimer =>
      'Le paiement sera prélevé sur votre compte App Store. L\'abonnement se renouvelle automatiquement sauf annulation au moins 24 heures avant la fin de la période en cours.';

  @override
  String get featureUnlimitedPlaylists => 'Playlists illimitées';

  @override
  String get featureExternalPlayer => 'Lecteur externe';

  @override
  String get featurePiP => 'Picture-in-Picture';

  @override
  String get featureParentalControls => 'Contrôle parental';

  @override
  String get featureCloudBackup => 'Sauvegarde et synchronisation cloud';

  @override
  String get featureNoAds => 'Sans publicité';

  @override
  String get about => 'À propos';

  @override
  String get version => 'Version';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get termsOfService => 'Conditions d\'utilisation';

  @override
  String get legal => 'Mentions légales';

  @override
  String get reportAbuse => 'Signaler un abus';

  @override
  String get dmcaPolicy => 'Politique DMCA';

  @override
  String get playlists => 'Playlists';

  @override
  String get playlistName => 'Nom de la playlist';

  @override
  String get playlistUrl => 'URL de la playlist';

  @override
  String get loading => 'Chargement...';

  @override
  String get refreshing => 'Actualisation...';

  @override
  String lastUpdated(String date) {
    return 'Dernière mise à jour : $date';
  }

  @override
  String channelCount(int count) {
    return '$count chaînes';
  }

  @override
  String get deletePlaylistConfirm =>
      'Êtes-vous sûr de vouloir supprimer cette playlist ? Toutes les chaînes associées seront supprimées.';

  @override
  String get nowPlaying => 'En cours';

  @override
  String get upNext => 'À suivre';

  @override
  String get noCurrentProgram => 'Aucune info programme disponible';

  @override
  String get parentalControlPin => 'Code parental';

  @override
  String get setPin => 'Définir le code';

  @override
  String get enterPin => 'Entrer le code';

  @override
  String get incorrectPin => 'Code incorrect';

  @override
  String get autoRefresh => 'Actualisation auto';

  @override
  String get refreshInterval => 'Intervalle d\'actualisation';

  @override
  String hours(int count) {
    return '$count heures';
  }

  @override
  String get exportConfig => 'Exporter la configuration';

  @override
  String get importConfig => 'Importer la configuration';

  @override
  String get clearData => 'Effacer toutes les données';

  @override
  String get clearDataConfirm =>
      'Cela supprimera toutes les playlists, chaînes, favoris et paramètres. Cette action est irréversible.';

  @override
  String get recentlyWatched => 'Regardé récemment';

  @override
  String get continueWatching => 'Reprendre la lecture';

  @override
  String get categoryAll => 'Tout';

  @override
  String get sortByName => 'Trier par nom';

  @override
  String get sortByRecent => 'Trier par récent';

  @override
  String get sortByGroup => 'Trier par groupe';
}
