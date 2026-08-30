import 'dart:async';
import 'dart:io';

import 'package:avislap/models/pending_upload_file.dart';
import 'package:avislap/utils/app_colors.dart';
import 'package:avislap/utils/app_icons.dart';
import 'package:avislap/utils/app_text.dart';
import 'package:avislap/widgets/app_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';

import '../../../services/api_exception.dart';
import '../../../services/app_api_service.dart';
import '../../../services/audit_draft_store.dart';
import '../../../services/session_service.dart';
import 'LavSafetyObservationScreen.dart';

class LAVSafetyScreen extends StatefulWidget {
  final bool restoreDraft;
  final String? initialShipNumber;
  final String? initialGateNumber;

  const LAVSafetyScreen({
    super.key,
    this.restoreDraft = false,
    this.initialShipNumber,
    this.initialGateNumber,
  });

  static const String draftStorageKey = 'lav_safety_observation_draft';
  static bool hasSavedDraft() => AuditDraftStore.hasDraft(draftStorageKey);
  static void clearSavedDraft() => AuditDraftStore.clearDraft(draftStorageKey);

  @override
  State<LAVSafetyScreen> createState() => _LAVSafetyScreenState();
}

class _LAVSafetyScreenState extends State<LAVSafetyScreen> {
  final AppApiService _api = Get.find<AppApiService>();
  final SessionService _session = Get.find<SessionService>();
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _didSubmitSuccessfully = false;
  List<Map<String, dynamic>> _gates = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _checklistItems = <Map<String, dynamic>>[];
  List<String> _gateOptions = const ['Please Select One'];
  final Map<String, String> _gateIdsByLabel = <String, String>{};
  bool _isGateLocked = false;
  // ── step: 0 = Job Details, 1 = Checklist, 2 = Notes/Submit
  int _step = 0;

  // ── Step 0 fields
  final _supervisorCtrl = TextEditingController();
  final _driverCtrl = TextEditingController();
  final _shipCtrl = TextEditingController();
  String _selectedGate = 'Please Select One';

  // ── Step 1 — checklist
  final Map<String, String?> _selectedValues = {};
  final Map<String, List<PendingUploadFile>> _uploadedImages = {};
  final ImagePicker _picker = ImagePicker();

  // ── Step 2 — notes + pictures
  final _otherFindingsCtrl = TextEditingController();
  final _additionalCtrl = TextEditingController();
  final List<PendingUploadFile> _step2Images = [];

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  static const double _cardRadius = 16;
  static const double _inputRadius = 12;

  String _normalizeGateValue(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^gate\s*'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .replaceAll(RegExp(r'0+([1-9])'), r'$1');
  }

  String _formatGateLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    return trimmed.toLowerCase().startsWith('gate ')
        ? trimmed
        : 'Gate $trimmed';
  }

  String? _resolveGateId(String selectedGate) {
    final direct = _gateIdsByLabel[selectedGate];
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final normalizedSelected = _normalizeGateValue(selectedGate);
    for (final entry in _gateIdsByLabel.entries) {
      if (_normalizeGateValue(entry.key) == normalizedSelected &&
          entry.value.isNotEmpty) {
        return entry.value;
      }
    }

    return null;
  }

  // ─────────────────────────────────────────────
  static String _formatCurrentDate() {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}/'
        '${now.day.toString().padLeft(2, '0')}/${now.year}';
  }

  Future<void> _pickImagesFor(String key) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (image != null) {
      final upload = PendingUploadFile(localFile: File(image.path));
      setState(() {
        _uploadedImages[key] = [
          ...(_uploadedImages[key] ?? <PendingUploadFile>[]),
          upload,
        ];
      });
      unawaited(_uploadPendingImage(upload));
    }
  }

  Future<void> _pickStep2Images() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (image != null) {
      final upload = PendingUploadFile(localFile: File(image.path));
      setState(() {
        _step2Images.add(upload);
      });
      unawaited(_uploadPendingImage(upload));
    }
  }

  @override
  void initState() {
    super.initState();
    _supervisorCtrl.text = _session.fullName;
    _loadFormData();
  }

  @override
  void dispose() {
    _persistDraftIfNeeded();
    _supervisorCtrl.dispose();
    _driverCtrl.dispose();
    _shipCtrl.dispose();
    _otherFindingsCtrl.dispose();
    _additionalCtrl.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    setState(() => _isLoading = true);
    try {
      final stationId = _session.activeStationId;
      final results = await Future.wait([
        _api.getLavSafetyChecklistItems(),
        if (stationId.isNotEmpty)
          _api.getGates(stationId)
        else
          Future.value([]),
      ]);

      _checklistItems = List<Map<String, dynamic>>.from(results[0]).where((
        item,
      ) {
        final checklistItemId = (item['id'] as String?) ?? '';
        return checklistItemId.isNotEmpty;
      }).toList();
      _gates = List<Map<String, dynamic>>.from(results[1]);
      _gateIdsByLabel.clear();
      for (final gate in _gates) {
        final gateId = gate['id']?.toString() ?? '';
        final gateCode = gate['gateCode']?.toString().trim() ?? '';
        if (gateId.isEmpty || gateCode.isEmpty) {
          continue;
        }

        final label = gateCode.toLowerCase().startsWith('gate ')
            ? gateCode
            : 'Gate $gateCode';
        _gateIdsByLabel[label] = gateId;
        _gateIdsByLabel[gateCode] = gateId;
      }
      _gateOptions = [
        'Please Select One',
        ..._gates.map(
          (gate) => (gate['gateCode'] as String?) ?? 'Unknown Gate',
        ),
      ];

      // Auto-populate initial values
      if (widget.initialShipNumber != null &&
          widget.initialShipNumber!.isNotEmpty) {
        _shipCtrl.text = widget.initialShipNumber!.trim().toUpperCase();
      }

      if (widget.initialGateNumber != null &&
          widget.initialGateNumber!.isNotEmpty) {
        final gText = widget.initialGateNumber!.trim().toLowerCase();

        // Skip if the provided gate is just a placeholder
        if (gText != "—" && gText != "n/a" && gText != "unknown") {
          // Normalization: remove non-alphanumeric, then remove leading zeros from numbers
          final normalizedInput = _normalizeGateValue(gText);

          final match = _gateOptions.firstWhereOrNull((opt) {
            if (opt.toLowerCase().contains('select')) return false;
            final normalizedOpt = _normalizeGateValue(opt);
            return normalizedOpt == normalizedInput ||
                normalizedOpt.contains(normalizedInput) ||
                normalizedInput.contains(normalizedOpt);
          });

          if (match != null) {
            _selectedGate = match;
            _isGateLocked = true;
          } else {
            final fallbackLabel = _formatGateLabel(widget.initialGateNumber!);
            if (!_gateOptions.contains(fallbackLabel)) {
              _gateOptions = [
                _gateOptions.first,
                fallbackLabel,
                ..._gateOptions.skip(1),
              ];
            }
            _selectedGate = fallbackLabel;
            _isGateLocked = true;
          }
        }
      }

      if (widget.restoreDraft) {
        _restoreDraft();
      }
    } catch (error) {
      final message = error is ApiException
          ? error.message
          : 'Unable to load the LAV checklist right now.';
      Get.snackbar(
        'Load Failed',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic>? _selectedGateRecord() {
    final gateId = _resolveGateId(_selectedGate);
    if (gateId == null || gateId.isEmpty) {
      return null;
    }
    for (final gate in _gates) {
      if (gate['id']?.toString() == gateId) {
        return gate;
      }
    }
    return null;
  }

  bool _validateStep0() {
    if (_driverCtrl.text.trim().isEmpty || _shipCtrl.text.trim().isEmpty) {
      Get.snackbar(
        'Incomplete',
        'Please complete the driver and ship details before continuing.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }

    if (_selectedGateRecord() == null) {
      Get.snackbar(
        'Incomplete',
        'Please select a gate before continuing.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }

    return true;
  }

  bool _validateStep1() {
    if (_checklistItems.isEmpty) {
      Get.snackbar(
        'Unavailable',
        'No active LAV checklist items are configured right now.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }

    for (final item in _checklistItems) {
      final checklistItemId = (item['id'] as String?) ?? '';
      if (checklistItemId.isEmpty) {
        continue;
      }

      if ((_selectedValues[checklistItemId] ?? '').isEmpty) {
        Get.snackbar(
          'Incomplete',
          'Please mark Pass or Fail for every checklist item.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _uploadPendingImage(PendingUploadFile upload) async {
    setState(() {
      upload.status = PendingUploadStatus.uploading;
      upload.progress = 0;
      upload.errorMessage = null;
    });

    try {
      final uploaded = await _api.uploadFile(
        upload.localFile,
        category: 'IMAGE',
        onSendProgress: (sent, total) {
          if (!mounted) {
            return;
          }
          setState(() {
            upload.progress = total <= 0 ? 0 : sent / total;
          });
        },
      );
      final fileId = uploaded['id']?.toString().trim() ?? '';
      if (fileId.isEmpty) {
        throw const ApiException('Image upload did not return a file id.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        upload.fileId = fileId;
        upload.cloudinaryUrl = uploaded['cloudinaryUrl']?.toString().trim();
        upload.progress = 1;
        upload.status = PendingUploadStatus.completed;
        upload.errorMessage = null;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        upload.status = PendingUploadStatus.failed;
        upload.errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        upload.status = PendingUploadStatus.failed;
        upload.errorMessage = 'Unable to upload this image right now.';
      });
    }
  }

  List<String> _uploadedFileIds(List<PendingUploadFile> uploads) {
    final fileIds = <String>[];
    for (final upload in uploads) {
      final fileId = upload.fileId?.trim() ?? '';
      if (upload.isCompleted && fileId.isNotEmpty) {
        fileIds.add(fileId);
      }
    }
    return fileIds;
  }

  String? _imageUploadBlockerMessage() {
    final uploads = <PendingUploadFile>[
      ..._step2Images,
      ..._uploadedImages.values.expand((entries) => entries),
    ];

    if (uploads.any((upload) => upload.isUploading)) {
      return 'Please wait for all selected images to finish uploading.';
    }
    if (uploads.any((upload) => upload.hasError)) {
      return 'Retry or remove failed image uploads before sending the report.';
    }
    return null;
  }

  Future<String> _uploadSignature() async {
    final bytes = await _signatureController.toPngBytes();
    if (bytes == null || bytes.isEmpty) {
      throw const ApiException('A signature is required before submission.');
    }

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/lav-signature-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);

    final uploaded = await _api.uploadFile(file, category: 'SIGNATURE');
    final fileId = uploaded['id'] as String?;
    if (fileId == null || fileId.isEmpty) {
      throw const ApiException('Unable to upload the signature.');
    }

    return fileId;
  }

  String _buildAdditionalNotes() {
    final supervisor = _supervisorCtrl.text.trim();
    final notes = _additionalCtrl.text.trim();
    if (supervisor.isEmpty) {
      return notes;
    }
    if (notes.isEmpty) {
      return 'Supervisor/Lead: $supervisor';
    }
    return 'Supervisor/Lead: $supervisor\n$notes';
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) {
      return;
    }
    if (!_validateStep1()) {
      return;
    }
    if (_selectedGateRecord() == null) {
      Get.snackbar(
        'Incomplete',
        'Please return to the first step and select a gate.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }
    final uploadBlocker = _imageUploadBlockerMessage();
    if (uploadBlocker != null) {
      Get.snackbar(
        'Uploads Pending',
        uploadBlocker,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final gate = _selectedGateRecord();
      final signatureFileId = await _uploadSignature();
      final generalPictureFileIds = _uploadedFileIds(_step2Images);

      final responses = <Map<String, dynamic>>[];
      for (final item in _checklistItems) {
        final checklistItemId = (item['id'] as String?) ?? '';
        if (checklistItemId.isEmpty) {
          continue;
        }

        final selectedValue = (_selectedValues[checklistItemId] ?? '')
            .toUpperCase();
        if (selectedValue.isEmpty) {
          throw ApiException('Every checklist item must be marked.');
        }

        final imageFileIds = _uploadedFileIds(
          _uploadedImages[checklistItemId] ?? const <PendingUploadFile>[],
        );

        responses.add({
          'checklistItemId': checklistItemId,
          'response': selectedValue == 'PASS' ? 'PASS' : 'FAIL',
          'imageFileIds': imageFileIds,
        });
      }

      await _api.createLavSafetyObservation({
        'driverName': _driverCtrl.text.trim(),
        'shipNumber': _shipCtrl.text.trim(),
        'gateId': gate?['id'],
        'responses': responses,
        'signatureFileId': signatureFileId,
        'otherFindings': _otherFindingsCtrl.text.trim(),
        'additionalNotes': _buildAdditionalNotes(),
        'generalPictureFileIds': generalPictureFileIds,
      });

      if (!mounted) {
        return;
      }

      _didSubmitSuccessfully = true;
      LAVSafetyScreen.clearSavedDraft();
      Get.snackbar(
        "Success",
        "LAV Safety Report Sent Successfully",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      Get.off(() => const LavSafetyObservationScreen());
    } on ApiException catch (error) {
      Get.snackbar(
        'Submission Failed',
        error.message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } catch (_) {
      Get.snackbar(
        'Submission Failed',
        'Unable to submit the LAV safety report right now.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.mainAppColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () =>
              _step > 0 ? setState(() => _step--) : Navigator.pop(context),
        ),
        title: AppText(
          "LAV Safety Observation",
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined, color: Colors.white),
            onPressed: _saveDraftManually,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
            onPressed: () => _showInstructions(context),
          ),
        ],
      ),
      body: SafeArea(
        top: true,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _step == 0
            ? _buildStep0()
            : _step == 1
            ? _buildStep1()
            : _buildStep2(),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // STEP 0 — Job Details
  // ══════════════════════════════════════════════
  Widget _buildStep0() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _buildSectionCard(
              children: [
                _buildRequiredLabel("Date and Time"),
                _buildReadOnlyDateField(),
                _buildRequiredLabel("Supervisor/Lead"),
                _buildTextField(
                  "Enter supervisor or lead name",
                  controller: _supervisorCtrl,
                ),
                _buildRequiredLabel("Driver"),
                _buildTextField("Enter Driver's Name", controller: _driverCtrl),
                _buildRequiredLabel("Ship"),
                _buildTextField("Enter Ship Number", controller: _shipCtrl),
                _buildRequiredLabel("Gate"),
                if (_isGateLocked)
                  _buildLockedField(_selectedGate)
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: AppDropdown(
                      hint: "Please Select One",
                      items: _gateOptions,
                      value: _selectedGate,
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _selectedGate = value);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        _buildNextButton(() {
          if (_validateStep0()) {
            setState(() => _step = 1);
          }
        }),
      ],
    );
  }

  // ══════════════════════════════════════════════
  // STEP 1 — Inspection Checklist
  // ══════════════════════════════════════════════
  Widget _buildStep1() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "Inspection Checklist" heading
                AppText(
                  "Inspection Checklist",
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mainAppColor,
                ),
                const SizedBox(height: 20),

                _buildSectionCard(
                  children: _checklistItems.isEmpty
                      ? [
                          AppText(
                            'No active checklist items are configured for this station.',
                            fontSize: 14,
                            color: AppColors.grey,
                          ),
                        ]
                      : List<Widget>.generate(_checklistItems.length, (index) {
                          final item = _checklistItems[index];
                          final checklistItemId = (item['id'] as String?) ?? '';
                          final checklistLabel = (item['label'] as String?)
                              ?.trim();
                          final checklistCode = (item['code'] as String?)
                              ?.trim();
                          final checklistDescription =
                              (item['description'] as String?)?.trim();

                          return _buildAuditRow(
                            checklistLabel?.isNotEmpty == true
                                ? checklistLabel!
                                : checklistCode?.isNotEmpty == true
                                ? checklistCode!
                                : 'Checklist Item',
                            checklistItemId,
                            subtitle: checklistDescription?.isNotEmpty == true
                                ? checklistDescription
                                : null,
                            isLast: index == _checklistItems.length - 1,
                            showImageUpload: true,
                          );
                        }),
                ),
              ],
            ),
          ),
        ),
        _buildNextButton(() {
          if (_validateStep1()) {
            setState(() => _step = 2);
          }
        }),
      ],
    );
  }

  // ══════════════════════════════════════════════
  // STEP 2 — Other Findings + Notes + Pictures
  // ══════════════════════════════════════════════
  Widget _buildStep2() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _buildSectionCard(
              children: [
                _buildNoteField(
                  "Other Findings",
                  "Enter any additional findings or notes...",
                  controller: _otherFindingsCtrl,
                ),
                _buildNoteField(
                  "Additional Notes",
                  "Enter any additional findings or notes...",
                  controller: _additionalCtrl,
                ),
                const SizedBox(height: 4),
                AppText(
                  "Pictures",
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mainAppColor,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickStep2Images,
                  child: _buildUploadBox(),
                ),
                if (_step2Images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _step2Images.map((upload) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              upload.localFile,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                          if (upload.isUploading || upload.hasError)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.45),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: upload.isUploading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : IconButton(
                                          onPressed: () => unawaited(
                                            _uploadPendingImage(upload),
                                          ),
                                          icon: const Icon(
                                            Icons.refresh_rounded,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 3,
                            right: 3,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _step2Images.remove(upload)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                // Beautiful Signature Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.draw_rounded,
                                color: AppColors.mainAppColor,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Digital Signature',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const Text(
                                ' *',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => _signatureController.clear(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Clear',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            border: Border.all(
                              color: AppColors.mainAppColor.withOpacity(0.3),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Center(
                                  child: Text(
                                    'Sign Here',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.withOpacity(0.3),
                                    ),
                                  ),
                                ),
                              ),
                              Signature(
                                controller: _signatureController,
                                height: 140,
                                backgroundColor: Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Submit button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainAppColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_inputRadius),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      "Send Report",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  bool _hasDraftContent() {
    return _step > 0 ||
        _driverCtrl.text.trim().isNotEmpty ||
        _shipCtrl.text.trim().isNotEmpty ||
        _otherFindingsCtrl.text.trim().isNotEmpty ||
        _additionalCtrl.text.trim().isNotEmpty ||
        _selectedGate != 'Please Select One' ||
        _selectedValues.isNotEmpty ||
        _uploadedImages.values.any((images) => images.isNotEmpty) ||
        _step2Images.isNotEmpty;
  }

  void _persistDraftIfNeeded() {
    if (_isSubmitting || _didSubmitSuccessfully) {
      return;
    }

    if (!_hasDraftContent()) {
      LAVSafetyScreen.clearSavedDraft();
      return;
    }

    AuditDraftStore.saveDraft(
      id: LAVSafetyScreen.draftStorageKey,
      type: AuditDraftType.lavSafetyObservation,
      title: 'LAV Safety Observation',
      subtitle: 'Resume the LAV checklist, notes, and uploaded pictures.',
      shipNumber: _shipCtrl.text.trim(),
      gate: _selectedGate,
      payload: {
        'savedAt': DateTime.now().toIso8601String(),
        'step': _step,
        'supervisorName': _supervisorCtrl.text.trim(),
        'driverName': _driverCtrl.text.trim(),
        'shipNumber': _shipCtrl.text.trim(),
        'selectedGate': _selectedGate,
        'selectedValues': Map<String, String?>.from(_selectedValues),
        'uploadedImages': {
          for (final entry in _uploadedImages.entries)
            if (entry.value.isNotEmpty)
              entry.key: entry.value
                  .map(_serializePendingUpload)
                  .toList(growable: false),
        },
        'otherFindings': _otherFindingsCtrl.text.trim(),
        'additionalNotes': _additionalCtrl.text.trim(),
        'step2Images': _step2Images
            .map(_serializePendingUpload)
            .toList(growable: false),
      },
    );
  }

  void _restoreDraft() {
    final draft = AuditDraftStore.getPayload(LAVSafetyScreen.draftStorageKey);
    if (draft == null || draft.isEmpty) {
      return;
    }

    _step = ((draft['step'] as num?)?.toInt() ?? 0).clamp(0, 2).toInt();
    _supervisorCtrl.text =
        draft['supervisorName']?.toString() ?? _supervisorCtrl.text;
    _driverCtrl.text = draft['driverName']?.toString() ?? '';
    _shipCtrl.text = draft['shipNumber']?.toString() ?? '';

    final draftGate = draft['selectedGate']?.toString().trim() ?? '';
    if (!_isGateLocked &&
        draftGate.isNotEmpty &&
        _gateOptions.contains(draftGate)) {
      _selectedGate = draftGate;
    }

    _selectedValues
      ..clear()
      ..addAll(_readNullableStringMap(draft['selectedValues']));

    _uploadedImages
      ..clear()
      ..addAll(_readUploadMap(draft['uploadedImages']));

    _otherFindingsCtrl.text = draft['otherFindings']?.toString() ?? '';
    _additionalCtrl.text = draft['additionalNotes']?.toString() ?? '';

    _step2Images
      ..clear()
      ..addAll(_deserializeUploads(draft['step2Images']));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      Get.snackbar(
        'Draft Restored',
        'Your LAV Safety Observation draft is ready to continue.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.mainAppColor,
        colorText: Colors.white,
      );
    });
  }

  Map<String, dynamic> _serializePendingUpload(PendingUploadFile upload) {
    return {
      'path': upload.localFile.path,
      'fileId': upload.fileId,
      'cloudinaryUrl': upload.cloudinaryUrl,
      'progress': upload.progress,
      'status': upload.status.name,
      'errorMessage': upload.errorMessage,
    };
  }

  PendingUploadFile? _deserializePendingUpload(dynamic raw) {
    final map = AuditDraftStore.normalizeMap(raw);
    final path = map['path']?.toString().trim() ?? '';
    if (path.isEmpty) {
      return null;
    }

    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }

    final rawStatus = map['status']?.toString().trim().toLowerCase() ?? '';
    var status = switch (rawStatus) {
      'completed' => PendingUploadStatus.completed,
      'failed' => PendingUploadStatus.failed,
      _ => PendingUploadStatus.failed,
    };
    final fileId = map['fileId']?.toString().trim();
    if (status == PendingUploadStatus.completed &&
        (fileId == null || fileId.isEmpty)) {
      status = PendingUploadStatus.failed;
    }

    return PendingUploadFile(
      localFile: file,
      fileId: fileId?.isNotEmpty == true ? fileId : null,
      cloudinaryUrl: map['cloudinaryUrl']?.toString().trim(),
      progress: (map['progress'] as num?)?.toDouble() ?? 0,
      status: status,
      errorMessage: status == PendingUploadStatus.failed
          ? (map['errorMessage']?.toString().trim().isNotEmpty == true
                ? map['errorMessage']?.toString().trim()
                : 'Upload was interrupted. Tap retry.')
          : map['errorMessage']?.toString().trim(),
    );
  }

  List<PendingUploadFile> _deserializeUploads(dynamic raw) {
    if (raw is! List) {
      return const <PendingUploadFile>[];
    }

    return raw
        .map(_deserializePendingUpload)
        .whereType<PendingUploadFile>()
        .toList(growable: false);
  }

  Map<String, List<PendingUploadFile>> _readUploadMap(dynamic raw) {
    if (raw is! Map) {
      return <String, List<PendingUploadFile>>{};
    }

    final mapped = <String, List<PendingUploadFile>>{};
    raw.forEach((key, value) {
      final uploads = _deserializeUploads(value);
      if (uploads.isNotEmpty) {
        mapped[key.toString()] = uploads;
      }
    });
    return mapped;
  }

  Map<String, String?> _readNullableStringMap(dynamic raw) {
    if (raw is! Map) {
      return <String, String?>{};
    }

    final mapped = <String, String?>{};
    raw.forEach((key, value) {
      final normalizedKey = key.toString().trim();
      if (normalizedKey.isEmpty) {
        return;
      }
      final normalizedValue = value?.toString().trim();
      mapped[normalizedKey] = normalizedValue == null || normalizedValue.isEmpty
          ? null
          : normalizedValue;
    });
    return mapped;
  }

  void _saveDraftManually() {
    _persistDraftIfNeeded();
    if (!LAVSafetyScreen.hasSavedDraft()) {
      Get.snackbar(
        'Nothing To Save',
        'Add a few observation details first, then save the draft.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    Get.snackbar(
      'Draft Saved',
      'LAV Safety Observation draft saved successfully.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.mainAppColor,
      colorText: Colors.white,
    );
  }

  // ─────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────

  Widget _buildAuditRow(
    String title,
    String key, {
    String? subtitle,
    bool showImageUpload = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRequiredLabel(title),
          if (subtitle != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppText(subtitle, fontSize: 13, color: AppColors.grey),
            ),
          ] else
            const SizedBox(height: 8),

          // Pass / Fail — 2 buttons (N/A removed)
          Row(
            children: [
              _auditChip(key, "Pass", AppIcons.correct, AppColors.green),
              const SizedBox(width: 8),
              _auditChip(key, "Fail", AppIcons.cancel, AppColors.red),
            ],
          ),

          if (showImageUpload) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _pickImagesFor(key),
              child: _buildUploadBox(),
            ),
            // thumbnails
            if ((_uploadedImages[key] ?? []).isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (_uploadedImages[key] ?? []).map((upload) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          upload.localFile,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (upload.isUploading || upload.hasError)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: upload.isUploading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : IconButton(
                                      onPressed: () => unawaited(
                                        _uploadPendingImage(upload),
                                      ),
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(
                            () => _uploadedImages[key]!.remove(upload),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // Pass / Fail chip (with svg icon)
  Widget _auditChip(String key, String value, String svgIcon, Color color) {
    bool isSelected = _selectedValues[key] == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedValues[key] = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.12)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(_inputRadius),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                svgIcon,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(
                  isSelected ? color : AppColors.grey,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 5),
              AppText(
                value,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : AppColors.from_heading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequiredLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(
            text,
            fontWeight: FontWeight.w600,
            color: AppColors.mainAppColor,
            fontSize: 14,
          ),
          const Text(
            " *",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.red,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyDateField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _formatCurrentDate(),
              style: TextStyle(color: AppColors.dark, fontSize: 15),
            ),
          ),
          Icon(Icons.calendar_month_outlined, color: AppColors.grey, size: 20),
        ],
      ),
    );
  }

  Widget _buildSectionCard({String? title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && title.isNotEmpty) ...[
            AppText(
              title,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.dark,
            ),
            const SizedBox(height: 16),
          ],
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(String hint, {TextEditingController? controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppColors.from_heading.withOpacity(0.8)),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: AppColors.mainAppColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildLockedField(String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.lock_outline_rounded,
              color: AppColors.from_heading.withOpacity(0.8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteField(
    String label,
    String hint, {
    TextEditingController? controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            label,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.mainAppColor,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AppColors.from_heading.withOpacity(0.8),
              ),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_inputRadius),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_inputRadius),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_inputRadius),
                borderSide: BorderSide(
                  color: AppColors.mainAppColor,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadBox() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.camera_alt_outlined, color: AppColors.grey, size: 20),
          const SizedBox(width: 8),
          Text(
            "Capture image",
            style: TextStyle(color: AppColors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton(VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.mainAppColor,
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: const Text(
            'NEXT',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  void _showInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: AppColors.mainAppColor,
              size: 26,
            ),
            const SizedBox(width: 10),
            Text(
              "Instructions",
              style: TextStyle(
                color: AppColors.mainAppColor,
                fontWeight: FontWeight.w500,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conduct the LAV Audit as you observe the Drivers, don\'t wait till the end of the shift to submit.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.dark,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Please submit this with as much detail as possible 2 Observations per Shift',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.dark,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Take pictures of the Driver following the proper procedures.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.mainAppColor,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "OK",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.mainAppColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
