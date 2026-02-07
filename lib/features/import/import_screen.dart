import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aly_player/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/providers/providers.dart';
import '../../core/models/dtos.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

enum _ImportTab { m3u, xtream, direct }

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _urlController = TextEditingController();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _directUrlController = TextEditingController();
  bool _isLoading = false;
  _ImportTab _selectedTab = _ImportTab.m3u;

  @override
  void dispose() {
    _urlController.dispose();
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _directUrlController.dispose();
    super.dispose();
  }

  Future<void> _importFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(playlistServiceProvider).importFromUrl(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.importSuccess)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.importError}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['m3u', 'm3u8', 'txt'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(playlistServiceProvider).importFromFile(result.files.single.path!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.importSuccess)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.importError}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().startsWith('http')) {
      _urlController.text = data.text!.trim();
    }
  }

  void _showQrScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: MobileScanner(
          onDetect: (capture) {
            final barcode = capture.barcodes.firstOrNull;
            if (barcode?.rawValue != null) {
              Navigator.pop(ctx);
              _urlController.text = barcode!.rawValue!;
            }
          },
        ),
      ),
    );
  }

  Future<void> _importFromXtream() async {
    final server = _serverController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (server.isEmpty || username.isEmpty || password.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final credentials = XtreamCredentials(
        server: server,
        username: username,
        password: password,
      );
      await ref.read(xtreamServiceProvider).importFromXtream(credentials);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.importSuccess)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final msg = e.toString().contains('Authentication')
            ? l10n.authFailed
            : '${l10n.importError}: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromDirectUrl() async {
    final url = _directUrlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(playlistServiceProvider).importFromDirectUrl(url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.importSuccess)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.importError}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importPlaylist)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Tab selector
                SegmentedButton<_ImportTab>(
                  segments: [
                    ButtonSegment(value: _ImportTab.m3u, label: Text('M3U')),
                    ButtonSegment(value: _ImportTab.xtream, label: Text(l10n.xtreamCodes)),
                    ButtonSegment(value: _ImportTab.direct, label: Text(l10n.directUrl)),
                  ],
                  selected: {_selectedTab},
                  onSelectionChanged: (v) => setState(() => _selectedTab = v.first),
                ),
                const SizedBox(height: 24),

                // Tab content
                if (_selectedTab == _ImportTab.m3u) ...[
                  Text(l10n.importFromUrl,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'https://example.com/playlist.m3u',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste),
                        onPressed: _importFromClipboard,
                        tooltip: l10n.paste,
                      ),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _importFromUrl,
                    icon: const Icon(Icons.download),
                    label: Text(l10n.importButton),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(l10n.importFromFile,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _importFromFile,
                    icon: const Icon(Icons.file_open),
                    label: Text(l10n.selectFile),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(l10n.importFromQr,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _showQrScanner,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(l10n.scanQrCode),
                  ),
                ],

                if (_selectedTab == _ImportTab.xtream) ...[
                  TextField(
                    controller: _serverController,
                    decoration: InputDecoration(
                      labelText: l10n.serverUrl,
                      hintText: 'http://example.com:8080',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: l10n.username,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _importFromXtream,
                    icon: const Icon(Icons.cloud_download),
                    label: Text(l10n.connect),
                  ),
                ],

                if (_selectedTab == _ImportTab.direct) ...[
                  TextField(
                    controller: _directUrlController,
                    decoration: InputDecoration(
                      labelText: l10n.directUrl,
                      hintText: 'https://example.com/stream.m3u8',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _importFromDirectUrl,
                    icon: const Icon(Icons.download),
                    label: Text(l10n.importButton),
                  ),
                ],
              ],
            ),
    );
  }
}
