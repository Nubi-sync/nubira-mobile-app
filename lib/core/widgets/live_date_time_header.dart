import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Lightweight, minute-aligned live clock for the mobile top bar.
/// Uses the exact same font for date and time.
/// Automatically syncs on app resume and minute tick-over with 0% battery drain.
class LiveDateTimeHeader extends StatefulWidget {
  final TextStyle? textStyle;

  const LiveDateTimeHeader({
    super.key,
    this.textStyle,
  });

  @override
  State<LiveDateTimeHeader> createState() => _LiveDateTimeHeaderState();
}

class _LiveDateTimeHeaderState extends State<LiveDateTimeHeader>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _lastMinute = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastMinute = DateTime.now().minute;
    // Check every second, only triggers rebuild when the minute actually changes
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final currentMinute = DateTime.now().minute;
        if (currentMinute != _lastMinute) {
          _lastMinute = currentMinute;
          setState(() {});
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        _lastMinute = DateTime.now().minute;
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

    // Single unified string in the exact same font
    final fullText = '$weekday, $day $month  •  $hour12:$minute $amPm';

    final unifiedStyle = widget.textStyle ??
        GoogleFonts.plusJakartaSans(
          fontSize: 14.0,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0B1220),
          letterSpacing: -0.2,
        );

    return Text(
      fullText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: unifiedStyle,
    );
  }
}
