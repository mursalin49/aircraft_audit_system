import 'package:flutter/material.dart';
import 'dart:math' as math;

class SeatSelectionScreen extends StatefulWidget {
  const SeatSelectionScreen({Key? key}) : super(key: key);

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  Set<String> selectedSeats = {};
  final double planeWidth = 280.0;

  Set<String> occupiedSeats = {
    '1A', '1B', '2C', '2D', '3A', '4B',
    '15A', '16C', '16D',
    '21A', '22B', '23C',
    '41D', '42E', '43F',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const Icon(Icons.arrow_back, color: Colors.black),
        title: const Text('Select Seat', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              _buildCompleteAirplane(),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteAirplane() {
    return SizedBox(
      width: planeWidth,
      child: Column(
        children: [

          _buildPlaneNose(),

          // ২. বডি সেকশন (নোজের সাথে মিলাতে নেগেটিভ মার্জিন ব্যবহার করা হয়েছে)
          Transform.translate(
            offset: const Offset(0, 0), // ইমেজের জয়েন্টে সাদা দাগ এড়াতে
            child: _buildPlaneBody(),
          ),

          // ৩. টেইল সেকশন
          _buildPlaneTail(),
        ],
      ),
    );
  }

  // NOSE SECTION
  Widget _buildPlaneNose() {
    double noseWidthFactor = 1.08; // ইমেজ সেন্টারে রেখে দুই পাশের গ্যাপ পূরণ করতে ওভার-স্কেল করে ClipRect দিয়ে কাটা হলো
    return SizedBox(
      width: planeWidth,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: 0.95,
              child: Image.asset(
                'assets/images/nose.png',
                width: planeWidth * noseWidthFactor,
                fit: BoxFit.fitWidth,
                color: const Color(0xFFE8E8E8),
              ),
            ),
          ),
          // ককপিট উইন্ডো
          Positioned(
            top: 120,
            child: _buildCockpitWindows(),
          ),
          // ফ্রন্ট গ্যালিকে ককপিটের আরও কাছে (ওপরে) নিতে bottom এর ভ্যালু বাড়ানো হলো
          Positioned(
            bottom: 5, // গ্যালি আরও ওপরে (সামনে) নিতে এই ভ্যালু বাড়াতে পারেন (যেমন: 70, 80)
            left: 0, right: 0,
            child: _buildFrontGalleyContent(),
          ),
        ],
      ),
    );
  }

  // BODY SECTION
  Widget _buildPlaneBody() {
    return Container(
      width: planeWidth,
      decoration: const BoxDecoration(
        color: Color(0xFFE8E8E8),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(2), 
          topRight: Radius.circular(2),
          bottomLeft: Radius.circular(2), 
          bottomRight: Radius.circular(2),
        ),
      ),
      child: Column(
        children: [
          _buildDeltaComfortContent(),
          _buildDeltaMainContent(),
          _buildRearCabinContent(),
        ],
      ),
    );
  }

  // TAIL SECTION
  Widget _buildPlaneTail() {
    double tailWidthFactor = 1.06;
    return SizedBox(
      width: planeWidth,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          ClipRect(
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 0.90,
              child: Image.asset(
                'assets/images/tail.png',
                width: planeWidth * tailWidthFactor,
                fit: BoxFit.fitWidth,
                color: const Color(0xFFE8E8E8),
              ),
            ),
          ),
          Positioned(
            top: 30,
            left: 0, right: 0,
            child: _buildTailContent(),
          ),
        ],
      ),
    );
  }

  // --- সিট ম্যাপ লজিক (আপনার আগের কোড অনুযায়ী) ---

  Widget _buildCockpitWindows() {
    int windowCount = 6;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(windowCount, (i) {
        double indexOffset = i - (windowCount - 1) / 2;
        double angle = indexOffset * 0.25;
        double yOffset = math.pow(indexOffset.abs(), 2) * 4;
        return Transform.translate(
          offset: Offset(0, yOffset),
          child: Transform.rotate(
            angle: angle,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 24, height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF5D6E7E),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildExitRow() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 30),
          child: Text('< Exit', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: EdgeInsets.only(right: 30),
          child: Text('Exit >', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
  
  Widget _buildSeatHeaders(List<String> left, List<String> right) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 102, child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: left.map((s) => Text(s, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))).toList())),
        const SizedBox(width: 30),
        SizedBox(width: 102, child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: right.map((s) => Text(s, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))).toList())),
      ],
    );
  }
  
  Widget _buildFapBlock({String text = 'FAP'}) {
    return Container(
      width: 35, height: 35,
      decoration: BoxDecoration(color: const Color(0xFF5D6E7E), borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildFrontGalleyContent() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [ _buildServiceIcon(Icons.wc), _buildFapBlock() ],
        ),
        const SizedBox(height: 10),
        _buildExitRow(),
        const SizedBox(height: 10),
        _buildSeatHeaders(['A', 'B'], ['C', 'D']),
        const SizedBox(height: 5),
        for (int row = 1; row <= 6; row++)
          _buildSeatRow(rowNumber: row, leftSeats: ['A', 'B'], rightSeats: ['C', 'D'], showRowNumber: true),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [ 
            const Text('Closet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)), 
            _buildFapBlock() 
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [ _buildServiceIcon(Icons.wc), _buildServiceIcon(Icons.wc) ],
        ),
      ],
    );
  }

  Widget _buildDeltaComfortContent() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Delta Comfort', style: TextStyle(color: Color(0xFF5A7FA5), fontWeight: FontWeight.bold)),
        ),
        _buildExitRow(),
        const SizedBox(height: 10),
        _buildSeatRow(rowNumber: 14, leftSeats: ['', '', ''], rightSeats: ['', 'E', 'F'], showRowNumber: true),
        for (int row = 15; row <= 20; row++)
          _buildSeatRow(rowNumber: row, leftSeats: ['A', 'B', 'C'], rightSeats: ['D', 'E', 'F'], showRowNumber: true),
      ],
    );
  }

  Widget _buildDeltaMainContent() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Delta Main', style: TextStyle(color: Color(0xFF5A7FA5), fontWeight: FontWeight.bold)),
        ),
        for (int row = 21; row <= 27; row++)
          _buildSeatRow(rowNumber: row, leftSeats: ['A', 'B', 'C'], rightSeats: ['D', 'E', 'F'], showRowNumber: true),
        _buildSeatRow(rowNumber: 28, leftSeats: ['', 'B', 'C'], rightSeats: ['D', 'E', ''], showRowNumber: true),
        for (int row = 29; row <= 40; row++)
          _buildSeatRow(rowNumber: row, leftSeats: ['A', 'B', 'C'], rightSeats: ['D', 'E', 'F'], showRowNumber: true),
      ],
    );
  }

  Widget _buildRearCabinContent() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [ _buildServiceIcon(Icons.wc), _buildServiceIcon(Icons.wc) ],
        ),
        const SizedBox(height: 10),
        _buildExitRow(),
        const SizedBox(height: 10),
        _buildSeatHeaders(['A', 'B', 'C'], ['D', 'E', 'F']),
        const SizedBox(height: 5),
        for (int row = 41; row <= 49; row++)
          _buildSeatRow(rowNumber: row, leftSeats: ['A', 'B', 'C'], rightSeats: ['D', 'E', 'F'], showRowNumber: true),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildTailContent() {
    return Column(
      children: [
        _buildExitRow(),
        const SizedBox(height: 20),
        Container(
          width: 80, height: 40,
          decoration: BoxDecoration(color: const Color(0xFF5D6E7E), borderRadius: BorderRadius.circular(8)),
          child: const Center(child: Text('GALLEY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
        ),
      ],
    );
  }

  Widget _buildSeatRow({required int rowNumber, required List<String> leftSeats, required List<String> rightSeats, bool showRowNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: leftSeats.map((s) => s.isEmpty ? const SizedBox(width: 34) : _buildSeat('$rowNumber$s')).toList()),
          SizedBox(width: 30, child: Center(child: Text(showRowNumber ? "$rowNumber" : "", style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold)))),
          Row(children: rightSeats.map((s) => s.isEmpty ? const SizedBox(width: 34) : _buildSeat('$rowNumber$s')).toList()),
        ],
      ),
    );
  }

  Widget _buildSeat(String seatId) {
    bool isOccupied = occupiedSeats.contains(seatId);
    bool isSelected = selectedSeats.contains(seatId);
    Color seatColor = isOccupied ? const Color(0xFF5D6E7E) : (isSelected ? const Color(0xFF4A7FBE) : const Color(0xFF7A8A9A));

    return GestureDetector(
      onTap: () {
        if (!isOccupied) {
          setState(() {
            isSelected ? selectedSeats.remove(seatId) : selectedSeats.add(seatId);
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 30, height: 30,
        child: CustomPaint(painter: RealisticSeatPainter(color: seatColor)),
      ),
    );
  }

  Widget _buildServiceIcon(IconData icon) {
    return Container(
      width: 35, height: 35,
      decoration: BoxDecoration(color: const Color(0xFF5D6E7E), borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

// আপনার অরিজিনাল RealisticSeatPainter ক্লাসটি এখানে ব্যবহার করুন...
class RealisticSeatPainter extends CustomPainter {
  final Color color;
  RealisticSeatPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.15, 0, size.width * 0.7, size.height * 0.35), const Radius.circular(3)), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.15, size.height * 0.4, size.width * 0.7, size.height * 0.45), const Radius.circular(3)), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
