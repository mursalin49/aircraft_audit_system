// import 'package:avislap/utils/app_colors.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
//
// class SearchField extends StatelessWidget {
//   final TextEditingController controller;
//   final Function(String) onChanged;
//   final String hintText;
//
//   const SearchField({
//     super.key,
//     required this.controller,
//     required this.onChanged,
//     required this.hintText,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8.r),
//         border: Border.all(color: AppColors.border),
//       ),
//       child: TextField(
//         controller: controller,
//         onChanged: onChanged,
//         style: TextStyle(
//           color: AppColors.mainAppColor,
//           fontSize: 14.sp,
//           fontFamily: 'SegeoUi_regular',
//         ),
//         decoration: InputDecoration(
//           hintText: hintText,
//           hintStyle: TextStyle(
//             color: const Color(0xFF878787),
//             fontSize: 14.sp,
//             fontFamily: 'SegeoUi_regular',
//           ),
//           prefixIcon: Icon(
//             Icons.search,
//             color: const Color(0xFF878787),
//             size: 28.sp,
//           ),
//           border: InputBorder.none,
//           contentPadding: EdgeInsets.symmetric(
//             horizontal: 10.w,
//             vertical: 12.h,
//           ),
//         ),
//       ),
//     );
//   }
// }