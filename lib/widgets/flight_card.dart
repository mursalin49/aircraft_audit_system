import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/aviationstack_config.dart';
import '../models/aviationstack_model.dart';

class FlightCard extends StatefulWidget {
  final AviationFlight flight;
  final VoidCallback? onStartAudit;

  const FlightCard({super.key, required this.flight, this.onStartAudit});

  @override
  State<FlightCard> createState() => _FlightCardState();
}

class _FlightCardState extends State<FlightCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: EdgeInsets.only(bottom: 16.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 15.r,
                spreadRadius: 2.r,
                offset: const Offset(0, 4),
              ),
              if (_isHovered)
                BoxShadow(
                  color:
                      (widget.flight.isDeparture
                              ? AviationStackConfig.departureColor
                              : AviationStackConfig.arrivalColor)
                          .withValues(alpha: 0.15),
                  blurRadius: 20.r,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: Colors.white, // White theme
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: _isHovered
                        ? (widget.flight.isDeparture
                                  ? AviationStackConfig.departureColor
                                  : AviationStackConfig.arrivalColor)
                              .withValues(alpha: 0.4)
                        : const Color(0xFFE2E8F0), // Light gray border
                    width: 1.5,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      // Subtile left border accent
                      Container(
                        width: 4.w,
                        decoration: BoxDecoration(
                          color: widget.flight.isDeparture
                              ? AviationStackConfig.departureColor
                              : AviationStackConfig.arrivalColor,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            SizedBox(height: 16.h),
                            _buildBody(),
                            SizedBox(height: 16.h),
                            _buildFooter(),
                            if (widget.onStartAudit != null) ...[
                              SizedBox(height: 16.h),
                              _buildActionButton(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            widget.flight.airlineName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
        _buildFlightNumberBadge(),
        SizedBox(width: 8.w),
        _buildMovementBadge(),
        SizedBox(width: 8.w),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildFlightNumberBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9), // Light background for badge
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Text(
        widget.flight.flightNumber,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildMovementBadge() {
    final isDeparture = widget.flight.isDeparture;
    final color = isDeparture
        ? AviationStackConfig.departureColor
        : AviationStackConfig.arrivalColor;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100.r),
      ),
      child: Icon(
        isDeparture ? Icons.flight_takeoff_rounded : Icons.flight_land_rounded,
        size: 16,
        color: color,
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color statusColor;
    switch (widget.flight.status.toLowerCase()) {
      case 'active':
      case 'scheduled':
      case 'approaching':
      case 'landed':
      case 'on-ground':
      case 'departed':
        statusColor = AviationStackConfig.statusActive;
        break;
      case 'delayed':
        statusColor = AviationStackConfig.statusDelayed;
        break;
      case 'cancelled':
        statusColor = AviationStackConfig.statusCancelled;
        break;
      default:
        statusColor = AviationStackConfig.statusUnknown;
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: statusColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.5),
            blurRadius: 6,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Row(
      children: [
        Expanded(
          child: _buildInfoGroup(
            label: "DEPARTURE",
            value:
                "${widget.flight.departureIata} ${widget.flight.formattedDepartureTime}",
            color: AviationStackConfig.departureColor,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Icon(
            Icons.trending_flat,
            color: const Color(0xFF94A3B8), // Slate 400
            size: 24.sp,
          ),
        ),
        Expanded(
          child: _buildInfoGroup(
            label: "ARRIVAL",
            value:
                "${widget.flight.arrivalIata} ${widget.flight.formattedArrivalTime}",
            color: AviationStackConfig.arrivalColor,
            crossAxisAlignment: CrossAxisAlignment.end,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final terminal = widget.flight.isDeparture
        ? widget.flight.displayDepartureTerminal
        : widget.flight.displayArrivalTerminal;
    final gate = widget.flight.isDeparture
        ? widget.flight.displayDepartureGate
        : widget.flight.displayArrivalGate;

    return Row(
      children: [
        Expanded(
          child: _buildInfoGroup(
            label: "TERMINAL",
            value: terminal,
            color: AviationStackConfig.terminalColor,
          ),
        ),
        Expanded(
          child: _buildInfoGroup(
            label: "GATE",
            value: gate,
            color: AviationStackConfig.gateColor,
          ),
        ),
        Expanded(
          child: _buildInfoGroup(
            label: "SHIP NUMBER",
            value: widget.flight.shipNumber,
            color: const Color(0xFF475569), // Slate 600
            crossAxisAlignment: CrossAxisAlignment.end,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGroup({
    required String label,
    required String value,
    required Color color,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B), // Slate 500
            letterSpacing: 0.08 * 14, // letter-spacing: 0.08em
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.onStartAudit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AviationStackConfig.start.withValues(alpha: 0.1),
          foregroundColor: AviationStackConfig.start,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          padding: EdgeInsets.symmetric(vertical: 12.h),
        ),
        child: Text(
          "START AUDIT",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AviationStackConfig.start,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
