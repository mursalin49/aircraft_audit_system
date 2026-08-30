import 'package:avislap/utils/app_colors.dart';
import 'package:avislap/utils/app_images.dart';
import 'package:avislap/utils/app_text.dart';
import 'package:flutter/material.dart';

// 🔹 Logo Widget
Widget buildCircularLogo() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.mainAppColor, width: 2),
    ),
    child: Image.asset(AppImages.logo, height: 80),
  );
}

// 🔹 Input Label
Widget buildInputLabel(String text) => Align(
  alignment: Alignment.centerLeft,
  child: Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: AppText(
      text,
      fontWeight: FontWeight.bold,
      color: AppColors.mainAppColor,
      fontSize: 14,
    ),
  ),
);

// 🔹 Auth TextField (rounded, used in login/register)
Widget buildTextField({
  required String hint,
  bool obscureText = false,
  Widget? suffixIcon,
}) {
  return TextField(
    obscureText: obscureText,
    decoration: InputDecoration(
      hintText: hint,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    ),
  );
}

// 🔹 Form TextField (used in forms with optional suffix icon)
Widget buildFormTextField(String hint, {IconData? suffixIcon}) => TextField(
  decoration: InputDecoration(
    hintText: hint,
    suffixIcon: suffixIcon != null ? Icon(suffixIcon, size: 20) : null,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  ),
);

// ✅ Fixed: Added missing buildLargeTextField
Widget buildLargeTextField(String hint) => TextField(
  maxLines: 4,
  decoration: InputDecoration(
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    alignLabelWithHint: true,
  ),
);

// 🔹 Primary Button
Widget buildPrimaryButton(String label, VoidCallback onTap, {IconData? icon}) =>
    ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4A74EA),
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) Icon(icon, color: Colors.white, size: 18),
          if (icon != null) const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );

// 🔹 Header Widget
Widget buildHeader(String title, String subtitle) {
  return Column(
    children: [
      AppText(title, fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.mainAppColor),
      const SizedBox(height: 10),
      AppText(subtitle, textAlign: TextAlign.center, color: Colors.grey),
    ],
  );
}