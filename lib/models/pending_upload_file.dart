import 'dart:io';

enum PendingUploadStatus { uploading, completed, failed }

class PendingUploadFile {
  PendingUploadFile({
    required this.localFile,
    this.fileId,
    this.cloudinaryUrl,
    this.progress = 0,
    this.status = PendingUploadStatus.uploading,
    this.errorMessage,
  });

  final File localFile;
  String? fileId;
  String? cloudinaryUrl;
  double progress;
  PendingUploadStatus status;
  String? errorMessage;

  bool get isUploading => status == PendingUploadStatus.uploading;
  bool get isCompleted =>
      status == PendingUploadStatus.completed &&
      (fileId?.trim().isNotEmpty ?? false);
  bool get hasError => status == PendingUploadStatus.failed;
}
