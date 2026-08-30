import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';

class ReportExportService {
  Future<ReportExportResult> savePdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final String normalizedFileName = _normalizeFileName(fileName);
    final String baseName = normalizedFileName.substring(
      0,
      normalizedFileName.length - 4,
    );

    String? savedPath;
    try {
      savedPath = await FileSaver.instance.saveAs(
        name: baseName,
        bytes: bytes,
        fileExtension: 'pdf',
        mimeType: MimeType.pdf,
      );
    } catch (_) {
      savedPath = null;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return ReportExportResult(
        fileName: normalizedFileName,
        savedPath: _validatedPath(savedPath),
      );
    }

    savedPath ??= await FileSaver.instance.saveFile(
      name: baseName,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );

    return ReportExportResult(
      fileName: normalizedFileName,
      savedPath: _validatedPath(savedPath),
    );
  }

  String _validatedPath(String? savedPath) {
    final String trimmedPath = savedPath?.trim() ?? '';
    if (trimmedPath.isEmpty ||
        trimmedPath.toLowerCase().contains('something went wrong')) {
      throw Exception('Unable to save the generated PDF.');
    }

    return trimmedPath;
  }

  String _normalizeFileName(String fileName) {
    final String trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      return 'report-export.pdf';
    }

    final String sanitized = trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-');
    return sanitized.toLowerCase().endsWith('.pdf')
        ? sanitized
        : '$sanitized.pdf';
  }
}

class ReportExportResult {
  const ReportExportResult({required this.fileName, required this.savedPath});

  final String fileName;
  final String savedPath;
}
