import 'package:flutter/material.dart';

/// An abstract trail illustration, not a user's recorded GPS route.
class TrailArtwork extends StatelessWidget {
  const TrailArtwork({super.key});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      painter: _TrailPainter(Theme.of(context).brightness == Brightness.dark),
      child: const SizedBox.expand(),
    ),
  );
}

class _TrailPainter extends CustomPainter {
  const _TrailPainter(this.dark);
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color(dark ? 0xFF344D41 : 0xFFDFE9D8),
    );
    canvas.drawCircle(
      Offset(w * .79, h * .20),
      30,
      Paint()..color = const Color(0xFFF2E7BD),
    );
    for (var i = 0; i < 4; i++) {
      final y = h * (.32 + i * .18);
      final path = Path()
        ..moveTo(0, y + 45)
        ..cubicTo(w * .22, y - 80, w * .39, y + 80, w * .64, y)
        ..quadraticBezierTo(w * .85, y - 70, w, y - 8)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = (dark
              ? [
                  const Color(0xFF496555),
                  const Color(0xFF3C5949),
                  const Color(0xFF2A493A),
                  const Color(0xFF203D30),
                ]
              : [
                  const Color(0xFFB9CEAE),
                  const Color(0xFF97B797),
                  const Color(0xFF759D80),
                  const Color(0xFF537E65),
                ])[i],
      );
    }
    final trail = Path()
      ..moveTo(w * .68, h * .94)
      ..cubicTo(w * .36, h * .72, w * .97, h * .64, w * .71, h * .47)
      ..quadraticBezierTo(w * .59, h * .38, w * .69, h * .31);
    canvas.drawPath(
      trail,
      Paint()
        ..color = const Color(0xFFE7E8CC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(w * .69, h * .31),
      7,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(w * .69, h * .31),
      3,
      Paint()..color = const Color(0xFF315B43),
    );
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) => oldDelegate.dark != dark;
}
