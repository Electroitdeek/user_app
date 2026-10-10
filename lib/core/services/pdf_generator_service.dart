import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Generates a single PDF document from one or more images (one image per page).
///
/// Used by the Aadhaar KYC flow to merge a front + back card photo into a single
/// PDF so the backend always receives one consistent document format.
class PdfGeneratorService {
  /// Merge [images] into a single PDF (one image per A4 page) and write it to a
  /// temporary file. Returns the generated [File].
  static Future<File> imagesToPdf(
    List<File> images, {
    String fileName = 'document',
  }) async {
    final doc = pw.Document();

    for (final image in images) {
      final bytes = await image.readAsBytes();
      final memImage = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(18),
          build: (context) => pw.Center(
            child: pw.Image(memImage, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/${fileName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path);
    await file.writeAsBytes(await doc.save());
    return file;
  }
}
