import 'package:flutter/material.dart';

class BlobBackground extends StatelessWidget {
  final Widget child;
  final bool dark;

  const BlobBackground({super.key, required this.child, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(color: dark ? Colors.black : Colors.white, child: child);
  }
}
