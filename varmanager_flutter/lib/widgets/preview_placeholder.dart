import 'package:flutter/material.dart';

class PreviewPlaceholder extends StatelessWidget {
  const PreviewPlaceholder({
    super.key,
    this.width,
    this.height,
    this.icon = Icons.image_not_supported,
  });

  final double? width;
  final double? height;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFEEEEEE),
      alignment: Alignment.center,
      child: Icon(icon),
    );
  }
}
