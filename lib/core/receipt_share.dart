import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves a receipt PDF to the cache folder and hands it to WhatsApp / the system share sheet.
class ReceiptShare {
  static const _channel = MethodChannel('rk/whatsapp');

  static Future<File> save(Uint8List bytes, String receiptNo) async {
    final dir = await getTemporaryDirectory();
    final safe = receiptNo.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File('${dir.path}/Receipt_$safe.pdf');
    return file.writeAsBytes(bytes, flush: true);
  }

  /// Opens the parent's WhatsApp chat with the PDF attached (the user taps send). If WhatsApp can't be
  /// targeted directly, falls back to the normal share sheet so the PDF can still be sent.
  static Future<void> sendToWhatsApp({
    required File file,
    required String whatsappNumber,
    required String message,
  }) async {
    var ok = false;
    try {
      ok = await _channel.invokeMethod<bool>('sendFile', {
            'path': file.path,
            'phone': whatsappNumber,
            'text': message,
            'mime': 'application/pdf',
          }) ??
          false;
    } on PlatformException {
      ok = false;
    } on MissingPluginException {
      ok = false;
    }
    if (!ok) await share(file: file, message: message);
  }

  static Future<void> share({required File file, required String message}) =>
      SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')], text: message));
}
