import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const int _size = 2048;

class _Rgb {
  const _Rgb(this.r, this.g, this.b);
  final int r;
  final int g;
  final int b;

  static _Rgb lerp(_Rgb a, _Rgb b, double t) {
    return _Rgb(
      (a.r + (b.r - a.r) * t).round(),
      (a.g + (b.g - a.g) * t).round(),
      (a.b + (b.b - a.b) * t).round(),
    );
  }
}

const _bgTop = _Rgb(0x10, 0x1c, 0x17);
const _bgBottom = _Rgb(0x07, 0x0d, 0x0b);
const _glow = _Rgb(0x0f, 0x9f, 0x72);
const _bar1Top = _Rgb(0x0b, 0x6e, 0x56);
const _bar1Bottom = _Rgb(0x0e, 0x8a, 0x69);
const _bar2Top = _Rgb(0x10, 0xa8, 0x76);
const _bar2Bottom = _Rgb(0x12, 0xc2, 0x8b);
const _bar3Top = _Rgb(0x34, 0xd9, 0x9f);
const _bar3Bottom = _Rgb(0x7b, 0xf0, 0xc0);
const _line = _Rgb(0xdf, 0xff, 0xf2);
const _dot = _Rgb(0x8d, 0xff, 0xd2);

void main() {
  final icon = _renderIcon(withBackground: true, scale: 1.0);
  _save('assets/images/app_icon.png', icon);

  final foreground = _renderIcon(withBackground: false, scale: 0.74);
  _save('assets/images/app_icon_foreground.png', foreground);

  final splash = img.copyResize(
    _renderIcon(withBackground: false, scale: 1.0),
    width: 512,
    height: 512,
    interpolation: img.Interpolation.cubic,
  );
  _save('assets/images/splash_logo.png', splash);

  stdout.writeln('Brand assets generated.');
}

img.Image _renderIcon({required bool withBackground, required double scale}) {
  final image = img.Image(width: _size, height: _size, numChannels: 4);

  for (var y = 0; y < _size; y++) {
    final ny = y / _size;
    for (var x = 0; x < _size; x++) {
      if (withBackground) {
        final base = _Rgb.lerp(_bgTop, _bgBottom, ny);
        final nx = x / _size;
        final dx = nx - 0.5;
        final dy = ny - 0.48;
        final dist = math.sqrt(dx * dx + dy * dy);
        final glow = math.pow(math.max(0.0, 1 - dist / 0.62), 2.0) * 0.16;
        final blended = _Rgb.lerp(base, _glow, glow.toDouble());
        image.setPixelRgba(x, y, blended.r, blended.g, blended.b, 255);
      } else {
        image.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }

  final w = _size.toDouble();
  final h = _size.toDouble();

  double sx(double nx) => w / 2 + (nx - 0.5) * (w * scale);
  double sy(double ny) => h / 2 + (ny - 0.5) * (h * scale);

  final barWidth = w * 0.108 * scale;
  final radius = barWidth * 0.46;
  final bottom = sy(0.70);
  final bars = <(double, double, _Rgb, _Rgb)>[
    (0.300, 0.215, _bar1Top, _bar1Bottom),
    (0.463, 0.295, _bar2Top, _bar2Bottom),
    (0.626, 0.375, _bar3Top, _bar3Bottom),
  ];

  for (final bar in bars) {
    final left = sx(bar.$1);
    final top = bottom - (h * bar.$2 * scale);
    _roundedGradientRect(
      image,
      left,
      top,
      left + barWidth,
      bottom,
      radius,
      bar.$3,
      bar.$4,
    );
  }

  final points = <(double, double)>[
    (0.255, 0.492),
    (0.415, 0.405),
    (0.575, 0.322),
    (0.735, 0.238),
  ];
  _polyline(image, points.map((p) => (sx(p.$1), sy(p.$2))).toList(), w * 0.020 * scale, _line);
  _filledCircle(image, sx(0.735), sy(0.238), w * 0.036 * scale, _dot);
  _filledCircle(image, sx(0.735), sy(0.238), w * 0.016 * scale, _bgBottom);

  return img.copyResize(
    image,
    width: 1024,
    height: 1024,
    interpolation: img.Interpolation.cubic,
  );
}

void _save(String path, img.Image image) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(image, level: 9));
}

void _roundedGradientRect(
  img.Image image,
  double left,
  double top,
  double right,
  double bottom,
  double radius,
  _Rgb topColor,
  _Rgb bottomColor,
) {
  final minX = math.max(0, left.floor() - 1);
  final maxX = math.min(image.width - 1, right.ceil() + 1);
  final minY = math.max(0, top.floor() - 1);
  final maxY = math.min(image.height - 1, bottom.ceil() + 1);

  for (var y = minY; y <= maxY; y++) {
    final py = y + 0.5;
    final t = ((py - top) / (bottom - top)).clamp(0.0, 1.0);
    final color = _Rgb.lerp(topColor, bottomColor, t);
    for (var x = minX; x <= maxX; x++) {
      final px = x + 0.5;
      if (_insideRoundedRect(px, py, left, top, right, bottom, radius)) {
        image.setPixelRgba(x, y, color.r, color.g, color.b, 255);
      }
    }
  }
}

bool _insideRoundedRect(
  double px,
  double py,
  double left,
  double top,
  double right,
  double bottom,
  double radius,
) {
  if (px < left || px > right || py < top || py > bottom) return false;
  final cx = px.clamp(left + radius, right - radius);
  final cy = py.clamp(top + radius, bottom - radius);
  final dx = px - cx;
  final dy = py - cy;
  return dx * dx + dy * dy <= radius * radius;
}

void _filledCircle(img.Image image, double cx, double cy, double radius, _Rgb color) {
  final minX = math.max(0, (cx - radius).floor() - 1);
  final maxX = math.min(image.width - 1, (cx + radius).ceil() + 1);
  final minY = math.max(0, (cy - radius).floor() - 1);
  final maxY = math.min(image.height - 1, (cy + radius).ceil() + 1);
  final r2 = radius * radius;
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final dx = x + 0.5 - cx;
      final dy = y + 0.5 - cy;
      if (dx * dx + dy * dy <= r2) {
        image.setPixelRgba(x, y, color.r, color.g, color.b, 255);
      }
    }
  }
}

void _polyline(
  img.Image image,
  List<(double, double)> points,
  double thickness,
  _Rgb color,
) {
  final half = thickness / 2;
  for (var i = 0; i < points.length - 1; i++) {
    final a = points[i];
    final b = points[i + 1];
    final minX = math.max(0, (math.min(a.$1, b.$1) - half).floor() - 1);
    final maxX = math.min(image.width - 1, (math.max(a.$1, b.$1) + half).ceil() + 1);
    final minY = math.max(0, (math.min(a.$2, b.$2) - half).floor() - 1);
    final maxY = math.min(image.height - 1, (math.max(a.$2, b.$2) + half).ceil() + 1);
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final d = _distanceToSegment(x + 0.5, y + 0.5, a.$1, a.$2, b.$1, b.$2);
        if (d <= half) {
          image.setPixelRgba(x, y, color.r, color.g, color.b, 255);
        }
      }
    }
  }
}

double _distanceToSegment(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) {
    final ex = px - ax;
    final ey = py - ay;
    return math.sqrt(ex * ex + ey * ey);
  }
  var t = ((px - ax) * dx + (py - ay) * dy) / lengthSquared;
  t = t.clamp(0.0, 1.0);
  final ex = px - (ax + t * dx);
  final ey = py - (ay + t * dy);
  return math.sqrt(ex * ex + ey * ey);
}
