import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

Future<void> downloadJpg(Uint8List pngBytes, String filename) async {
  final jpgBytes = await _toJpgBytes(pngBytes);
  final sourceUrl = html.Url.createObjectUrl(html.Blob([jpgBytes], 'image/jpeg'));
  final anchor = html.AnchorElement(href: sourceUrl)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(sourceUrl);
}

Future<bool> shareJpg(Uint8List pngBytes, String filename) async {
  final navigator = html.window.navigator;
  if (!js_util.hasProperty(navigator, 'share')) return false;
  try {
    final jpgBytes = await _toJpgBytes(pngBytes);
    final file = html.File([jpgBytes], filename, {'type': 'image/jpeg'});
    final data = js_util.jsify({
      'title': 'รายงาน driverLog',
      'text': 'รายงานการเดินทางจาก driverLog',
      'files': [file],
    });
    await js_util.promiseToFuture<void>(
      js_util.callMethod(navigator, 'share', [data]),
    );
    return true;
  } catch (_) {
    return false;
  }
}

Future<Uint8List> _toJpgBytes(Uint8List pngBytes) async {
  final sourceUrl = html.Url.createObjectUrl(html.Blob([pngBytes], 'image/png'));
  final image = html.ImageElement(src: sourceUrl);
  await image.onLoad.first;

  final canvas = html.CanvasElement(width: image.width, height: image.height);
  canvas.context2D.drawImage(image, 0, 0);
  html.Url.revokeObjectUrl(sourceUrl);
  return base64Decode(canvas.toDataUrl('image/jpeg', 0.92).split(',').last);
}
