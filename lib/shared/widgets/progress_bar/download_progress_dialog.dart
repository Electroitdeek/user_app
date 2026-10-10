import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/api/api_error_handler.dart';
import '../../../core/services/file_downloading_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class DownloadProgressDialog extends StatefulWidget {
  final String url;
  final String fileName;
  final Future<DownloadResult> Function(
    String url,
    String fileName,
    Function(int, int) onProgress,
    CancelToken cancelToken,
  )
  onDownload;

  const DownloadProgressDialog({super.key, required this.url, required this.fileName, required this.onDownload});

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  bool _isDownloading = true;
  bool _isCancelled = false;
  String? _errorMessage;
  final CancelToken _cancelToken = CancelToken();

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final result = await widget.onDownload(widget.url, widget.fileName, _onProgress, _cancelToken);

      if (mounted && !_isCancelled) {
        // Automatically return the result to close the dialog and open the file
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted && !_isCancelled) {
        setState(() {
          _isDownloading = false;
          _errorMessage = ApiErrorHandler.getErrorMessage(e);
        });
      }
    }
  }

  void _onProgress(int received, int total) {
    if (mounted && !_isCancelled) {
      setState(() {
        _receivedBytes = received;
        _totalBytes = total;
        _progress = total > 0 ? (received / total) : 0.0;
      });
    }
  }

  void _cancelDownload() {
    setState(() {
      _isCancelled = true;
    });
    _cancelToken.cancel('Download cancelled by user');
    Navigator.of(context).pop(null);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDownloading,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _cancelDownload();
      },
      child: Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: kBlackColor.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isDownloading) ...[
                _buildDownloadingUI(),
              ] else if (_errorMessage != null) ...[
                _buildErrorUI(),
              ] else ...[
                // This state should be short-lived due to auto-pop
                const SizedBox(
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(color: kSuccessColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadingUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.file_download_outlined, size: 20, color: kPrimaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Downloading File', style: kTextBold().copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    widget.fileName,
                    style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _cancelDownload,
              icon: Icon(Icons.close_rounded, size: 20, color: kTextSecondaryColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 6,
            backgroundColor: kGreyColor2,
            valueColor: const AlwaysStoppedAnimation<Color>(kPrimaryColor),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: kTextBold(color: kPrimaryColor).copyWith(fontSize: 12),
            ),
            if (_totalBytes > 0)
              Flexible(
                child: Text(
                  '${_formatBytes(_receivedBytes)} of ${_formatBytes(_totalBytes)}',
                  style: kTextMedium(color: kTextSecondaryColor).copyWith(fontSize: 11),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kErrorColor.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline_rounded, size: 32, color: kErrorColor),
        ),
        const SizedBox(height: 20),
        Text('Download Failed', style: kTextBold().copyWith(fontSize: 18)),
        const SizedBox(height: 12),
        Text(
          _errorMessage ?? 'Something went wrong while downloading',
          style: kTextNormal(color: kTextSecondaryColor).copyWith(fontSize: 13),
          textAlign: TextAlign.center,
          maxLines: 3,
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Close', style: kTextMedium()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                    _isDownloading = true;
                    _progress = 0;
                  });
                  _startDownload();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Retry', style: kTextBold(color: kWhiteColor)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    if (!_cancelToken.isCancelled) {
      _cancelToken.cancel();
    }
    super.dispose();
  }
}
