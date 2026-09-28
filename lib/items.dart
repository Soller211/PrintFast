import 'dart:convert';
import 'dart:io';

enum ItemStatus { ready, pending, error }

class PrintItem {
  PrintItem.pdf(String this.path, {this.status = ItemStatus.ready}) : url = null;
  PrintItem.adobe(String this.url) : path = null, status = ItemStatus.pending;

  String? path;
  final String? url;
  ItemStatus status;

  String get name => path != null ? displayName(path!) : 'Link de Adobe';
}

final _adobeLink = RegExp(r'https://acrobat\.adobe\.com/id/urn:aaid:sc:[A-Za-z0-9:-]+');

/// Adobe share links in [text] that are not in [known], in order, without repeats.
List<String> newAdobeLinks(String text, Iterable<String> known) {
  final seen = known.toSet();
  return [
    for (final m in _adobeLink.allMatches(text))
      if (seen.add(m.group(0)!)) m.group(0)!,
  ];
}

bool looksLikePdf(String path, String? mimeType) =>
    mimeType == 'application/pdf' || path.toLowerCase().endsWith('.pdf');

/// PDF spec allows junk before the header, so look in the first 1 KB.
Future<bool> isPdfFile(String path) async {
  try {
    final head = await File(path).openRead(0, 1024).expand((b) => b).toList();
    return String.fromCharCodes(head).contains('%PDF-');
  } on FileSystemException {
    return false;
  }
}

/// Copies [src] into [dir] under a unique name: receive_sharing_intent copies shared
/// files to cacheDir by their original name, so a later share of another "documento.pdf" would overwrite it.
Future<String> keepCopy(String src, Directory dir) async {
  final dest = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${src.split('/').last}';
  await File(src).copy(dest);
  return dest;
}

/// Paths that appear more than once in one share. receive_sharing_intent copies each file to
/// `cacheDir/<original name>`, so same-named files overwrite each other before we see them.
// ponytail: flags them instead of recovering; reading the content URIs natively would keep both.
Set<String> sharedTwice(Iterable<String> paths) {
  final seen = <String>{};
  return {for (final p in paths) if (!seen.add(p)) p};
}

final _uniquePrefix = RegExp(r'^\d{16}_');

String displayName(String path) => path.split('/').last.replaceFirst(_uniquePrefix, '');

/// File name Adobe puts in the signed download URL, e.g. "factura.pdf".
String adobeFileName(String signedUrl) {
  final cd = Uri.parse(signedUrl).queryParameters['response-content-disposition'] ?? '';
  return RegExp(r'filename="?([^";]+)').firstMatch(cd)?.group(1) ?? 'adobe.pdf';
}

/// Android returns JS strings JSON-encoded ("\"https://...&...\""); null when empty.
String? decodeJsResult(Object result) {
  var s = result.toString();
  if (s.startsWith('"')) s = jsonDecode(s) as String;
  return s.isEmpty || s == 'null' ? null : s;
}

/// "4 archivos · 2 listos · 1 por bajar · 1 con error"
String summary(List<PrintItem> items) {
  int count(ItemStatus s) => items.where((i) => i.status == s).length;
  String n(int k, String one, String many) => '$k ${k == 1 ? one : many}';
  final ready = count(ItemStatus.ready), pending = count(ItemStatus.pending), error = count(ItemStatus.error);
  return [
    n(items.length, 'archivo', 'archivos'),
    if (ready > 0) n(ready, 'listo', 'listos'),
    if (pending > 0) '$pending por bajar',
    if (error > 0) '$error con error',
  ].join(' · ');
}
