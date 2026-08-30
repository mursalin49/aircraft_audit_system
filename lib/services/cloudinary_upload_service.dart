import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../config/app_env.dart';
import 'api_exception.dart';

class CloudinarySignedUploadPayload {
  CloudinarySignedUploadPayload({
    required this.signature,
    required this.timestamp,
    required this.apiKey,
    required this.cloudName,
    this.folder,
  });

  final String signature;
  final int timestamp;
  final String apiKey;
  final String cloudName;
  final String? folder;

  factory CloudinarySignedUploadPayload.fromMap(Map<String, dynamic> map) {
    final folderValue = map['folder']?.toString().trim() ?? '';
    return CloudinarySignedUploadPayload(
      signature: map['signature']?.toString().trim() ?? '',
      timestamp: int.tryParse(map['timestamp']?.toString() ?? '') ?? 0,
      apiKey: map['api_key']?.toString().trim() ?? '',
      cloudName: map['cloud_name']?.toString().trim() ?? '',
      folder: folderValue.isEmpty ? null : folderValue,
    );
  }

  bool get isValid =>
      signature.isNotEmpty &&
      timestamp > 0 &&
      apiKey.isNotEmpty &&
      cloudName.isNotEmpty;
}

class CloudinaryUploadResult {
  CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
    required this.bytes,
    required this.originalFileName,
    required this.mimeType,
    required this.format,
    required this.resourceType,
  });

  final String secureUrl;
  final String publicId;
  final int bytes;
  final String originalFileName;
  final String mimeType;
  final String format;
  final String resourceType;
}

class CloudinaryUploadService {
  CloudinaryUploadService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static String get _cloudName => AppEnv.cloudinaryCloudName;

  static String get _unsignedPreset => AppEnv.cloudinaryUnsignedPreset;

  bool get hasUnsignedUploadConfig =>
      _cloudName.trim().isNotEmpty && _unsignedPreset.trim().isNotEmpty;

  Future<String> uploadImage(File imageFile) async {
    final result = await uploadFile(imageFile);
    return result.secureUrl;
  }

  Future<CloudinaryUploadResult> uploadFile(
    File imageFile, {
    ProgressCallback? onProgress,
    CloudinarySignedUploadPayload? signedPayload,
    bool skipCompression = false,
  }) async {
    _ensureConfigured(signedPayload);

    final uploadFile = skipCompression
        ? imageFile
        : await _compressImage(imageFile);
    final compressedBytes = await uploadFile.readAsBytes();
    final originalFileName = path.basename(imageFile.path);
    final mimeType = _inferMimeType(uploadFile.path);
    final signedCloudName = signedPayload?.cloudName.trim() ?? '';
    final cloudName = signedCloudName.isNotEmpty ? signedCloudName : _cloudName;
    final signedFolder = signedPayload?.folder?.trim() ?? '';

    final formData = <String, dynamic>{
      'file': MultipartFile.fromBytes(
        compressedBytes,
        filename: path.basename(uploadFile.path),
      ),
      if (signedPayload != null) ...{
        'api_key': signedPayload.apiKey,
        'timestamp': signedPayload.timestamp.toString(),
        'signature': signedPayload.signature,
        if (signedFolder.isNotEmpty) 'folder': signedFolder,
      } else
        'upload_preset': _unsignedPreset,
    };

    final response = await _dio.post<Map<String, dynamic>>(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      data: FormData.fromMap(formData),
      options: Options(headers: const {'Accept': 'application/json'}),
      onSendProgress: onProgress,
    );

    final data = response.data;
    if (data == null) {
      throw const ApiException('Cloudinary did not return an upload response.');
    }

    final secureUrl = data['secure_url']?.toString().trim() ?? '';
    if (secureUrl.isEmpty) {
      throw const ApiException(
        'Cloudinary upload finished, but no secure URL was returned.',
      );
    }

    return CloudinaryUploadResult(
      secureUrl: secureUrl,
      publicId: data['public_id']?.toString().trim() ?? '',
      bytes: (data['bytes'] as num?)?.round() ?? compressedBytes.length,
      originalFileName: originalFileName,
      mimeType: mimeType,
      format:
          data['format']?.toString().trim() ?? _inferFormat(uploadFile.path),
      resourceType: data['resource_type']?.toString().trim() ?? 'image',
    );
  }

  Future<File> _compressImage(File imageFile) async {
    final tempDir = await getTemporaryDirectory();
    final extension = path.extension(imageFile.path).toLowerCase();
    final usePng = extension == '.png';
    final targetPath = path.join(
      tempDir.path,
      'cloudinary-${DateTime.now().microsecondsSinceEpoch}${usePng ? '.png' : '.jpg'}',
    );

    final compressed = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      targetPath,
      quality: 85,
      minWidth: 1280,
      minHeight: 1280,
      keepExif: false,
      format: usePng ? CompressFormat.png : CompressFormat.jpeg,
    );

    if (compressed == null) {
      return imageFile;
    }

    return File(compressed.path);
  }

  void _ensureConfigured(CloudinarySignedUploadPayload? signedPayload) {
    if (signedPayload != null) {
      if (!signedPayload.isValid) {
        throw const ApiException(
          'Cloudinary signed upload is not configured correctly.',
        );
      }
      return;
    }

    if (_cloudName.trim().isEmpty || _unsignedPreset.trim().isEmpty) {
      throw const ApiException(
        'Cloudinary upload is not configured. Set CLOUDINARY_CLOUD_NAME and CLOUDINARY_UNSIGNED_PRESET in .env or with --dart-define.',
      );
    }
  }

  String _inferMimeType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      case '.jpeg':
      case '.jpg':
      default:
        return 'image/jpeg';
    }
  }

  String _inferFormat(String filePath) {
    final extension = path.extension(filePath).replaceFirst('.', '').trim();
    return extension.isEmpty ? 'jpg' : extension.toLowerCase();
  }
}
