import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

final keepScreenOnProvider =
    Provider<Future<void> Function({required bool on})>(
      (ref) =>
          ({required on}) => WakelockPlus.toggle(enable: on),
    );
