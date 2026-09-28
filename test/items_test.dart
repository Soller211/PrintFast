import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:printfast/items.dart';

const link1 = 'https://acrobat.adobe.com/id/urn:aaid:sc:VA6C2:00000000-aaaa-bbbb-cccc-000000000001';
const link2 = 'https://acrobat.adobe.com/id/urn:aaid:sc:VA6C2:00000000-1111-2222-3333-444444444444';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('printfast_test'));
  tearDown(() => tmp.delete(recursive: true));

  group('newAdobeLinks', () {
    test('finds the link in a WhatsApp share message', () {
      expect(newAdobeLinks('Abre el documento compartido: $link1', []), [link1]);
    });

    test('finds several links in copied WhatsApp messages, in order', () {
      const copied = '[27/9/26, 10:01 a. m.] Mamá: Abre el documento compartido: $link1\n'
          '[27/9/26, 10:02 a. m.] Mamá: Abre el documento compartido: $link2';
      expect(newAdobeLinks(copied, []), [link1, link2]);
    });

    test('skips repeats and links already in the list', () {
      expect(newAdobeLinks('$link1 $link1 $link2', [link2]), [link1]);
    });

    test('ignores text without Adobe links', () {
      expect(newAdobeLinks('hola https://google.com', []), isEmpty);
    });
  });

  test('looksLikePdf uses mime type or extension', () {
    expect(looksLikePdf('/x/a.bin', 'application/pdf'), isTrue);
    expect(looksLikePdf('/x/Factura.PDF', null), isTrue);
    expect(looksLikePdf('/x/foto.jpg', 'image/jpeg'), isFalse);
  });

  group('isPdfFile', () {
    test('true for a file with a PDF header', () async {
      final f = File('${tmp.path}/ok.pdf')..writeAsStringSync('%PDF-1.7\n%...');
      expect(await isPdfFile(f.path), isTrue);
    });

    test('false for a file that is not a PDF', () async {
      final f = File('${tmp.path}/fake.pdf')..writeAsStringSync('<html>hola</html>');
      expect(await isPdfFile(f.path), isFalse);
    });

    test('false for a missing file', () async {
      expect(await isPdfFile('${tmp.path}/nope.pdf'), isFalse);
    });
  });

  test('keepCopy keeps two files with the same name apart', () async {
    final a = Directory('${tmp.path}/a')..createSync();
    final b = Directory('${tmp.path}/b')..createSync();
    final out = Directory('${tmp.path}/out')..createSync();
    File('${a.path}/documento.pdf').writeAsStringSync('A');
    File('${b.path}/documento.pdf').writeAsStringSync('B');

    final p1 = await keepCopy('${a.path}/documento.pdf', out);
    final p2 = await keepCopy('${b.path}/documento.pdf', out);

    expect(p1, isNot(p2));
    expect(File(p1).readAsStringSync(), 'A');
    expect(File(p2).readAsStringSync(), 'B');
    expect(displayName(p1), 'documento.pdf');
  });

  test('sharedTwice finds paths the share plugin delivered more than once', () {
    // receive_sharing_intent copies same-named files in one share to the same cache path,
    // so the first file's content is already gone by the time Dart sees the list.
    expect(sharedTwice(['/c/factura.pdf', '/c/otro.pdf', '/c/factura.pdf']), {'/c/factura.pdf'});
    expect(sharedTwice(['/c/a.pdf', '/c/b.pdf']), isEmpty);
  });

  test('displayName only strips the keepCopy prefix', () {
    expect(displayName('/t/1758999999123456_factura.pdf'), 'factura.pdf');
    expect(displayName('/t/2024_informe.pdf'), '2024_informe.pdf');
  });

  test('adobeFileName reads the name from the signed URL', () {
    expect(
      adobeFileName('https://x.adobe.io/b?response-content-disposition=attachment%3B%20filename%3D%22factura_septiembre.pdf%22&x=1'),
      'factura_septiembre.pdf',
    );
    expect(adobeFileName('https://x.adobe.io/b'), 'adobe.pdf');
  });

  test('decodeJsResult unwraps Android JSON-encoded strings', () {
    expect(decodeJsResult(r'"https://a.io/b?x=1&y=2"'), 'https://a.io/b?x=1&y=2');
    expect(decodeJsResult('""'), isNull);
    expect(decodeJsResult(''), isNull);
    expect(decodeJsResult('null'), isNull);
    expect(decodeJsResult('https://a.io/b'), 'https://a.io/b');
  });

  test('PrintItem names', () {
    expect(PrintItem.pdf('/t/1758999999123456_factura.pdf').name, 'factura.pdf');
    final adobe = PrintItem.adobe(link1);
    expect(adobe.name, 'Link de Adobe');
    expect(adobe.status, ItemStatus.pending);
  });

  test('summary counts items by status with Spanish plurals', () {
    expect(summary([PrintItem.pdf('/t/a.pdf')]), '1 archivo · 1 listo');
    expect(
      summary([
        PrintItem.pdf('/t/a.pdf'),
        PrintItem.pdf('/t/b.pdf'),
        PrintItem.adobe(link1),
        PrintItem.pdf('/t/c.pdf', status: ItemStatus.error),
      ]),
      '4 archivos · 2 listos · 1 por bajar · 1 con error',
    );
  });
}
