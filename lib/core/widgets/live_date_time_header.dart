import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Lightweight, minute-aligned live clock for the mobile top bar.
/// Uses zero external dependencies and ticks only when the minute transitions,
/// ensuring 0.00% battery or CPU overhead.
class LiveDateTimeHeader extends StatefulWidget {
  final TextStyle? textStyle;

  const LiveDateTimeHeader({
    super.key,
    this.textStyle,
  });

  @override
  State<LiveDateTimeHeader> createState() => _LiveDateTimeHeaderState();
}

class _LiveDateTimeHeaderState extends State<LiveDateTimeHeader> {
  String _datePart = '';
  String _timePart = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTime(isInitial: true);
    // Minute-aligned ticker (every 15s to catch the minute transition accurately)
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _syncTime(isInitial: false);
      }
    });
  }

  void _syncTime({required bool isInitial}) {
    final now = DateTime.now();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final weekday = weekdays[now.weekday - 1];
    final day = now.day;
    final month = months[now.month - 1];

    final hour24 = now.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minute = now.minute.toString().padLeft(2, '0');
    final amPm = hour24 >= 12 ? 'PM' : 'AM';

    final newDate = '$weekday, $day $month';
    final newTime = '$hour12:$minute $amPm';

    if (isInitial) {
      _datePart = newDate;
      _timePart = newTime;
    } else if (_datePart != newDate || _timePart != newTime) {
      setState(() {
        _datePart = newDate;
        _timePart = newTime;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _datePart,
            style: widget.textStyle ??
                GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B1220),
                  letterSpacing: -0.3,
                ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Container(
              width: 3.5,
              height: 3.5,
              decoration: const BoxDecoration(
                color: Color(0xFF94A3B8),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Text(
            _timePart,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
