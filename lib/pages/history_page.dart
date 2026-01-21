import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/scan_entry.dart';
import '../services/history_store.dart';
import '../utils/text_utils.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<ScanEntry> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final data = await HistoryStore.instance.load();
    if (!mounted) return;
    setState(() {
      items = data;
      loading = false;
    });
  }

  Future<void> _clear() async {
    await HistoryStore.instance.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: items.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_outline),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 56, color: cs.outline),
              const SizedBox(height: 10),
              Text(
                'No scans yet',
                style:
                Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Your saved scans will appear here.'),
            ],
          ),
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final e = items[i];
          final isUrl = looksLikeUrl(e.value);

          return Dismissible(
            key: ValueKey(e.createdAt.toIso8601String()),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 18),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.delete, color: cs.onErrorContainer),
            ),
            onDismissed: (_) async {
              await HistoryStore.instance.removeAt(e.createdAt);
              await _load();
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          e.format,
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${e.createdAt}',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: cs.outline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    ellipsizeMiddle(e.value, max: 80),
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                              ClipboardData(text: e.value));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Share.share(e.value);
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                      ),
                      if (isUrl)
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            final uri = toLaunchableUri(e.value);
                            await launchUrl(uri,
                                mode: LaunchMode.platformDefault);
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
