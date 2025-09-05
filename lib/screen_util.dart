import 'package:flutter/widgets.dart';

/// Utility to scale dimensions based on screen size.
///
/// Call [ScreenUtil.init] in a widget's build method before using [w] or [h]
/// to scale width and height respectively. The default design size is based on
/// a 375x812 layout.
class ScreenUtil {
  static late double _scaleWidth;
  static late double _scaleHeight;
  static bool _initialized = false;

  /// Initialize with the current [context] and an optional design size.
  static void init(BuildContext context,
      {double designWidth = 375, double designHeight = 812}) {
    final size = MediaQuery.sizeOf(context);
    _scaleWidth = size.width / designWidth;
    _scaleHeight = size.height / designHeight;
    _initialized = true;
  }

  static double w(double width) {
    if (!_initialized) {
      throw StateError('ScreenUtil.init must be called before using w().');
    }
    return width * _scaleWidth;
  }

  static double h(double height) {
    if (!_initialized) {
      throw StateError('ScreenUtil.init must be called before using h().');
    }
    return height * _scaleHeight;
  }

  static double sp(double fontSize) {
    if (!_initialized) {
      throw StateError('ScreenUtil.init must be called before using sp().');
    }
    final scale = _scaleWidth < _scaleHeight ? _scaleWidth : _scaleHeight;
    return fontSize * scale;
  }
}

