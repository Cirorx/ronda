import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Whether the browser sees any microphone. Listing devices needs no
/// permission: before it is given, the browser still lists one of each kind
/// it has, without a name.
Future<bool> hasMicrophone() async {
  try {
    final devices = await web.window.navigator.mediaDevices
        .enumerateDevices()
        .toDart;
    return devices.toDart.any((device) => device.kind == 'audioinput');
  } on Object {
    // No mediaDevices at all (an insecure page): no microphone to use.
    return false;
  }
}
