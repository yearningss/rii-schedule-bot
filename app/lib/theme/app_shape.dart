import 'package:flutter/material.dart';

/// Дизайн-токены скруглений и форм Material 3.
class AppShape {
  AppShape._();

  // Числовые радиусы скругления
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 28.0;
  static const double radiusFull = 999.0;

  // Объекты Radius
  static const Radius circularXs = Radius.circular(radiusXs);
  static const Radius circularSm = Radius.circular(radiusSm);
  static const Radius circularMd = Radius.circular(radiusMd);
  static const Radius circularLg = Radius.circular(radiusLg);
  static const Radius circularXl = Radius.circular(radiusXl);
  static const Radius circularFull = Radius.circular(radiusFull);

  // Объекты BorderRadius
  static const BorderRadius roundedXs = BorderRadius.all(circularXs);
  static const BorderRadius roundedSm = BorderRadius.all(circularSm);
  static const BorderRadius roundedMd = BorderRadius.all(circularMd);
  static const BorderRadius roundedLg = BorderRadius.all(circularLg);
  static const BorderRadius roundedXl = BorderRadius.all(circularXl);
  static const BorderRadius roundedFull = BorderRadius.all(circularFull);

  // Специальные BorderRadius (например, для BottomSheet)
  static const BorderRadius sheetTop = BorderRadius.vertical(top: circularXl);

  // Стандартные формы ShapeBorder для компонентов Material 3
  static const RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: roundedLg,
  );

  static const RoundedRectangleBorder dialogShape = RoundedRectangleBorder(
    borderRadius: roundedXl,
  );

  static const RoundedRectangleBorder bottomSheetShape = RoundedRectangleBorder(
    borderRadius: sheetTop,
  );

  static const RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: roundedFull,
  );

  static const RoundedRectangleBorder chipShape = RoundedRectangleBorder(
    borderRadius: roundedSm,
  );
}
