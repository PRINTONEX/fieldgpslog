import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<BitmapDescriptor> getBitmapDescriptorFromIconData(
  IconData iconData, {
  double size = 120,
  Color color = Colors.blue,
}) async {
  final pictureRecorder = ui.PictureRecorder();
  final canvas = ui.Canvas(pictureRecorder);
  final textPainter = TextPainter(textDirection: TextDirection.ltr);
  final iconStr = String.fromCharCode(iconData.codePoint);

  textPainter.text = TextSpan(
    text: iconStr,
    style: TextStyle(
      letterSpacing: 0.0,

      color: color,
      fontSize: size,
      fontFamily: iconData.fontFamily,
      package: iconData.fontPackage,
    ),
  );

  textPainter.layout();
  textPainter.paint(canvas, ui.Offset.zero);

  final picture = pictureRecorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

  if (bytes == null) return BitmapDescriptor.defaultMarker;
  return BitmapDescriptor.bytes(bytes.buffer.asUint8List());
}

Future<BitmapDescriptor> bitmapFromURL(String url, {int targetWidth = 64}) async {
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      },
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception("Failed to load image: HTTP ${response.statusCode}");
    }

    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw Exception("Failed to load image: Empty response body");
    }

    final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
    final frame = await codec.getNextFrame();

    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);

    if (data == null) {
      throw Exception("Failed to convert image to byte data");
    }

    return BitmapDescriptor.bytes(data.buffer.asUint8List());
  } catch (e) {
    debugPrint("Error loading URL marker ($url): $e");
    return BitmapDescriptor.defaultMarker;
  }
}

Future<BitmapDescriptor> bitmapFromAsset(String assetPath, {int targetWidth = 64}) async {
  try {
    final ByteData data = await rootBundle.load(assetPath);
    final Uint8List bytes = data.buffer.asUint8List();
    
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
    final frame = await codec.getNextFrame();

    final pngData = await frame.image.toByteData(format: ui.ImageByteFormat.png);

    if (pngData == null) {
      throw Exception("Failed to convert asset image to byte data");
    }

    return BitmapDescriptor.bytes(pngData.buffer.asUint8List());
  } catch (e) {
    debugPrint("Error loading asset marker ($assetPath): $e");
    return BitmapDescriptor.defaultMarker;
  }
}
