import 'dart:io';

import 'package:adhisaat_health_care/core/api/api_client.dart';
import 'package:adhisaat_health_care/core/navigation/app_navigator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../shared/widgets/progress_bar/download_progress_dialog.dart';

class FileDownloadService {
  final Dio _dio;

  FileDownloadService({Dio? dio}) : _dio = dio ?? Dio();

  /// Download file with progress callback
  Future<DownloadResult> downloadFile({
    required String url,
    String? fileName,
    required Function(int received, int total) onProgress,
    CancelToken? cancelToken,
    bool forceRedownload = false,
  }) async {
    try {
      // Handle local file paths
      if (url.startsWith('/') || url.startsWith('file://')) {
        final path = url.startsWith('file://') ? url.substring(7) : url;
        final file = File(path);
        if (await file.exists()) {
          final ext = getFileExtension(path);
          return DownloadResult(filePath: path, mimeType: getMimeType(path), fileExtension: ext, alreadyExists: true);
        }
      }

      // Request storage permission
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        throw Exception('Storage permission denied');
      }

      // Get download directory
      String name = fileName ?? p.basenameWithoutExtension(url);
      String extension = getFileExtension(url);

      // If fileName already has the extension, don't use basenameWithoutExtension logic
      // or just ensure we don't append it twice.
      String filePathWithExt;
      if (name.toLowerCase().endsWith(extension.toLowerCase()) && extension.isNotEmpty) {
        filePathWithExt = await _getSafeFilePath(name);
      } else {
        final filePath = await _getSafeFilePath(name);
        filePathWithExt = "$filePath$extension";
      }

      kPrint("url: $url");
      kPrint("name: $name");
      kPrint("extension: $extension");
      kPrint("fileNameWithExt: $filePathWithExt");

      // Check if file already exists
      if (!forceRedownload && await fileExists(filePathWithExt)) {
        return DownloadResult(filePath: filePathWithExt, mimeType: getMimeType(filePathWithExt), fileExtension: extension, alreadyExists: true);
      }

      // Download file with progress
      final response = await _dio.download(
        url,
        filePathWithExt,
        cancelToken: cancelToken,
        onReceiveProgress: onProgress,
        options: Options(responseType: ResponseType.bytes, followRedirects: true),
      );

      // SharePoint / OneDrive download URLs (e.g. download.aspx?...) carry no
      // usable extension in the path, so the file lands without a type and
      // OpenFilex can't open it. Trust the server Content-Type header to
      // recover the real extension and rename the file accordingly.
      final headerExt = _extensionFromContentType(
        response.headers.value(Headers.contentTypeHeader),
      );
      if (headerExt.isNotEmpty &&
          !filePathWithExt.toLowerCase().endsWith(headerExt)) {
        final corrected = await _ensureExtension(filePathWithExt, headerExt);
        return DownloadResult(
          filePath: corrected,
          mimeType: getMimeType(corrected),
          fileExtension: headerExt,
          alreadyExists: false,
        );
      }

      return DownloadResult(filePath: filePathWithExt, mimeType: getMimeType(filePathWithExt), fileExtension: extension, alreadyExists: false);
    } catch (e) {
      kPrint("error on downloading : ${e.toString()}");
      rethrow;
    }
  }

  Future<void> downloadAndViewFile({required String url, String? originalName}) async {
    // Check if it's already a local file
    if (url.startsWith('/') || url.startsWith('file://') || url.startsWith('content://')) {
      final path = url.startsWith('file://') ? url.substring(7) : url;
      final file = File(path);
      if (await file.exists()) {
        kPrint("Opening local file: $path");
        await OpenFilex.open(path, type: getMimeType(path));
        return;
      }
    }

    String fileName = generateFileName(originalName: originalName, url: url);
    final result = await showDialog<DownloadResult?>(
      context: AppNavigator.context!,
      barrierDismissible: false,
      builder: (context) => DownloadProgressDialog(
        url: url,
        fileName: fileName,
        onDownload: (url, fileName, onProgress, cancelToken) =>
            downloadFile(url: url, fileName: fileName, onProgress: onProgress, cancelToken: cancelToken, forceRedownload: false),
      ),
    );
    if (result != null) {
      kPrint(result.filePath);
      kPrint(result.mimeType);
      await OpenFilex.open(result.filePath, type: result.mimeType);
    }
  }

  /// Request storage permission
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Check Android version
      final androidInfo = await _getAndroidVersion();

      if (androidInfo >= 33) {
        // Android 13+ - App-specific directories (getTemporaryDirectory)
        // do not require general storage or photos permissions.
        return true;
      } else {
        // Android 12 and below - Request storage permission
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        return status.isGranted || status.isLimited;
      }
    } else if (Platform.isIOS) {
      // iOS - App documents directory doesn't require explicit permissions
      // when downloading generic files / documents.
      return true;
    }

    return true;
  }

  /// Get Android SDK version
  Future<int> _getAndroidVersion() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt;
  }

  static const _knownExtensions = {
    '.pdf', '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp',
    '.doc', '.docx', '.xls', '.xlsx', '.csv', '.txt', '.log',
  };

  /// Get file extension from a URL or path.
  ///
  /// Parses only the path component (query strings on SharePoint/OneDrive
  /// URLs contain dots that would otherwise be mistaken for an extension)
  /// and only accepts a known file extension. Returns '' when unknown — the
  /// caller then relies on the server Content-Type to recover the type.
  String getFileExtension(String url) {
    try {
      final path = Uri.parse(url).path;
      final ext = p.extension(path).toLowerCase();
      if (_knownExtensions.contains(ext)) return ext;
    } catch (_) {}
    return '';
  }

  /// Map an HTTP Content-Type header to a file extension.
  String _extensionFromContentType(String? contentType) {
    if (contentType == null) return '';
    final ct = contentType.split(';').first.trim().toLowerCase();
    switch (ct) {
      case 'application/pdf':
        return '.pdf';
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      case 'image/gif':
        return '.gif';
      case 'application/msword':
        return '.doc';
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return '.docx';
      case 'application/vnd.ms-excel':
        return '.xls';
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return '.xlsx';
      case 'text/plain':
        return '.txt';
      default:
        return '';
    }
  }

  /// Rename a downloaded file to carry the given extension if it doesn't already.
  Future<String> _ensureExtension(String filePath, String ext) async {
    if (filePath.toLowerCase().endsWith(ext.toLowerCase())) return filePath;
    final newPath = '$filePath$ext';
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final renamed = await file.rename(newPath);
        return renamed.path;
      }
    } catch (_) {}
    return filePath;
  }

  /// Get MIME type from file path
  String getMimeType(String url) {
    // Fallback based on extension
    final extension = getFileExtension(url).toLowerCase();
    switch (extension) {
      case '.pdf':
        return 'application/pdf';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  /// Get file type category
  FileType getFileType(String filePath) {
    final extension = getFileExtension(filePath).toLowerCase();

    if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(extension)) {
      return FileType.image;
    } else if (['.pdf'].contains(extension)) {
      return FileType.pdf;
    } else if (['.doc', '.docx'].contains(extension)) {
      return FileType.document;
    } else if (['.xls', '.xlsx', '.csv'].contains(extension)) {
      return FileType.spreadsheet;
    } else if (['.txt', '.log'].contains(extension)) {
      return FileType.text;
    } else {
      return FileType.other;
    }
  }

  /// Generate unique filename with proper extension
  String generateFileName({String? originalName, required String url}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    String fileName = originalName ?? p.basenameWithoutExtension(url);
    // Get extension from original name or URL
    String extension = getFileExtension(fileName);
    if (extension.isEmpty) {
      extension = getFileExtension(url);
    }

    // Clean the base name
    String baseName = fileName;
    if (baseName.contains('.')) {
      baseName = baseName.substring(0, baseName.lastIndexOf('.'));
    }

    // Remove special characters from base name
    baseName = baseName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    baseName = baseName.replaceAll(RegExp(r'\s+'), '_');

    return '${'document'}_${baseName}_$timestamp$extension';
  }

  /// Generate unique filename
  // String generateFileName(String originalName, String? documentType) {
  //   final timestamp = DateTime.now().millisecondsSinceEpoch;
  //   final extension = originalName.contains('.') ? originalName.substring(originalName.lastIndexOf('.')) : '';
  //   final baseName = originalName.contains('.')
  //       ? originalName.substring(0, originalName.lastIndexOf('.'))
  //       : originalName;
  //
  //   return '${documentType ?? 'document'}_${baseName}_$timestamp$extension';
  // }

  /// Check if file exists
  Future<bool> fileExists(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// Delete file
  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Get file size
  Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  static Future<String> _getSafeFilePath(String fileName) async {
    Directory directory;

    if (Platform.isAndroid) {
      // Standard for downloads that shouldn't clutter the user's gallery
      directory = await getTemporaryDirectory();
    } else {
      // Standard for iOS to ensure the file is accessible to the 'Open' intent
      directory = await getApplicationDocumentsDirectory();
    }

    return "${directory.path}/$fileName";
  }
}

/// Download result with metadata
class DownloadResult {
  final String filePath;
  final String mimeType;
  final String fileExtension;
  final bool alreadyExists;

  DownloadResult({required this.filePath, required this.mimeType, required this.fileExtension, required this.alreadyExists});
}

/// File type categories
enum FileType { image, pdf, document, spreadsheet, text, other }
