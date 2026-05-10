import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<BitmapDescriptor> bitmapFromURL(String url, {int targetWidth = 64}) async {
  final response = await http.get(Uri.parse(url));

  final bytes = response.bodyBytes;

  final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
  final frame = await codec.getNextFrame();

  final data =
  await frame.image.toByteData(format: ui.ImageByteFormat.png);

  return BitmapDescriptor.bytes(data!.buffer.asUint8List());
}
