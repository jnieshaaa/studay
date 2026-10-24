import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Data class holding extracted PDF information
class ExtractedPdfData {
  final String fileName;
  final String text;
  final int pageCount;

  const ExtractedPdfData({
    required this.fileName,
    required this.text,
    required this.pageCount,
  });
}

/// Utility for picking PDF files and extracting readable text content on-device.
class PdfExtractor {
  /// Opens device file picker to select a PDF and extracts its text.
  /// Returns [ExtractedPdfData] or null if canceled / unreadable.
  static Future<ExtractedPdfData?> pickAndExtractText() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.single;
      Uint8List? bytes = file.bytes;

      if (bytes == null && file.path != null && !kIsWeb) {
        final ioFile = File(file.path!);
        if (await ioFile.exists()) {
          bytes = await ioFile.readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        return null;
      }

      return extractTextFromBytes(bytes, fileName: file.name);
    } catch (e) {
      debugPrint('[PdfExtractor] Error picking/extracting PDF: $e');
      rethrow;
    }
  }

  /// Extracts text from in-memory PDF bytes.
  static ExtractedPdfData extractTextFromBytes(
    Uint8List bytes, {
    String fileName = 'document.pdf',
  }) {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    try {
      final pageCount = document.pages.count;
      final text = PdfTextExtractor(document).extractText();
      return ExtractedPdfData(
        fileName: fileName,
        text: text.trim(),
        pageCount: pageCount,
      );
    } finally {
      document.dispose();
    }
  }
}
