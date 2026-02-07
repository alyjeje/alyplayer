// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AlyPlayer';

  @override
  String get home => 'Home';

  @override
  String get liveTV => 'Live TV';

  @override
  String get films => 'Films';

  @override
  String get series => 'Series';

  @override
  String get favorites => 'Favorites';

  @override
  String get settings => 'Settings';

  @override
  String get channels => 'Channels';

  @override
  String get collections => 'Collections';

  @override
  String get all => 'All';

  @override
  String get search => 'Search';

  @override
  String get searchChannels => 'Search channels...';

  @override
  String get searchFilms => 'Search films...';

  @override
  String get searchSeries => 'Search series...';

  @override
  String get noChannels => 'No channels yet';

  @override
  String get noFilms => 'No films yet';

  @override
  String get noSeries => 'No series yet';

  @override
  String get noFavorites => 'No favorites yet';

  @override
  String get noFavoritesHint =>
      'Tap the heart icon on any channel to add it here';

  @override
  String get noCollections => 'No collections yet';

  @override
  String get noEpgSources => 'No EPG sources configured';

  @override
  String get addEpgSource => 'Add EPG Source';

  @override
  String get season => 'Season';

  @override
  String get episode => 'Episode';

  @override
  String get noEpisodes => 'No episodes found';

  @override
  String get trendingSeries => 'Trending Series';

  @override
  String get trendingFilms => 'Trending Films';

  @override
  String seasonEpisode(int season, int episode) {
    return 'S${season}E$episode';
  }

  @override
  String episodes(int count) {
    return '$count episodes';
  }

  @override
  String seasons(int count) {
    return '$count seasons';
  }

  @override
  String get serverUrl => 'Server URL';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get connect => 'Connect';

  @override
  String get directUrl => 'Direct URL';

  @override
  String get xtreamCodes => 'Xtream Codes';

  @override
  String get authFailed => 'Authentication failed';

  @override
  String get importMethod => 'Import Method';

  @override
  String get error => 'Error';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get done => 'Done';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get Started';

  @override
  String get welcomeTitle => 'Welcome to AlyPlayer';

  @override
  String get welcomeSubtitle =>
      'Your personal media player for live TV and on-demand content';

  @override
  String get disclaimerTitle => 'Important Notice';

  @override
  String get disclaimerBody =>
      'AlyPlayer is a media player only. It does not provide, host, or distribute any content. You are solely responsible for the content you access. Please ensure you have the legal right to view any content you add to this app.';

  @override
  String get disclaimerAccept =>
      'I confirm that I will only use content I have the legal right to access';

  @override
  String get quickStartTitle => 'Add Your Content';

  @override
  String get quickStartSubtitle =>
      'Import your playlist via URL, file, or QR code to get started';

  @override
  String get importPlaylist => 'Import Playlist';

  @override
  String get importFromUrl => 'Import from URL';

  @override
  String get importFromFile => 'Import from File';

  @override
  String get importFromQr => 'Import from QR Code';

  @override
  String get importButton => 'Import';

  @override
  String get importSuccess => 'Playlist imported successfully';

  @override
  String get importError => 'Import failed';

  @override
  String get selectFile => 'Select File';

  @override
  String get scanQrCode => 'Scan QR Code';

  @override
  String get paste => 'Paste';

  @override
  String get managePlaylists => 'Manage Playlists';

  @override
  String get epg => 'EPG';

  @override
  String get epgSources => 'EPG Sources';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get systemDefault => 'System default';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get subscription => 'Subscription';

  @override
  String get upgradePremium => 'Upgrade to Premium';

  @override
  String get premium => 'Premium';

  @override
  String get unlockPremium => 'Unlock Premium';

  @override
  String get premiumDescription =>
      'Get the most out of AlyPlayer with premium features';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String get perMonth => 'per month';

  @override
  String get perYear => 'per year';

  @override
  String get save50 => 'Save 50%';

  @override
  String get restorePurchases => 'Restore Purchases';

  @override
  String get subscriptionDisclaimer =>
      'Payment will be charged to your App Store account. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.';

  @override
  String get featureUnlimitedPlaylists => 'Unlimited playlists';

  @override
  String get featureExternalPlayer => 'External player support';

  @override
  String get featurePiP => 'Picture-in-Picture';

  @override
  String get featureParentalControls => 'Parental controls';

  @override
  String get featureCloudBackup => 'Cloud backup & sync';

  @override
  String get featureNoAds => 'Ad-free experience';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get legal => 'Legal';

  @override
  String get reportAbuse => 'Report Abuse';

  @override
  String get dmcaPolicy => 'DMCA Policy';

  @override
  String get playlists => 'Playlists';

  @override
  String get playlistName => 'Playlist Name';

  @override
  String get playlistUrl => 'Playlist URL';

  @override
  String get loading => 'Loading...';

  @override
  String get refreshing => 'Refreshing...';

  @override
  String lastUpdated(String date) {
    return 'Last updated: $date';
  }

  @override
  String channelCount(int count) {
    return '$count channels';
  }

  @override
  String get deletePlaylistConfirm =>
      'Are you sure you want to delete this playlist? All associated channels will be removed.';

  @override
  String get nowPlaying => 'Now Playing';

  @override
  String get upNext => 'Up Next';

  @override
  String get noCurrentProgram => 'No program info available';

  @override
  String get parentalControlPin => 'Parental Control PIN';

  @override
  String get setPin => 'Set PIN';

  @override
  String get enterPin => 'Enter PIN';

  @override
  String get incorrectPin => 'Incorrect PIN';

  @override
  String get autoRefresh => 'Auto Refresh';

  @override
  String get refreshInterval => 'Refresh Interval';

  @override
  String hours(int count) {
    return '$count hours';
  }

  @override
  String get exportConfig => 'Export Configuration';

  @override
  String get importConfig => 'Import Configuration';

  @override
  String get clearData => 'Clear All Data';

  @override
  String get clearDataConfirm =>
      'This will delete all playlists, channels, favorites, and settings. This action cannot be undone.';

  @override
  String get recentlyWatched => 'Recently Watched';

  @override
  String get continueWatching => 'Continue Watching';

  @override
  String get categoryAll => 'All';

  @override
  String get sortByName => 'Sort by Name';

  @override
  String get sortByRecent => 'Sort by Recent';

  @override
  String get sortByGroup => 'Sort by Group';
}
