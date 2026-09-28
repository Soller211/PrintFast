# PrintFast — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App Android en Flutter que recibe PDFs y links de Adobe desde WhatsApp, baja los de Adobe automáticamente y los imprime todos juntos con un solo diálogo de impresión.

**Architecture:** Una pantalla (`HomeScreen`) con la lista en memoria. Las funciones puras (detectar links, validar PDFs, nombres de archivo) viven en `items.dart` con pruebas unitarias. `AdobeFetchScreen` abre el link en un WebView, encuentra la URL firmada del PDF que el propio visor de Adobe descarga y la baja con `HttpClient`. `printAll` une los PDFs con `pdf_combiner` y abre el diálogo de impresión con `printing`.

**Tech Stack:** Flutter 3.47.5 (stable), Dart 3, `receive_sharing_intent` ^1.9.0, `webview_flutter`, `pdf_combiner` ^6.2.2, `printing` ^5.15.1, `path_provider` ^2.1.6.

**Spec:** `docs/superpowers/specs/2026-09-27-printfast-design.md`

## Global Constraints

- Solo Android. Sin iOS, sin web, sin escritorio (`flutter create --platforms android`).
- Sin cuentas, sin backend, sin base de datos; archivos en el directorio temporal de la app (`<tmp>/printfast`).
- Código abierto: licencia MIT, README en español.
- Textos de la interfaz en español.
- Link de Adobe válido = `https://acrobat.adobe.com/id/urn:aaid:sc:...`.
- Tiempo máximo por link de Adobe: 40 s.
- Dependencias: solo las cinco del Tech Stack. Descargas con `dart:io` `HttpClient`, sin el paquete `http`.
- Entorno: WSL, Flutter en `~/flutter`, Android SDK en `~/Android/Sdk`, JDK 21 ya instalado.

## Review Focus

1. **Dos PDFs con el mismo nombre** (p. ej. dos `documento.pdf` de WhatsApp): el plugin copia ambos a `cacheDir/documento.pdf` y el segundo pisa al primero. Se esperan dos elementos distintos con su contenido correcto. → prueba de `keepCopy` en la Tarea 2.
2. **El mismo link compartido o pegado dos veces**: no debe duplicarse en la lista. → prueba de `newAdobeLinks` en la Tarea 2.
3. **APK de release sin permiso `INTERNET`**: la plantilla de Flutter solo lo pone en `debug`/`profile`, así que el APK que se instala en el teléfono no podría bajar nada de Adobe. → verificación con `grep` en la Tarea 4.
4. **Link de Adobe borrado, privado o caducado**: el visor nunca baja un PDF. Se espera que a los 40 s quede en error, no que la pantalla cargue para siempre. → prueba manual con un link alterado en la Tarea 3.
5. **Archivo que dice ser PDF y no lo es** (tipo MIME equivocado o archivo dañado): debe marcarse en error con su nombre antes de unir, en vez de que falle toda la impresión. → prueba de `isPdfFile` en la Tarea 2.
6. **Resultado de JS en Android**: `runJavaScriptReturningResult` devuelve el texto codificado en JSON (`"https://...&..."`). Si no se decodifica, la URL firmada queda rota. → prueba de `decodeJsResult` en la Tarea 2.

## Estructura de archivos

```
lib/
  main.dart          HomeScreen: lista, recepción de shares, pegar, botones
  items.dart         PrintItem + funciones puras (links, PDFs, nombres, JS)
  adobe_fetch.dart   AdobeFetchScreen + download()
  print_all.dart     printAll(): unir + imprimir
test/
  items_test.dart
android/app/src/main/AndroidManifest.xml   filtros de share, INTERNET, singleTask
README.md, LICENSE
```

---

### Task 1: Instalar Flutter y crear el proyecto

**Files:**
- Create: proyecto Flutter en `/home/soller211/PrintFastP` (`pubspec.yaml`, `lib/`, `android/`, `test/`, `.gitignore`)
- Create: `LICENSE`
- Delete: `test/widget_test.dart` (lo genera la plantilla y prueba el contador de ejemplo)

**Interfaces:**
- Produces: paquete Dart llamado `printfast` (los imports son `package:printfast/...`), `applicationId` `io.github.solleru.printfast`.

- [ ] **Step 1: Descargar e instalar Flutter 3.47.5**

```bash
cd ~ && curl -fLO https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.5-stable.tar.xz
tar xf flutter_linux_3.47.5-stable.tar.xz && rm flutter_linux_3.47.5-stable.tar.xz
grep -q 'flutter/bin' ~/.bashrc || echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/flutter/bin:$PATH"
flutter --disable-analytics
flutter config --android-sdk ~/Android/Sdk
```

- [ ] **Step 2: Aceptar licencias y verificar**

```bash
yes | flutter doctor --android-licenses
flutter doctor
```

Esperado: `[✓] Flutter` y `[✓] Android toolchain`. Chrome, Linux desktop y "Connected device" pueden salir en ✗ o ! sin problema. Si falla Android toolchain por falta de `cmdline-tools`, `platform-tools` o `build-tools`, instalar con `~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager "platform-tools" "build-tools;36.0.0" "platforms;android-36"`.

- [ ] **Step 3: Crear el proyecto dentro de la carpeta existente**

```bash
cd /home/soller211/PrintFastP
flutter create --org io.github.solleru --project-name printfast --platforms android --description "Imprime juntos los PDFs y links de Adobe que te mandan por WhatsApp" .
rm test/widget_test.dart
flutter pub add receive_sharing_intent webview_flutter pdf_combiner printing path_provider
```

- [ ] **Step 4: Agregar la licencia MIT**

`LICENSE`:
```
MIT License

Copyright (c) 2026 Solleru

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 5: Verificar que compila**

Run: `flutter build apk --debug`
Esperado: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`. La primera vez tarda varios minutos porque Gradle baja dependencias. Si algún plugin pide un `minSdk` o `compileSdk` más alto, subirlo en `android/app/build.gradle.kts` (`minSdk = 24` alcanza para `webview_flutter`).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Scaffold Flutter Android project with dependencies and MIT license"
```

---

### Task 2: Lógica pura (`items.dart`)

**Files:**
- Create: `lib/items.dart`
- Test: `test/items_test.dart`

**Interfaces:**
- Produces:
  - `enum ItemStatus { ready, pending, error }`
  - `class PrintItem` con los constructores `PrintItem.pdf(String path, {ItemStatus status = ItemStatus.ready})` y `PrintItem.adobe(String url)`, los campos `String? path`, `final String? url` y `ItemStatus status`, y el getter `String name`
  - `List<String> newAdobeLinks(String text, Iterable<String> known)`
  - `bool looksLikePdf(String path, String? mimeType)`
  - `Future<bool> isPdfFile(String path)`
  - `Future<String> keepCopy(String src, Directory dir)`: devuelve `'<dir>/<16 dígitos>_<nombre>'`
  - `String displayName(String path)`: nombre sin carpeta y sin el prefijo `<16 dígitos>_`
  - `String adobeFileName(String signedUrl)`
  - `String? decodeJsResult(Object result)`

- [ ] **Step 1: Escribir las pruebas que fallan**

`test/items_test.dart`:
```dart
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
}
```

- [ ] **Step 2: Correr las pruebas y confirmar que fallan**

Run: `flutter test test/items_test.dart`
Esperado: FAIL con `Error when reading 'lib/items.dart': No such file or directory`.

- [ ] **Step 3: Implementar**

`lib/items.dart`:
```dart
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
/// files to cacheDir by their original name, so two "documento.pdf" would collide.
Future<String> keepCopy(String src, Directory dir) async {
  final dest = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_${src.split('/').last}';
  await File(src).copy(dest);
  return dest;
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
```

- [ ] **Step 4: Correr las pruebas y confirmar que pasan**

Run: `flutter test test/items_test.dart`
Esperado: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/items.dart test/items_test.dart
git commit -m "Add item model and pure helpers for links, PDFs and names"
```

---

### Task 3: Bajar PDFs de Adobe (`adobe_fetch.dart`)

**Files:**
- Create: `lib/adobe_fetch.dart`
- Modify: `lib/main.dart` (temporalmente, solo para la prueba manual; la Tarea 4 lo reemplaza entero)
- Modify: `android/app/src/main/AndroidManifest.xml` (permiso `INTERNET`)

**Interfaces:**
- Consumes: `decodeJsResult`, `adobeFileName` e `isPdfFile` de `items.dart`
- Produces:
  - `class AdobeFetchScreen extends StatefulWidget`: `AdobeFetchScreen({required String url, required Directory saveDir, required String label})`. Al cerrarse con `Navigator.pop` devuelve un `String?`: la ruta del PDF bajado, o `null` si falló, pasó el tiempo o el usuario volvió atrás.
  - `Future<void> download(String url, String path)`: lanza una excepción si el estado HTTP no es 200.

- [ ] **Step 1: Agregar el permiso INTERNET al manifiesto principal**

En `android/app/src/main/AndroidManifest.xml`, justo después de la línea `<manifest xmlns:android=...>`:
```xml
    <uses-permission android:name="android.permission.INTERNET"/>
```

Verificar: `grep -c 'android.permission.INTERNET' android/app/src/main/AndroidManifest.xml` → `1`

- [ ] **Step 2: Implementar la pantalla**

`lib/adobe_fetch.dart`:
```dart
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
    if (_busy || _done) return;
    if (DateTime.now().difference(_started) > _timeout) return _finish(null);
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Bajando de Adobe ${widget.label}')),
        body: Column(children: [
          const LinearProgressIndicator(),
          Expanded(child: WebViewWidget(controller: _web)),
        ]),
      );
}

Future<void> download(String url, String path) async {
  final client = HttpClient();
  try {
    final res = await (await client.getUrl(Uri.parse(url))).close();
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
    await res.pipe(File(path).openWrite());
  } finally {
    client.close();
  }
}
```

- [ ] **Step 3: Pantalla temporal para probar en el teléfono**

Reemplazar `lib/main.dart` completo por:
```dart
import 'dart:io';

import 'package:flutter/material.dart';

import 'adobe_fetch.dart';

// Temporary harness for Task 3; Task 4 replaces this file.
void main() => runApp(const MaterialApp(home: _Probe()));

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  String _result = '';

  Future<void> _go(String url) async {
    final path = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => AdobeFetchScreen(url: url, saveDir: Directory.systemTemp, label: '1 de 1')),
    );
    setState(() => _result = path ?? 'null (falló)');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FilledButton(
              onPressed: () => _go('https://acrobat.adobe.com/id/urn:aaid:sc:VA6C2:00000000-aaaa-bbbb-cccc-000000000001'),
              child: const Text('Link real'),
            ),
            FilledButton(
              onPressed: () => _go('https://acrobat.adobe.com/id/urn:aaid:sc:VA6C2:00000000-0000-0000-0000-000000000000'),
              child: const Text('Link roto'),
            ),
            Text(_result),
          ]),
        ),
      );
}
```

- [ ] **Step 4: Instalar en el teléfono y probar**

Hay dos formas de instalarla:
- **Depuración inalámbrica** (Android 11+): en el teléfono, Opciones de desarrollador → Depuración inalámbrica → Vincular con código. En WSL: `~/Android/Sdk/platform-tools/adb pair <ip>:<puerto> <código>`, luego `adb connect <ip>:<puerto>` y `flutter run`.
- **APK a mano:** `flutter build apk --debug && cp build/app/outputs/flutter-apk/app-debug.apk /mnt/c/Users/<tu-usuario>/Downloads/printfast-debug.apk`. Luego pasarlo al teléfono (Drive, cable o WhatsApp a ti mismo) e instalarlo.

Esperado:
- "Link real": en ≤10 s vuelve y muestra una ruta que termina en `factura_septiembre.pdf`.
- "Link roto": a los ~40 s vuelve y muestra `null (falló)`.
- Volver atrás mientras carga: muestra `null (falló)` y la app no se cierra.

Si el WebView termina en una página de "abrir en la app"/Play Store o en una página de error `intent://` en vez del visor, anotarlo: hay que agregar un `NavigationDelegate` que bloquee los `intent:`.

Si "Link real" también termina en `null`, la causa más probable es que el WebView de Android no expone esa entrada. Diagnóstico: en Chrome del PC, abrir `chrome://inspect` con el teléfono conectado por adb, inspeccionar el WebView y ejecutar `performance.getEntriesByType('resource').map(e=>e.name).filter(n=>n.includes('pdf'))`. Reportar el resultado antes de cambiar el enfoque.

- [ ] **Step 5: Commit**

```bash
git add lib/adobe_fetch.dart lib/main.dart android/app/src/main/AndroidManifest.xml
git commit -m "Add AdobeFetchScreen: download PDF from Adobe share link via signed URL"
```

---

### Task 4: Pantalla principal, compartir, pegar e imprimir

**Files:**
- Create: `lib/print_all.dart`
- Modify: `lib/main.dart` (reemplazo completo)
- Modify: `android/app/src/main/AndroidManifest.xml` (`launchMode`, `label`, filtros de share)

**Interfaces:**
- Consumes: todo lo de `items.dart` (Tarea 2) y `AdobeFetchScreen` (Tarea 3)
- Produces: `Future<void> printAll(List<String> paths, Directory tmp)`

- [ ] **Step 1: Unir e imprimir**

`lib/print_all.dart`:
```dart
import 'dart:io';

import 'package:pdf_combiner/models/merge_input.dart';
import 'package:pdf_combiner/pdf_combiner.dart';
import 'package:printing/printing.dart';

/// Merges [paths] in order into one PDF and opens the Android print dialog once.
Future<void> printAll(List<String> paths, Directory tmp) async {
  final merged = paths.length == 1
      ? paths.single
      : await PdfCombiner.mergeMultiplePDFs(
          inputs: paths.map(MergeInput.path).toList(),
          outputPath: '${tmp.path}/printfast_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
  final bytes = await File(merged).readAsBytes();
  await Printing.layoutPdf(name: 'PrintFast', onLayout: (_) async => bytes);
}
```

- [ ] **Step 2: Pantalla principal**

Reemplazar `lib/main.dart` completo por:
```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'adobe_fetch.dart';
import 'items.dart';
import 'print_all.dart';

void main() => runApp(MaterialApp(
      title: 'PrintFast',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
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
    var ignored = 0;
    for (final f in files) {
      if (f.type == SharedMediaType.text || f.type == SharedMediaType.url) {
        if (_addLinks(f.path) == 0) ignored++;
      } else if (looksLikePdf(f.path, f.mimeType)) {
        await _addPdf(f.path, dir);
      } else {
        ignored++;
      }
    }
    if (ignored > 0) _say('$ignored ignorado(s): solo se aceptan PDFs y links nuevos de Adobe');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('PrintFast'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_sweep), tooltip: 'Vaciar lista', onPressed: _busy ? null : _clear),
        ],
      ),
      body: _items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Comparte PDFs desde WhatsApp,\no copia los mensajes con links de Adobe y toca "Pegar links".',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(children: [for (final item in _items) _tile(item)]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.content_paste),
                label: const Text('Pegar links'),
                onPressed: _busy ? null : _paste,
              ),
              if (toFetch > 0)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.download),
                  label: Text('Bajar de Adobe ($toFetch)'),
                  onPressed: _busy ? null : _fetchAdobe,
                ),
              FilledButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('Imprimir todo'),
                onPressed: _busy || !_canPrint ? null : _print,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(PrintItem item) => ListTile(
        leading: switch (item.status) {
          ItemStatus.ready => const Icon(Icons.check_circle, color: Colors.green),
          ItemStatus.pending => const Icon(Icons.hourglass_empty),
          ItemStatus.error => const Icon(Icons.error, color: Colors.red),
        },
        title: Text(item.name),
        subtitle: switch (item.status) {
          ItemStatus.error => Text(item.url != null ? 'No se pudo bajar: reintenta o quítalo' : 'No es un PDF válido: quítalo'),
          _ when item.url != null && item.path == null => Text(item.url!, maxLines: 1, overflow: TextOverflow.ellipsis),
          _ => null,
        },
        trailing: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Quitar',
          onPressed: _busy ? null : () => setState(() => _items.remove(item)),
        ),
      );
}
```

- [ ] **Step 3: Manifiesto: nombre, singleTask y filtros de share**

En `android/app/src/main/AndroidManifest.xml`:
- En `<application ...>`: `android:label="PrintFast"`.
- En `<activity android:name=".MainActivity" ...>`: cambiar `android:launchMode="singleTop"` por `android:launchMode="singleTask"`. Así, compartir con la app abierta suma a la lista actual en vez de abrir otra instancia.
- Dentro de esa `<activity>`, después del `<intent-filter>` de `MAIN`/`LAUNCHER`, agregar:

```xml
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="application/pdf" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="text/plain" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.SEND_MULTIPLE" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="*/*" />
            </intent-filter>
```

`SEND_MULTIPLE` usa `*/*` porque WhatsApp puede mandar varios documentos como `*/*` o `application/*`. Si llegan imágenes, se ignoran y se avisa.

Verificar:
```bash
grep -c 'android.permission.INTERNET' android/app/src/main/AndroidManifest.xml   # → 1
grep -c 'singleTask' android/app/src/main/AndroidManifest.xml                    # → 1
grep -c 'android.intent.action.SEND' android/app/src/main/AndroidManifest.xml    # → 3
```

- [ ] **Step 4: Análisis estático y pruebas**

Run: `flutter analyze && flutter test`
Esperado: `No issues found!` y `All tests passed!`

- [ ] **Step 5: Probar en el teléfono**

Instalar como en la Tarea 3, paso 4. Checklist (todo tiene que pasar):
1. En WhatsApp, seleccionar 2+ PDFs → Compartir → PrintFast. Aparecen todos con ✅.
2. Compartir dos PDFs que se llamen igual. Aparecen dos elementos y, al imprimir, salen los dos contenidos distintos.
3. En WhatsApp, copiar 2+ mensajes con links de Adobe → "Pegar links". Aparecen con ⏳ y el botón dice "Bajar de Adobe (N)".
4. "Pegar links" otra vez. Sale "No encontré links nuevos" y no se duplica nada.
5. "Bajar de Adobe". Pasa sola por cada link y quedan en ✅ con el nombre real del archivo.
6. "Imprimir todo". Sale **un** diálogo de impresión con todas las páginas en el orden de la lista; imprimir en la impresora real.
7. Con la app abierta, compartir un PDF más desde WhatsApp. Se suma a la lista existente.
8. Compartir una foto. Aparece "1 ignorado(s)".
9. Con una lista que tenga un ❌, "Imprimir todo" está deshabilitado; al quitar el ❌ se habilita.
10. "Vaciar lista" deja la pantalla vacía.

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart lib/print_all.dart android/app/src/main/AndroidManifest.xml
git commit -m "Add home screen: receive shares, paste links, fetch Adobe, print all at once"
```

---

### Task 5: README y APK de release

**Files:**
- Modify: `README.md` (reemplazar el que genera `flutter create`)

**Interfaces:**
- Consumes: la app terminada

- [ ] **Step 1: README**

`README.md`:
````markdown
# PrintFast

App Android para imprimir de una sola vez los PDFs y links de Adobe Acrobat que te mandan por WhatsApp.

## Cómo se usa

1. **PDFs:** en WhatsApp mantén presionado para seleccionar los documentos → Compartir → **PrintFast**.
2. **Links de Adobe** (`https://acrobat.adobe.com/id/urn:...`): selecciona los mensajes → Copiar → en PrintFast toca **Pegar links**. También puedes compartir un mensaje con link directo a PrintFast.
3. Toca **Bajar de Adobe**: la app abre cada link y baja el PDF sola.
4. Toca **Imprimir todo**: se juntan todos los PDFs en uno y se abre el diálogo de impresión de Android una sola vez.

Necesitas una impresora ya configurada en el teléfono (Ajustes → Impresión).

## Cómo funciona lo de Adobe

El visor de Adobe baja el PDF desde una URL firmada apenas carga la página. PrintFast abre el link en un WebView, busca esa URL en `performance.getEntriesByType('resource')` y la descarga. No usa cuenta de Adobe. Si Adobe cambia su visor, el ajuste se hace en `lib/adobe_fetch.dart`.

## Compilar

```bash
flutter pub get
flutter test
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`. Se firma con la clave de depuración, así que sirve para instalarlo a mano pero no para Play Store.

## Licencia

MIT
````

- [ ] **Step 2: Compilar el release y confirmar que tiene INTERNET**

```bash
flutter build apk --release
~/Android/Sdk/build-tools/36.0.0/aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk | grep INTERNET
cp build/app/outputs/flutter-apk/app-release.apk /mnt/c/Users/<tu-usuario>/Downloads/printfast.apk
```

Esperado: el `grep` imprime `uses-permission: name='android.permission.INTERNET'` y el APK queda en Descargas de Windows.

- [ ] **Step 3: Instalar el release en el teléfono** y repetir los puntos 3, 5 y 6 del checklist de la Tarea 4 (lo de Adobe es lo que se rompe si falta `INTERNET` en release).

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "Add README with usage and build instructions"
```
