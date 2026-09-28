# PrintFast — Diseño

Fecha: 2026-09-27

## Problema

La mamá del usuario le manda por WhatsApp varias cosas para imprimir: PDFs y links
compartidos de Adobe Acrobat (`https://acrobat.adobe.com/id/urn:aaid:sc:...`).
Abrir/descargar cada uno por separado y mandarlo a imprimir uno por uno es lento.

## Objetivo

Compartir varios mensajes de WhatsApp a la vez hacia la app y terminar con **un solo
diálogo de impresión** que imprima todo.

Éxito = de "seleccionar mensajes en WhatsApp" a "todo impreso" con: 1 share de los PDFs,
1 copiar/pegar de los links, 0 toques por link de Adobe, 1 diálogo de impresión.

## Restricciones

- Solo Android. La impresora ya está configurada en el teléfono (servicio de impresión de Android).
- Flutter.
- Sin cuentas, sin backend, sin base de datos.
- Proyecto de código abierto y simple (licencia MIT, README para que otros lo usen).

## Flujo

1. Formas de meter cosas a la lista (se pueden repetir y se suman):
   - WhatsApp: seleccionar documentos → Compartir → PrintFast. Android entrega **solo archivos** cuando
     se comparten varios a la vez (`SEND_MULTIPLE` no lleva texto).
   - WhatsApp: compartir **un** mensaje de texto → PrintFast (llega como texto).
   - WhatsApp: seleccionar varios mensajes de texto → Copiar → en la app, botón **"Pegar links"**
     (lee el portapapeles).
2. La app clasifica lo que recibe:
   - Archivo PDF → a la lista como **listo**.
   - Texto que contiene uno o más links `acrobat.adobe.com/id/urn:...` → cada link a la lista como **pendiente**.
   - Cualquier otra cosa (imágenes, audio, texto sin link) → se ignora; se muestra
     "N elementos ignorados".
3. Pantalla única con la lista: nombre, estado (listo / pendiente / error), quitar elemento.
4. **"Bajar de Adobe"**: abre cada link pendiente (o con error, para reintentar) en un WebView dentro de la
   app. **No hace falta tocar nada**: el visor de Adobe baja el PDF solo al cargar, desde una URL
   firmada (`...blobstore...adobe.io/...?response-content-type=application%2Fpdf&X-Amz-...`). La app
   busca esa URL en `performance.getEntriesByType('resource')` cada segundo, la descarga con
   `HttpClient` (no necesita cookies), marca el elemento como listo y pasa al siguiente. Si en 40 s
   no aparece, el elemento queda en error.
5. **"Imprimir todo"** (habilitado cuando hay al menos un elemento y todos están listos): une todos los PDFs listos en
   el orden de la lista en un solo PDF y abre el diálogo de impresión de Android una vez.

Si se comparten más cosas mientras la app está abierta, se agregan a la lista actual.

## Componentes

| Pieza | Responsabilidad | Paquete |
|---|---|---|
| Recepción del share | Recibir archivos + texto del intent de compartir de Android | `receive_sharing_intent` |
| Extractor de links | Función pura: texto → lista de URLs de Adobe | ninguno (RegExp) |
| Lista (estado) | Elementos en memoria: `{nombre, estado, rutaPdf?, url?}` | ninguno (StatefulWidget) |
| Descarga de Adobe | WebView + buscar la URL firmada en Resource Timing → `HttpClient` → archivo en el directorio temporal | `webview_flutter` |
| Unir + imprimir | Unir PDFs → un solo diálogo de impresión | `printing` + librería para unir PDFs (se elige en el plan) |

Los archivos viven en el directorio temporal de la app y se borran cuando se vacía la lista.

## Manejo de errores

- La descarga de Adobe falla, pide iniciar sesión o se cierra el WebView → el elemento queda en **error**
  con opciones de reintentar o quitar; el lote continúa con el siguiente pendiente.
- Un PDF no se puede leer o unir → mensaje con el nombre del archivo que falló; ese elemento pasa a **error**.
- No hay nada listo → "Imprimir todo" deshabilitado.

## Pruebas

- Prueba unitaria del extractor de links (varios links en un mensaje, texto de WhatsApp tipo
  "Abre el documento compartido: <url>", sin links, links que no son de Adobe).
- Todo lo demás: prueba manual en el teléfono del usuario con mensajes reales de WhatsApp.

## Riesgos / preguntas abiertas

1. **Descarga de Adobe.** Probado el 2026-09-27 con un navegador móvil sin sesión: el visor hace `fetch` a
   una URL firmada tipo S3 con `content-type: application/pdf`; `curl` sin cookies baja el PDF. Riesgo que
   queda: que Adobe cambie su visor. Si pasa, solo cambia la búsqueda de la URL en `adobe_fetch.dart`.
   Se descartó `flutter_inappwebview` (sin versión estable desde 2024) en favor del `webview_flutter` oficial.
2. **Entorno.** Flutter se instala en el WSL; ya existe un SDK de Android en `~/Android/Sdk`.

## Fuera de alcance (por ahora)

Imprimir imágenes, iOS, historial, obtener PDFs de Adobe de forma totalmente automática (opción B), links
de otros servicios.
