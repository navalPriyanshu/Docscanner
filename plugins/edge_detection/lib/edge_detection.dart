import 'dart:async';
import 'package:flutter/services.dart';

class EdgeDetection {
  static const MethodChannel _channel = MethodChannel('edge_detection');

  static Future<bool> detectEdge(String filePath) async {
    final bool? success = await _channel.invokeMethod('detectEdge', {
      'file_path': filePath,
    });
    return success ?? false;
  }
}