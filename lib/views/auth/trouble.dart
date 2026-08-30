// import 'package:avislap/controllers/login_controller.dart';
// import 'package:avislap/utils/app_colors.dart';
// import 'package:avislap/utils/app_images.dart';
// import 'package:avislap/utils/app_text.dart';
// import 'package:avislap/views/auth/forget.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
//
// class trouble extends StatelessWidget {
//   final controller = Get.find<AuthController>();
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Padding(
//         padding: const EdgeInsets.all(30),
//         child: Column(
//           children: [
//             const SizedBox(height: 60),
//             Image.asset(AppImages.logo, height: 100), // লোগো
//             const SizedBox(height: 30),
//             AppText("Having Trouble Signing in?", fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.mainAppColor, textAlign: TextAlign.center),
//             const SizedBox(height: 10),
//             AppText("Please select your issue", color: Colors.grey),
//
//             const SizedBox(height: 30),
//             _buildRadioOption("I don't know my used ID ?", "id_issue"),
//             _buildRadioOption("I don't know my Password ?", "pass_issue"),
//             _buildRadioOption("Doesn't have access to my Registered E-mail ID", "email_issue"),
//
//             const SizedBox(height: 30),
//             TextButton(
//               onPressed: () => Get.back(),
//               child: AppText("Back to Sign In", color: AppColors.mainAppColor, fontWeight: FontWeight.bold),
//             ),
//             const Spacer(),
//             _buildPrimaryButton("CONTINUE", () {
//               Get.to(() => ForgotPasswordScreen() );
//             }),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildRadioOption(String title, String value) {
//     return Obx(() => RadioListTile(
//       title: AppText(title, fontSize: 14, color: Colors.grey.shade700),
//       value: value,
//       groupValue: controller.selectedIssue.value,
//       onChanged: (v) => controller.selectedIssue.value = v.toString(),
//       activeColor: AppColors.mainAppColor,
//       contentPadding: EdgeInsets.zero,
//     ));
//   }
// }
//
// // 🔹 Common Primary Button
// Widget _buildPrimaryButton(String label, VoidCallback onTap) {
//   return ElevatedButton(
//     onPressed: onTap,
//     style: ElevatedButton.styleFrom(
//       backgroundColor: AppColors.mainAppColor,
//       minimumSize: const Size(double.infinity, 55),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//     ),
//     child: AppText(label, color: Colors.white, fontWeight: FontWeight.bold),
//   );
// }