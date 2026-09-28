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
