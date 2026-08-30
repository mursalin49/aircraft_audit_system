import 'package:avislap/services/audit_draft_store.dart';
import 'package:avislap/views/forms/Cabin%20Quality%20Audit/CabinAudit.dart';
import 'package:avislap/views/forms/LAV%20Safety%20Observation/LAVSafety.dart';
import 'package:avislap/views/forms/cabin%20security%20search/cabin_secuirity.dart';
import 'package:avislap/views/forms/hidden_object_audit/hidden_object_audit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DraftAuditsScreen extends StatefulWidget {
  const DraftAuditsScreen({super.key});

  @override
  State<DraftAuditsScreen> createState() => _DraftAuditsScreenState();
}

class _DraftAuditsScreenState extends State<DraftAuditsScreen> {
  List<AuditDraftRecord> _drafts = const <AuditDraftRecord>[];

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  void _loadDrafts() {
    setState(() {
      _drafts = AuditDraftStore.allDrafts();
    });
  }

  Future<void> _openDraft(AuditDraftRecord draft) async {
    switch (draft.type) {
      case AuditDraftType.lavSafetyObservation:
        await Get.to(() => const LAVSafetyScreen(restoreDraft: true));
        break;
      case AuditDraftType.cabinQualityAudit:
        await Get.to(() => const CabinAuditScreen(restoreDraft: true));
        break;
      case AuditDraftType.cabinSecuritySearchTraining:
        await Get.to(() => const CabinQualityAuditScreenN(restoreDraft: true));
        break;
      case AuditDraftType.hiddenObjectAudit:
        await Get.to(
          () => const HiddenObjectAuditWorkflowScreen(restoreDraft: true),
        );
        break;
      default:
        Get.snackbar(
          'Draft Unavailable',
          'This draft type is not supported yet.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.black87,
          colorText: Colors.white,
        );
        return;
    }
    _loadDrafts();
  }

  Future<void> _deleteDraft(AuditDraftRecord draft) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete draft'),
            content: Text(
              'Remove the saved draft for ${draft.title}?',
              style: GoogleFonts.plusJakartaSans(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    AuditDraftStore.clearDraft(draft.id);
    _loadDrafts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Draft Audits',
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18.sp,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _drafts.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: () async => _loadDrafts(),
              child: ListView(
                padding: EdgeInsets.all(16.w),
                children: [
                  _buildHeaderCard(),
                  SizedBox(height: 16.h),
                  ..._drafts.map(_buildDraftCard),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0F172A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_drafts.length} saved ${_drafts.length == 1 ? "draft" : "drafts"}',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 22.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Jump back into the exact audit you paused, with the audit type clearly labeled.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.84),
              fontWeight: FontWeight.w500,
              fontSize: 13.sp,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88.w,
              height: 88.w,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(28.r),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 42.sp,
                color: const Color(0xFF475569),
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              'No saved drafts yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'When an audit is saved as a draft, it will appear here with its audit type and key flight details.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftCard(AuditDraftRecord draft) {
    final details = <String>[
      if ((draft.shipNumber ?? '').trim().isNotEmpty)
        'Ship ${draft.shipNumber!.trim()}',
      if ((draft.flightNumber ?? '').trim().isNotEmpty)
        'Flight ${draft.flightNumber!.trim()}',
      if ((draft.gate ?? '').trim().isNotEmpty) draft.gate!.trim(),
    ];

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: _accentFor(draft.type).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  _iconFor(draft.type),
                  color: _accentFor(draft.type),
                  size: 22.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      DateFormat('MMM d, y • h:mm a').format(draft.savedAt),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteDraft(draft);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete draft'),
                  ),
                ],
              ),
            ],
          ),
          if ((draft.subtitle ?? '').trim().isNotEmpty) ...[
            SizedBox(height: 12.h),
            Text(
              draft.subtitle!.trim(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF475569),
                height: 1.45,
              ),
            ),
          ],
          if (details.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: details
                  .map(
                    (detail) => Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 7.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                      child: Text(
                        detail,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openDraft(draft),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentFor(draft.type),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: Text(
                'Continue Draft',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _accentFor(String type) {
    switch (type) {
      case AuditDraftType.lavSafetyObservation:
        return const Color(0xFF0284C7);
      case AuditDraftType.cabinQualityAudit:
        return const Color(0xFF059669);
      case AuditDraftType.cabinSecuritySearchTraining:
        return const Color(0xFFD97706);
      case AuditDraftType.hiddenObjectAudit:
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF2563EB);
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case AuditDraftType.lavSafetyObservation:
        return Icons.clean_hands_outlined;
      case AuditDraftType.cabinQualityAudit:
        return Icons.fact_check_outlined;
      case AuditDraftType.cabinSecuritySearchTraining:
        return Icons.security_outlined;
      case AuditDraftType.hiddenObjectAudit:
        return Icons.visibility_outlined;
      default:
        return Icons.description_outlined;
    }
  }
}
