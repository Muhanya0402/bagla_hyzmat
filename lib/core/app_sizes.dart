import 'package:flutter/material.dart';

class AppSizes {
  final double width;

  const AppSizes(this.width);

  double font(double percent) => width * (percent / 100);
  double spacing(double percent) => width * (percent / 100);
  double icon(double percent) => width * (percent / 100);

  static AppSizes of(BuildContext context) {
    return AppSizes(MediaQuery.sizeOf(context).width);
  }
}