import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class _C {
  static const Color primary  = Color(0xFF3D5AFE);
  static const Color dark     = Color(0xFF1A1A2E);
  static const Color grey     = Color(0xFF8891A4);
  static const Color border   = Color(0xFFE4E7EF);
  static const Color inputBg  = Color(0xFFF9FAFB);
}

class NewSearchController extends GetxController {
  final nameCtrl     = TextEditingController();
  final fromDateCtrl = TextEditingController();
  final toDateCtrl   = TextEditingController();
  final selectedFilters = <String>{}.obs; // values: 'pass' | 'fail'

  void apply() => Get.back(result: {
    'name': nameCtrl.text,
    'fromDate': fromDateCtrl.text,
    'toDate': toDateCtrl.text,
    'filter': selectedFilters.toSet(),
  });

  void cancel() {
    nameCtrl.clear(); fromDateCtrl.clear(); toDateCtrl.clear();
    selectedFilters.clear();
    Get.back();
  }

  @override
  void onClose() {
    nameCtrl.dispose(); fromDateCtrl.dispose(); toDateCtrl.dispose();
    super.onClose();
  }
}

// ── How to open from Icons.more_vert ──────────────────────
// IconButton(
//   icon: Icon(Icons.more_vert, color: primary, size: 24.sp),
//   onPressed: () => Get.bottomSheet(
//     const NewSearchSheet(),
//     isScrollControlled: true,
//     backgroundColor: Colors.transparent,
//   ),
// )

class NewSearchSheet extends StatelessWidget {
  const NewSearchSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(NewSearchController());

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Card ──────────────────────────────────────
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16.w),
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 24, offset: const Offset(0,4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Row(children: [
                    Icon(Icons.search_rounded, color: _C.primary, size: 22.sp),
                    SizedBox(width: 8.w),
                    Text('New Search', style: GoogleFonts.dmSans(fontSize: 18.sp, fontWeight: FontWeight.w700, color: _C.primary)),
                  ]),
                  SizedBox(height: 20.h),

                  // Search by Name
                  _sectionLabel('Search by Name'),
                  SizedBox(height: 8.h),
                  _pillField(ctrl.nameCtrl, 'Enter Name', prefixIcon: Icons.search_rounded),
                  SizedBox(height: 20.h),

                  // Search by Date
                  _sectionLabel('Search by Date'),
                  SizedBox(height: 10.h),
                  _subLabel('From'),
                  SizedBox(height: 6.h),
                  _dateField(ctrl.fromDateCtrl, 'mm/dd/yyyy'),
                  SizedBox(height: 12.h),
                  _subLabel('To'),
                  SizedBox(height: 6.h),
                  _dateField(ctrl.toDateCtrl, 'Search'),
                  SizedBox(height: 20.h),

                  // Pass or Fail
                  _sectionLabel('Pass or Fail'),
                  SizedBox(height: 10.h),
                  Obx(() => Row(children: [
                    Expanded(child: _chip('Pass', Icons.check_rounded, ctrl.selectedFilters.contains('pass'),
                            () => ctrl.selectedFilters.contains('pass')
                                ? ctrl.selectedFilters.remove('pass')
                                : ctrl.selectedFilters.add('pass'))),
                    SizedBox(width: 12.w),
                    Expanded(child: _chip('Fail', Icons.close_rounded, ctrl.selectedFilters.contains('fail'),
                            () => ctrl.selectedFilters.contains('fail')
                                ? ctrl.selectedFilters.remove('fail')
                                : ctrl.selectedFilters.add('fail'))),
                  ])),
                ],
              ),
            ),
            SizedBox(height: 14.h),

            // ── Buttons ──────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(children: [
                Expanded(child: _outlineBtn('Cancel', ctrl.cancel)),
                SizedBox(width: 12.w),
                Expanded(child: _filledBtn('Apply', ctrl.apply)),
              ]),
            ),
            SizedBox(height: 28.h),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(t,
      style: GoogleFonts.dmSans(fontSize: 13.sp, fontWeight: FontWeight.w600, color: _C.primary));

  Widget _subLabel(String t) => Text(t,
      style: GoogleFonts.dmSans(fontSize: 12.sp, color: _C.grey));

  Widget _pillField(TextEditingController ctrl, String hint, {IconData? prefixIcon}) => TextField(
    controller: ctrl,
    style: GoogleFonts.dmSans(fontSize: 14.sp, color: _C.dark),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(fontSize: 14.sp, color: _C.grey),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18.sp, color: _C.grey) : null,
      filled: true, fillColor: _C.inputBg,
      contentPadding: EdgeInsets.symmetric(vertical: 13.h, horizontal: 16.w),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.r), borderSide: BorderSide(color: _C.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30.r), borderSide: BorderSide(color: _C.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30.r), borderSide: BorderSide(color: _C.primary, width: 1.5)),
    ),
  );

  Widget _dateField(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl, readOnly: true,
    onTap: () async {
      final p = await showDatePicker(
        context: Get.context!,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020), lastDate: DateTime(2030),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: _C.primary)),
          child: child!,
        ),
      );
      if (p != null) ctrl.text = '${p.month.toString().padLeft(2,'0')}/${p.day.toString().padLeft(2,'0')}/${p.year}';
    },
    style: GoogleFonts.dmSans(fontSize: 14.sp, color: _C.dark),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(fontSize: 14.sp, color: _C.grey),
      prefixIcon: Icon(Icons.calendar_month_outlined, size: 18.sp, color: _C.grey),
      filled: true, fillColor: _C.inputBg,
      contentPadding: EdgeInsets.symmetric(vertical: 13.h),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.r), borderSide: BorderSide(color: _C.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30.r), borderSide: BorderSide(color: _C.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30.r), borderSide: BorderSide(color: _C.primary, width: 1.5)),
    ),
  );

  Widget _chip(String label, IconData icon, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: selected ? _C.primary.withOpacity(0.08) : _C.inputBg,
          borderRadius: BorderRadius.circular(30.r),
          border: Border.all(color: selected ? _C.primary.withOpacity(0.5) : _C.border, width: selected ? 1.5 : 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16.sp, color: selected ? _C.primary : _C.grey),
          SizedBox(width: 6.w),
          Text(label, style: GoogleFonts.dmSans(
              fontSize: 14.sp, fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? _C.primary : _C.grey)),
        ]),
      ),
    );
  }

  Widget _outlineBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(color: _C.border, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(label, style: GoogleFonts.dmSans(fontSize: 15.sp, fontWeight: FontWeight.w600, color: _C.dark)),
    ),
  );

  Widget _filledBtn(String label, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52.h,
      decoration: BoxDecoration(color: _C.primary, borderRadius: BorderRadius.circular(30.r)),
      alignment: Alignment.center,
      child: Text(label, style: GoogleFonts.dmSans(fontSize: 15.sp, fontWeight: FontWeight.w700, color: Colors.white)),
    ),
  );
}
