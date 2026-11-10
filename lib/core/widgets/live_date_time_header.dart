import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Lightweight, minute-aligned live clock for the mobile top bar.
/// Computes date & time directly so it is never empty on hot-reload or launch.
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
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Re-check time every 15s to update the minute smoothly
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    final datePart = '$weekday, $day $month';
    final timePart = '$hour12:$minute $amPm';

    final dateStyle = widget.textStyle ??
        GoogleFonts.plusJakartaSans(
          fontSize: 14.0,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0B1220),
          letterSpacing: -0.2,
        );

    final timeStyle = GoogleFonts.jetBrainsMono(
      fontSize: 13.0,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF334155),
      letterSpacing: -0.2,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            datePart,
            style: dateStyle,
          ),
          const SizedBox(width: 6),
          Container(
            width: 3.5,
            height: 3.5,
            decoration: const BoxDecoration(
              color: Color(0xFF94A3B8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            timePart,
            style: timeStyle,
          ),
        ],
      ),
    );
  }
}
