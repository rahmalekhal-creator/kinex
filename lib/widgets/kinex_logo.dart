import 'package:flutter/material.dart';

class KinexLogo extends StatelessWidget {
  const KinexLogo({
    super.key,
    this.size = 28,
    this.radius,
    this.backgroundColor,
    this.padding = 0,
  });

  final double size;
  final double? radius;
  final Color? backgroundColor;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius ?? size * 0.22);

    final image = ClipRRect(
      borderRadius: borderRadius,
      child: Image.asset(
        'assets/Kinex.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.image_not_supported_outlined,
          size: size * 0.72,
          color: const Color(0xFFA8B3CF),
        ),
      ),
    );

    if (backgroundColor == null && padding <= 0) {
      return image;
    }

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
      ),
      child: image,
    );
  }
}

