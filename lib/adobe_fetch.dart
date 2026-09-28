import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'items.dart';

// The Acrobat viewer fetches the PDF itself from a signed URL as soon as the page loads
// (checked 2026-09-27), so we read that URL from Resource Timing instead of clicking "Download".
// ponytail: tied to Adobe's current viewer; if it stops matching, this string is the only fix point.
const _findPdfUrl = '''
(performance.getEntriesByType('resource').map(e => e.name)
  .find(n => n.includes('response-content-type=application%2Fpdf')) || '')
''';

const _timeout = Duration(seconds: 40);

/// Opens an Adobe share link and pops with the downloaded PDF path, or null on failure.
class AdobeFetchScreen extends StatefulWidget {
  const AdobeFetchScreen({super.key, required this.url, required this.saveDir, required this.label});

  final String url;
  final Directory saveDir;
  final String label;

  @override
  State<AdobeFetchScreen> createState() => _AdobeFetchScreenState();
}

class _AdobeFetchScreenState extends State<AdobeFetchScreen> {
  late final _web = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..loadRequest(Uri.parse(widget.url));
  late final Timer _poll;
  final _started = DateTime.now();
  bool _busy = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _check());
  }

  @override
  void dispose() {
    _poll.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (DateTime.now().difference(_started) > _timeout) return _finish(null);
    if (_busy || _done) return;
    _busy = true;

    String? url;
    try {
      url = decodeJsResult(await _web.runJavaScriptReturningResult(_findPdfUrl));
    } catch (_) {
      // Page still loading; try again on the next tick.
    }
    if (url == null) {
      _busy = false;
      return;
    }

    final path = '${widget.saveDir.path}/${DateTime.now().microsecondsSinceEpoch}_${adobeFileName(url)}';
    try {
      await download(url, path);
    } catch (_) {
      return _finish(null);
    }
    _finish(await isPdfFile(path) ? path : null);
  }

  void _finish(String? path) {
    if (_done) return;
    _done = true;
    _poll.cancel();
    if (mounted) Navigator.pop(context, path);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Bajando ${widget.label}'),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(4), child: LinearProgressIndicator()),
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          color: scheme.tertiaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Icon(Icons.hourglass_top_rounded, color: scheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'El PDF se baja solo, no toques nada. Si tarda más de 40 s, se marca con error.',
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
          ]),
        ),
        Expanded(child: WebViewWidget(controller: _web)),
      ]),
    );
  }
}

Future<void> download(String url, String path, {Duration timeout = _timeout}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    await () async {
      final res = await (await client.getUrl(Uri.parse(url))).close();
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
      await res.pipe(File(path).openWrite());
    }().timeout(timeout);
  } finally {
    client.close(force: true);
  }
}
