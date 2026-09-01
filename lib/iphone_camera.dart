                                                import 'dart:io';
import 'package:flutter/material.dart';

class IphoneCamera extends StatelessWidget {
  final File image;

  const IphoneCamera({
    super.key,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        1.1, 0, 0, 0, 10,
        0, 1.05, 0, 0, 5,
        0, 0, 0.95, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: Image.file(
        image,
        fit: BoxFit.cover,
      ),
    );
  }
}