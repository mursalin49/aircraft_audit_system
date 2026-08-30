import 'package:avislap/controllers/aviation_controller.dart';
import 'package:avislap/models/aviationstack_model.dart';
import 'package:avislap/services/app_api_service.dart';
import 'package:avislap/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/app_colors.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final AviationController _aviationController;

  @override
  void initState() {
    super.initState();
    _aviationController = Get.isRegistered<AviationController>()
        ? Get.find<AviationController>()
        : Get.put(AviationController());
    _aviationController.fetchFlights();
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionService>();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: RefreshIndicator(
        onRefresh: _aviationController.fetchFlights,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroSection(
                userName: session.fullName,
                designation: session.activeRoleName,
                profileImageFileId: session.profileImageFileId,
              ),
              const _DateSection(),
              SizedBox(height: 8.h),
              _OperationalContextCard(
                stationCode: session.activeStationCode,
                contract: session.activeContract,
                availableContracts: session.availableContracts,
              ),
              SizedBox(height: 16.h),
              _FlightsOverviewSection(
                controller: _aviationController,
                session: session,
              ),
              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final String userName;
  final String designation;
  final String profileImageFileId;

  const _HeroSection({
    required this.userName,
    required this.designation,
    required this.profileImageFileId,
  });

  @override
  Widget build(BuildContext context) {
    final AppApiService api = Get.find<AppApiService>();
    final String imageUrl = profileImageFileId.isEmpty
        ? ''
        : api.buildFileContentUrl(profileImageFileId);
    final Map<String, String> imageHeaders = api.buildImageHeaders();
    final String initials = userName.trim().isEmpty
        ? 'U'
        : userName
              .trim()
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();
    final ImageProvider<Object>? imageProvider = imageUrl.isEmpty
        ? null
        : NetworkImage(imageUrl, headers: imageHeaders);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 40.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0F172A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36.r),
          bottomRight: Radius.circular(36.r),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Align(
              alignment: Alignment.center,
              child: Image.asset(
                'assets/images/custom_logo.png',
                height: 48.h,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 28.h),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0x66FFFFFF), Color(0x1FFFFFFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white30, width: 1.5),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 36.r,
                    backgroundColor: Colors.white24,
                    backgroundImage: imageProvider,
                    child: imageProvider == null
                        ? Text(
                            initials,
                            style: GoogleFonts.dmSans(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Hello, $userName",
                  style: GoogleFonts.dmSans(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  "Welcome Back",
                  style: GoogleFonts.dmSans(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_user,
                        size: 14,
                        color: Colors.blueAccent,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        designation.isEmpty
                            ? "STAFF"
                            : designation.toUpperCase(),
                        style: GoogleFonts.dmSans(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSection extends StatelessWidget {
  const _DateSection();

  String _formatFullDate() {
    final d = DateTime.now();
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    const weekdays = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];
    return "${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today,
                color: Color(0xFF3B82F6),
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                _formatFullDate(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationalContextCard extends StatelessWidget {
  final String stationCode;
  final String contract;
  final List<String> availableContracts;

  const _OperationalContextCard({
    required this.stationCode,
    required this.contract,
    required this.availableContracts,
  });

  @override
  Widget build(BuildContext context) {
    final hasStation = stationCode.trim().isNotEmpty;
    final requiresContract = availableContracts.isNotEmpty;
    final hasContract = contract.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
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
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(
                    Icons.radar_rounded,
                    color: const Color(0xFF2563EB),
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Flight Board',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        hasStation
                            ? 'Showing flights for your active station session.'
                            : 'Select your station session to load live arrivals.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Wrap(
              spacing: 10.w,
              runSpacing: 10.h,
              children: [
                _ContextPill(
                  icon: Icons.flight_land_rounded,
                  label: 'Station',
                  value: hasStation ? stationCode : 'Not selected',
                  accent: const Color(0xFF2563EB),
                ),
                _ContextPill(
                  icon: Icons.business_center_outlined,
                  label: 'Airline',
                  value: hasContract
                      ? contract
                      : requiresContract
                      ? 'Not selected'
                      : 'All assigned airlines',
                  accent: const Color(0xFF0F766E),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  const _ContextPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: accent),
          SizedBox(width: 8.w),
          Text(
            '$label: $value',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlightsOverviewSection extends StatelessWidget {
  final AviationController controller;
  final SessionService session;

  const _FlightsOverviewSection({
    required this.controller,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = controller.activeAirport.status.value;
      final error = controller.activeAirport.error.value;
      final arrivals = controller.activeAirport.arrivals.toList(
        growable: false,
      );
      final visibleFlights = arrivals.take(6).toList(growable: false);

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inbound Flights',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        session.activeContract.isEmpty
                            ? 'Live arrivals for the current station.'
                            : 'Live arrivals for ${session.activeContract}.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                _RefreshBadge(controller: controller),
              ],
            ),
            SizedBox(height: 16.h),
            if (session.activeStationCode.isEmpty)
              const _FlightsEmptyState(
                icon: Icons.location_off_outlined,
                title: 'No active station selected',
                message:
                    'Choose your airport session first to see the live flight board here.',
              )
            else if (session.availableContracts.isNotEmpty &&
                session.activeContract.isEmpty)
              const _FlightsEmptyState(
                icon: Icons.airline_seat_individual_suite_outlined,
                title: 'Airline contract not selected',
                message:
                    'Pick the airline contract for this station to load the correct inbound flights.',
              )
            else if (status == 'loading' && arrivals.isEmpty)
              const _FlightsLoadingState()
            else if (status == 'error')
              _FlightsEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load flights',
                message: error ?? 'Please pull to refresh and try again.',
              )
            else if (visibleFlights.isEmpty)
              const _FlightsEmptyState(
                icon: Icons.flight_outlined,
                title: 'No inbound flights found',
                message:
                    'There are no matching arrivals for the current station and airline right now.',
              )
            else ...[
              _FlightsSnapshotRow(
                totalFlights: arrivals.length,
                visibleFlights: visibleFlights.length,
                lastUpdated: controller.activeAirport.lastUpdated.value,
                controller: controller,
              ),
              SizedBox(height: 12.h),
              ...visibleFlights.map(
                (flight) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: _HomeFlightCard(flight: flight),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _RefreshBadge extends StatelessWidget {
  final AviationController controller;

  const _RefreshBadge({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final secondsLeft = controller.secondsUntilCacheExpiry.value;
      final isLive = secondsLeft > 0;
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isLive ? const Color(0xFFDCFCE7) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(999.r),
        ),
        child: Text(
          isLive ? 'Refresh in ${secondsLeft}s' : 'Ready to refresh',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: isLive ? const Color(0xFF166534) : const Color(0xFF475569),
          ),
        ),
      );
    });
  }
}

class _FlightsSnapshotRow extends StatelessWidget {
  final int totalFlights;
  final int visibleFlights;
  final DateTime? lastUpdated;
  final AviationController controller;

  const _FlightsSnapshotRow({
    required this.totalFlights,
    required this.visibleFlights,
    required this.lastUpdated,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            totalFlights > visibleFlights
                ? 'Showing $visibleFlights of $totalFlights arrivals'
                : '$totalFlights arrivals loaded',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        Text(
          'Updated ${controller.timeAgo(lastUpdated)}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

class _HomeFlightCard extends StatelessWidget {
  final AviationFlight flight;

  const _HomeFlightCard({required this.flight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  flight.airlineName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
              ),
              _FlightStatusChip(status: flight.status),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _FlightHeadlineValue(
                label: 'Flight',
                value: flight.flightNumber,
                accent: const Color(0xFF0F172A),
              ),
              SizedBox(width: 18.w),
              _FlightHeadlineValue(
                label: 'From',
                value: flight.departureIata,
                accent: const Color(0xFF2563EB),
              ),
              const Spacer(),
              _FlightHeadlineValue(
                label: 'Arrival',
                value: flight.formattedArrivalTime,
                accent: const Color(0xFF0F766E),
                alignEnd: true,
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _FlightMetaPill(
                icon: Icons.meeting_room_outlined,
                label: 'Terminal ${flight.displayArrivalTerminal}',
              ),
              _FlightMetaPill(
                icon: Icons.place_outlined,
                label: 'Gate ${flight.displayArrivalGate}',
              ),
              _FlightMetaPill(
                icon: Icons.confirmation_number_outlined,
                label: 'Ship ${flight.shipNumber}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlightHeadlineValue extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final bool alignEnd;

  const _FlightHeadlineValue({
    required this.label,
    required this.value,
    required this.accent,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.6,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
      ],
    );
  }
}

class _FlightMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FlightMetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: const Color(0xFF64748B)),
          SizedBox(width: 6.w),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlightStatusChip extends StatelessWidget {
  final String status;

  const _FlightStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    late final Color color;

    switch (normalized) {
      case 'delayed':
        color = const Color(0xFFD97706);
        break;
      case 'cancelled':
        color = const Color(0xFFDC2626);
        break;
      case 'landed':
      case 'on-ground':
        color = const Color(0xFF166534);
        break;
      case 'approaching':
      case 'scheduled':
      case 'departed':
      default:
        color = const Color(0xFF2563EB);
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _FlightsLoadingState extends StatelessWidget {
  const _FlightsLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: Container(
            height: 118.h,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}

class _FlightsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _FlightsEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(22.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(icon, size: 30.sp, color: const Color(0xFF64748B)),
          ),
          SizedBox(height: 14.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
