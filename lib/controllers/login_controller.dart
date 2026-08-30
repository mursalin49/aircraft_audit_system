import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AuthController extends GetxController {
  // Login States
  var isPasswordVisible = false.obs;
  var rememberMe = false.obs;

  // Trouble Signing In States
  var selectedIssue = "".obs;

  // OTP Verification States
  var otpControllers = List.generate(5, (index) => TextEditingController());
  var otpFocusNodes = List.generate(5, (index) => FocusNode());

  // Reset Password States
  var isNewPasswordVisible = false.obs;
  var isConfirmPasswordVisible = false.obs;

  void togglePassword() => isPasswordVisible.value = !isPasswordVisible.value;
  void toggleNewPassword() => isNewPasswordVisible.value = !isNewPasswordVisible.value;
  void toggleConfirmPassword() => isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;

  @override
  void onClose() {
    for (var c in otpControllers) c.dispose();
    for (var n in otpFocusNodes) n.dispose();
    super.onClose();
  }
}