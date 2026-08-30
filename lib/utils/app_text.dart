import 'package:flutter/material.dart';

class AppText extends StatelessWidget {
  final String text;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final TextDecoration? decoration;
  final Color? decorationColor;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AppText(
      this.text, {
        super.key,
        this.color,
        this.fontSize,
        this.fontWeight,
        this.decoration,
        this.decorationColor,
        this.textAlign,
        this.maxLines,
        this.overflow,
      });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      style: TextStyle(
        letterSpacing: 0.2,
        fontSize: fontSize ?? 20,
        fontFamily: 'Roboto',
        fontWeight: fontWeight ?? FontWeight.w500,
        color: color ?? Colors.black,
        decoration: decoration,
        decorationColor: decorationColor,
      ),
    );
  }
}
