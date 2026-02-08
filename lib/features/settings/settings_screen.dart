import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aly_player/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          // ─── Playlists ───
          _SectionHeader(title: l10n.playlists),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: Text(l10n.importPlaylist),
            onTap: () => context.push('/import'),
          ),
          ListTile(
            leading: const Icon(Icons.manage_search),
            title: Text(l10n.managePlaylists),
            onTap: () => _showManagePlaylists(context, ref),
          ),

          // ─── EPG ───
          _SectionHeader(title: l10n.epg),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(l10n.epgSources),
            onTap: () => _showManageEpgSources(context, ref),
          ),

          // ─── Appearance ───
          _SectionHeader(title: l10n.appearance),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: Text(l10n.theme),
            subtitle: Text(l10n.systemDefault),
            onTap: () => _showThemePicker(context),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(_localeDisplayName(currentLocale, l10n)),
            onTap: () => _showLanguagePicker(context, ref),
          ),

          // ─── Subscription ───
          _SectionHeader(title: l10n.subscription),
          ListTile(
            leading: const Icon(Icons.star),
            title: Text(l10n.upgradePremium),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/paywall'),
          ),

          // ─── About ───
          _SectionHeader(title: l10n.about),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.version),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacyPolicy),
            onTap: () => _launchUrl('https://alyplayer.app/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.termsOfService),
            onTap: () => _launchUrl('https://alyplayer.app/terms'),
          ),

          // ─── Compliance ───
          _SectionHeader(title: l10n.legal),
          ListTile(
            leading: Icon(Icons.flag_outlined, color: theme.colorScheme.error),
            title: Text(l10n.reportAbuse),
            onTap: () => _launchUrl('mailto:abuse@alyplayer.app?subject=Report%20Abuse'),
          ),
          ListTile(
            leading: const Icon(Icons.gavel),
            title: Text(l10n.dmcaPolicy),
            onTap: () => _launchUrl('https://alyplayer.app/dmca'),
          ),

          // ─── Danger Zone ───
          _SectionHeader(title: ''),
          ListTile(
            leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
            title: Text(l10n.clearData,
                style: TextStyle(color: theme.colorScheme.error)),
            onTap: () => _showClearDataConfirm(context, ref),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _localeDisplayName(Locale? locale, AppLocalizations l10n) {
    if (locale == null) return l10n.systemDefault;
    return switch (locale.languageCode) {
      'en' => l10n.english,
      'fr' => l10n.french,
      _ => l10n.systemDefault,
    };
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.language),
        children: [
          SimpleDialogOption(
            onPressed: () {
              ref.read(localeProvider.notifier).setLocale(null);
              Navigator.pop(ctx);
            },
            child: Text(l10n.systemDefault),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('en'));
              Navigator.pop(ctx);
            },
            child: Text(l10n.english),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref.read(localeProvider.notifier).setLocale(const Locale('fr'));
              Navigator.pop(ctx);
            },
            child: Text(l10n.french),
          ),
        ],
      ),
    );
  }

  void _showManagePlaylists(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollController) => Consumer(
          builder: (context, ref, _) {
            final playlists = ref.watch(playlistsProvider);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l10n.managePlaylists,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Expanded(
                  child: playlists.when(
                    data: (list) {
                      if (list.isEmpty) {
                        return Center(child: Text(l10n.noChannels));
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final pl = list[i];
                          return ListTile(
                            title: Text(pl.name),
                            subtitle: Text(l10n.channelCount(pl.channelCount)),
                            trailing: IconButton(
                              icon: Icon(Icons.delete,
                                  color: Theme.of(context).colorScheme.error),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(l10n.delete),
                                    content: Text(l10n.deletePlaylistConfirm),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: Text(l10n.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: Text(l10n.delete),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await ref
                                      .read(playlistServiceProvider)
                                      .deletePlaylist(pl.id);
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showManageEpgSources(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollController) => Consumer(
          builder: (context, ref, _) {
            final sources = ref.watch(epgSourcesProvider);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.epgSources,
                          style: Theme.of(context).textTheme.titleLarge),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddEpgSourceDialog(context, ref);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: sources.when(
                    data: (list) {
                      if (list.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(l10n.noEpgSources),
                              const SizedBox(height: 12),
                              FilledButton.tonal(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showAddEpgSourceDialog(context, ref);
                                },
                                child: Text(l10n.addEpgSource),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final src = list[i];
                          return ListTile(
                            title: Text(src.name),
                            subtitle: Text(src.url,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              icon: Icon(Icons.delete,
                                  color: Theme.of(context).colorScheme.error),
                              onPressed: () => ref
                                  .read(epgServiceProvider)
                                  .deleteSource(src.id),
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('$e')),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAddEpgSourceDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addEpgSource),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                  labelText: 'XMLTV URL',
                  hintText: 'https://example.com/epg.xml'),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || urlCtrl.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(ctx);
              await ref
                  .read(epgServiceProvider)
                  .addSource(nameCtrl.text.trim(), urlCtrl.text.trim());
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.theme),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.systemDefault),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.light),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.dark),
          ),
        ],
      ),
    );
  }

  void _showClearDataConfirm(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearData),
        content: Text(l10n.clearDataConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              // Delete all playlists (cascade deletes channels)
              ref.read(databaseProvider).getAllPlaylists().then((playlists) {
                for (final p in playlists) {
                  ref.read(databaseProvider).deletePlaylistById(p.id);
                }
              });
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty) return const SizedBox(height: 16);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
