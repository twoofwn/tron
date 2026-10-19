import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.hint,
    this.validator,
    this.maxLength = 80,
    this.maxLines = 1,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String? hint;
  final String? Function(String?)? validator;
  final int maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    maxLength: maxLength,
    maxLines: maxLines,
    keyboardType: keyboardType,
    decoration: InputDecoration(hintText: hint, counterText: ''),
  );
}
