import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aly_player/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../core/providers/providers.dart';
import '../../core/database/database.dart';

class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key});

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  late DateTime _selectedDate;
  final _dateFormat = DateFormat('EEE d');
  final _timeFormat = DateFormat('HH:mm');
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  List<DateTime> get _dates {
    final today = DateTime.now();
    return List.generate(
        7, (i) => DateTime(today.year, today.month, today.day + i));
  }

  Future<void> _refreshEpg() async {
    setState(() => _isRefreshing = true);
    try {
      await ref.read(epgServiceProvider).refreshAllSources();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _showAddSourceDialog() {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addEpgSource),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'My EPG Source',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'XMLTV URL',
                hintText: 'https://example.com/epg.xml',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final url = urlController.text.trim();
              if (name.isEmpty || url.isEmpty) return;
              Navigator.pop(ctx);
              await ref.read(epgServiceProvider).addSource(name, url);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final epgSourcesAsync = ref.watch(epgSourcesProvider);
    final liveChannelsAsync = ref.watch(liveChannelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.epg),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshEpg,
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddSourceDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _dates.map((d) {
                final isSelected = d.day == _selectedDate.day &&
                    d.month == _selectedDate.month;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(_dateFormat.format(d)),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedDate = d),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          // Content
          Expanded(
            child: epgSourcesAsync.when(
              data: (sources) {
                if (sources.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(l10n.noEpgSources),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: _showAddSourceDialog,
                          child: Text(l10n.addEpgSource),
                        ),
                      ],
                    ),
                  );
                }
                // Show channels with their EPG data
                return liveChannelsAsync.when(
                  data: (channels) {
                    if (channels.isEmpty) {
                      return Center(child: Text(l10n.noCurrentProgram));
                    }
                    return ListView.builder(
                      itemCount: channels.length,
                      itemBuilder: (context, i) {
                        final channel = channels[i];
                        return _ChannelEpgTile(
                          channel: channel,
                          selectedDate: _selectedDate,
                          timeFormat: _timeFormat,
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('${l10n.error}: $e')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('${l10n.error}: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelEpgTile extends ConsumerWidget {
  final Channel channel;
  final DateTime selectedDate;
  final DateFormat timeFormat;

  const _ChannelEpgTile({
    required this.channel,
    required this.selectedDate,
    required this.timeFormat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tvgId = channel.tvgId;
    if (tvgId == null) {
      return ListTile(
        title: Text(channel.name),
        subtitle: Text(AppLocalizations.of(context)!.noCurrentProgram,
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
    }

    final programsAsync = ref.watch(
      StreamProvider<List<EpgProgram>>((ref) {
        final db = ref.watch(databaseProvider);
        return db.watchProgramsForChannel(tvgId, selectedDate);
      }),
    );

    return programsAsync.when(
      data: (programs) {
        if (programs.isEmpty) {
          return ListTile(
            title: Text(channel.name),
            subtitle: Text(AppLocalizations.of(context)!.noCurrentProgram,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline)),
          );
        }

        final now = DateTime.now();

        return ExpansionTile(
          title: Text(channel.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: _currentProgramText(programs, now, context),
          initiallyExpanded: false,
          children: programs.map((prog) {
            final isCurrent =
                now.isAfter(prog.startTime) && now.isBefore(prog.endTime);
            return ListTile(
              dense: true,
              leading: Text(
                timeFormat.format(prog.startTime.toLocal()),
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
              title: Text(
                prog.title,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: prog.subtitle != null ? Text(prog.subtitle!) : null,
              trailing: Text(
                timeFormat.format(prog.endTime.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              tileColor: isCurrent
                  ? Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3)
                  : null,
            );
          }).toList(),
        );
      },
      loading: () => ListTile(
        title: Text(channel.name),
        subtitle: const LinearProgressIndicator(),
      ),
      error: (_, __) => ListTile(
        title: Text(channel.name),
        subtitle: Text(AppLocalizations.of(context)!.noCurrentProgram),
      ),
    );
  }

  Widget? _currentProgramText(
      List<EpgProgram> programs, DateTime now, BuildContext context) {
    final current = programs.where(
        (p) => now.isAfter(p.startTime) && now.isBefore(p.endTime));
    if (current.isEmpty) return null;
    final prog = current.first;
    final elapsed = now.difference(prog.startTime);
    final total = prog.endTime.difference(prog.startTime);
    final progress = elapsed.inSeconds / total.inSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${AppLocalizations.of(context)!.nowPlaying}: ${prog.title}'),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          backgroundColor:
              Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ],
    );
  }
}
