// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import '../../healper/route.dart';
// import 'login.dart';
// import '../../utils/app_images.dart';
//
// class FlightAnimation extends StatefulWidget {
//   @override
//   _FlightAnimationState createState() => _FlightAnimationState();
// }
//
// class _FlightAnimationState extends State<FlightAnimation> with TickerProviderStateMixin {
//   late AnimationController _mainController;
//   late AnimationController _planeFloatController;
//
//   @override
//   void initState() {
//     super.initState();
//     _mainController = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 3),
//     )..repeat();
//
//     _planeFloatController = AnimationController(
//       vsync: this,
//       duration: const Duration(seconds: 3),
//     )..repeat(reverse: true);
//
//     // Navigate to Dashboard after splash
//     Future.delayed(const Duration(seconds: 3), () {
//       if (mounted) {
//         // Get.off(() => CabinAuditScreen());
//         Get.off(() => LoginScreen());
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     _mainController.dispose();
//     _planeFloatController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: AnimatedBuilder(
//         animation: _mainController,
//         builder: (context, child) {
//           return Stack(
//             children: [
//
//               _buildCloud(
//                 image: AppImages.small_cloud,
//                 width: 180,
//                 speed: 0.5,
//                 fromLeft: true,
//                 top: 150,
//               ),
//
//               _buildMovingPlane(),
//
//               _buildCloud(
//                 image: AppImages.big_cloud,
//                 width: 350,
//                 speed: 1.2,
//                 fromLeft: true,
//                 bottom: 100,
//               ),
//
//               _buildCloud(
//                 image: AppImages.small_cloud,
//                 width: 120,
//                 speed: 0.7,
//                 fromLeft: true,
//                 top: 500,
//               ),
//             ],
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildCloud({
//     required String image,
//     required double width,
//     required double speed,
//     required bool fromLeft,
//     double? top,
//     double? bottom,
//   }) {
//     double screenWidth = MediaQuery.of(context).size.width;
//     double progress = (_mainController.value * speed) % 1.0;
//
//     double xPos;
//     if (fromLeft) {
//
//       xPos = (progress * (screenWidth + width)) - width;
//     } else {
//
//       xPos = screenWidth - (progress * (screenWidth + width));
//     }
//
//     return Positioned(
//       left: xPos,
//       top: top,
//       bottom: bottom,
//       child: Image.asset(image, width: width, opacity: const AlwaysStoppedAnimation(0.7)),
//     );
//   }
//
//   Widget _buildMovingPlane() {
//     double screenWidth = MediaQuery.of(context).size.width;
//     double screenHeight = MediaQuery.of(context).size.height;
//     double progress = _mainController.value;
//
//
//     double xPos = screenWidth - (progress * (screenWidth + 300));
//     double yPos = (screenHeight * 0.6) - (progress * (screenHeight * 0.4));
//
//     return Positioned(
//       left: xPos,
//       top: yPos,
//       child: AnimatedBuilder(
//         animation: _planeFloatController,
//         builder: (context, child) {
//           return Transform.translate(
//             offset: Offset(0, _planeFloatController.value * 15),
//             child: Image.asset(AppImages.plane, width: 220),
//           );
//         },
//       ),
//     );
//   }
// }