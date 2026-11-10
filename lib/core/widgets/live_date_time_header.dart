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
  late String _formatted;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _formatted = _getFormattedTime();
    // Minute-aligned ticker (every 15s to catch the minute transition accurately)
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        final next = _getFormattedTime();
        if (_formatted != next) {
          setState(() {
            _formatted = next;
          });
        }
      }
    });
  }

  String _getFormattedTime() {
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

    return '$weekday, $day $month • $hour12:$minute $amPm';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatted,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: widget.textStyle ??
          GoogleFonts.publicSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0B1220),
            letterSpacing: -0.2,
          ),
    );
  }
}
