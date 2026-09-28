import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'adobe_fetch.dart';
import 'items.dart';
import 'print_all.dart';
import 'ui.dart';

void main() => runApp(MaterialApp(
      title: 'PrintFast',
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeScreen(),
    ));

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _items = <PrintItem>[];
  late final StreamSubscription<List<SharedMediaFile>> _shareSub;
  Directory? _dir;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(_onShared);
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _onShared(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  @override
  void dispose() {
    _shareSub.cancel();
    super.dispose();
  }

  Future<Directory> _workDir() async =>
      _dir ??= await Directory('${(await getTemporaryDirectory()).path}/printfast').create(recursive: true);

  void _say(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onShared(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;
    final dir = await _workDir();
    final clashes = sharedTwice(files.map((f) => f.path));
    var ignored = 0;
    for (final f in files) {
      if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
        if (_addLinks(f.path) == 0) ignored++;
      } else if (clashes.contains(f.path)) {
        setState(() => _items.add(PrintItem.pdf(f.path, status: ItemStatus.error)));
      } else if (looksLikePdf(f.path, f.mimeType)) {
        await _addPdf(f.path, dir);
      } else {
        ignored++;
      }
    }
    if (clashes.isNotEmpty) {
      _say('Varios archivos se llaman igual (${clashes.map(displayName).join(', ')}): compártelos de uno en uno');
    } else if (ignored > 0) {
      _say('$ignored ignorado(s): solo se aceptan PDFs y links nuevos de Adobe');
    }
  }

  int _addLinks(String text) {
    final links = newAdobeLinks(text, _items.map((i) => i.url).whereType<String>());
    setState(() => _items.addAll(links.map(PrintItem.adobe)));
    return links.length;
  }

  Future<void> _addPdf(String src, Directory dir) async {
    PrintItem item;
    try {
      final path = await keepCopy(src, dir);
      item = PrintItem.pdf(path, status: await isPdfFile(path) ? ItemStatus.ready : ItemStatus.error);
    } on FileSystemException {
      item = PrintItem.pdf(src, status: ItemStatus.error);
    }
    setState(() => _items.add(item));
  }

  // WhatsApp only shares one document at a time, so let the user multi-select them from its folder.
  Future<void> _pickPdfs() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    await _onShared([
      for (final f in picked)
        if (f.path != null) SharedMediaFile(path: f.path!, type: SharedMediaType.file, mimeType: 'application/pdf'),
    ]);
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    final n = _addLinks(text);
    _say(n == 0 ? 'No encontré links nuevos de Adobe en lo copiado' : 'Agregué $n link(s) de Adobe');
  }

  Iterable<PrintItem> get _toFetch => _items.where((i) => i.url != null && i.status != ItemStatus.ready);

  Future<void> _fetchAdobe() async {
    final dir = await _workDir();
    final todo = _toFetch.toList();
    setState(() => _busy = true);
    for (final (n, item) in todo.indexed) {
      if (!mounted) return;
      final path = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (_) => AdobeFetchScreen(url: item.url!, saveDir: dir, label: '${n + 1} de ${todo.length}'),
        ),
      );
      if (!mounted) return;
      setState(() {
        item.path = path;
        item.status = path == null ? ItemStatus.error : ItemStatus.ready;
      });
    }
    if (mounted) setState(() => _busy = false);
  }

  bool get _canPrint => _items.isNotEmpty && _items.every((i) => i.status == ItemStatus.ready);

  Future<void> _print() async {
    setState(() => _busy = true);
    try {
      await printAll([for (final i in _items) i.path!], await _workDir());
    } catch (e) {
      _say('No se pudo imprimir: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    final dir = _dir;
    setState(() {
      _items.clear();
      _dir = null;
    });
    if (dir != null && await dir.exists()) await dir.delete(recursive: true);
  }

  @override
  Widget build(BuildContext context) {
    final toFetch = _toFetch.length;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PrintFast'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_sweep_rounded), tooltip: 'Vaciar lista', onPressed: _busy ? null : _clear),
          IconButton(icon: const Icon(Icons.info_outline_rounded), tooltip: 'Acerca de', onPressed: () => showAbout(context)),
        ],
        bottom: _busy
            ? const PreferredSize(preferredSize: Size.fromHeight(4), child: LinearProgressIndicator())
            : null,
      ),
      body: _items.isEmpty
          ? const EmptyState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(summary(_items), style: text.labelLarge),
                ),
                for (final item in _items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Dismissible(
                      key: ObjectKey(item),
                      direction: _busy ? DismissDirection.none : DismissDirection.endToStart,
                      onDismissed: (_) => setState(() => _items.remove(item)),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.delete_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                      child: ItemCard(
                        item: item,
                        onRemove: _busy ? null : () => setState(() => _items.remove(item)),
                      ),
                    ),
                  ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('Elegir PDFs'),
                      onPressed: _busy ? null : _pickPdfs,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.content_paste_rounded),
                      label: const Text('Pegar links'),
                      onPressed: _busy ? null : _paste,
                    ),
                  ),
                ],
              ),
              if (toFetch > 0) ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.download_rounded),
                  label: Text('Bajar de Adobe ($toFetch)'),
                  onPressed: _busy ? null : _fetchAdobe,
                ),
              ],
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 56), textStyle: text.titleMedium),
                icon: const Icon(Icons.print_rounded),
                label: Text(_items.isEmpty ? 'Imprimir todo' : 'Imprimir todo (${_items.length})'),
                onPressed: _busy || !_canPrint ? null : _print,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
