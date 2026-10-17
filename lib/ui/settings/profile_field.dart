import 'package:flutter/material.dart';

/// Saves while typing whenever the value is valid; a validation message only
/// appears once the field loses focus, so it never nags mid-word.
class ProfileField extends StatefulWidget {
  const ProfileField({
    required this.label,
    required this.initialValue,
    required this.onSave,
    this.validate,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.words,
    super.key,
  });

  final String label;
  final String? initialValue;
  final Future<void> Function(String? value) onSave;
  final String? Function(String value)? validate;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  @override
  State<ProfileField> createState() => _ProfileFieldState();
}

class _ProfileFieldState extends State<ProfileField> {
  late final _controller = TextEditingController(text: widget.initialValue);
  final _focus = FocusNode();
  String? _error;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        setState(() => _error = widget.validate?.call(_controller.text.trim()));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String text) async {
    final value = text.trim();
    final valid = widget.validate?.call(value) == null;
    if (_error != null && valid) setState(() => _error = null);
    if (valid) await widget.onSave(value.isEmpty ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
        onChanged: _onChanged,
      ),
    );
  }
}
