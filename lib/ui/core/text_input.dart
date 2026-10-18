import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A suffix that empties the field; null while it is empty so it takes no
/// space. [onChanged] runs with the empty text, as typing would.
Widget? clearButton(
  TextEditingController controller, {
  required ValueChanged<String> onChanged,
}) {
  if (controller.text.isEmpty) return null;
  return IconButton(
    tooltip: 'Clear',
    icon: const Icon(Icons.cancel_outlined),
    onPressed: () {
      controller.clear();
      onChanged('');
    },
  );
}

/// Selects the whole value whenever the field gains focus, so typing
/// replaces it; a second tap places the cursor.
class SelectAllFocusNode extends FocusNode {
  SelectAllFocusNode(TextEditingController controller) {
    addListener(() {
      if (!hasFocus) return;
      // After the tap that focused the field has placed its cursor.
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        ),
      );
    });
  }
}

/// Text fields on phones keep focus when tapping elsewhere; here a tap
/// outside every field closes the keyboard, while moving between fields
/// keeps it open.
final Map<Type, Action<Intent>> unfocusOnTapOutside = {
  EditableTextTapOutsideIntent: CallbackAction<EditableTextTapOutsideIntent>(
    onInvoke: (intent) => intent.focusNode.unfocus(),
  ),
};
