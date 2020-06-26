import 'dart:async';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';

/// Se queda en full screen no hay botones del sistema
void fullScreen() {
  SystemChrome.setEnabledSystemUIOverlays([]);
}

/// Espera a que las dimensiones iniciales de la pantalla estén disponibles.
///
/// Debido al problema # 5259 de flutter, cuando la aplicación se inicia, el tamaño puede ser 0x0.
/// Esto espera a que la información se actualice correctamente.
///
/// Una mejor práctica sería implementar ganchos de cambio de tamaño en su juego y componentes y no usar esto en absoluto.
/// Asegúrese de que sus componentes puedan renderizarse y actualizarse para cualquier tamaño de pantalla posible.
Future<Size> initialDimensions() async {
  // https://github.com/flutter/flutter/issues/5259
  // "In release mode we start off at 0x0 but we don't in debug mode"
  return await new Future<Size>(() {
    if (window.physicalSize.isEmpty) {
      final completer = new Completer<Size>();
      window.onMetricsChanged = () {
        if (!window.physicalSize.isEmpty) {
          completer.complete(window.physicalSize / window.devicePixelRatio);
        }
      };
      return completer.future;
    }
    return window.physicalSize / window.devicePixelRatio;
  });
}

/// Returns a [material.TextPainter] that allows for text rendering and size measuring.
///
/// Rendering text on the Canvas is not as trivial as it should.
/// This methods exposes all possible parameters you might want to pass to render text, with sensible defaults.
/// Only the [text] is mandatory.
/// It returns a [material.TextPainter]. that have the properties: paint, width and height.
/// Example usage:
///
///     final tp = Flame.util.text('Score: $score', fontSize: 48.0, fontFamily: 'Awesome Font');
///     tp.paint(c, Offset(size.width - p.width - 10, size.height - p.height - 10));
///
material.TextPainter text(
  String text, {
  double fontSize: 24.0,
  Color color: material.Colors.black,
  String fontFamily: 'Arial',
  TextAlign textAlign: TextAlign.left,
  TextDirection textDirection: TextDirection.ltr,
}) {
  material.TextStyle style = new material.TextStyle(
    color: color,
    fontSize: fontSize,
    fontFamily: fontFamily,
  );
  material.TextSpan span = new material.TextSpan(
    style: style,
    text: text,
  );
  material.TextPainter tp = new material.TextPainter(
    text: span,
    textAlign: textAlign,
    textDirection: textDirection,
  );
  tp.layout();
  return tp;
}

void enableEvents() {
  window.onPlatformMessage = BinaryMessages.handlePlatformMessage;
}

/// Esto vincula correctamente un reconocedor de gestos a el juego.
///
/// Uso esto para que funcione en caso de que su aplicación también contenga otros widgets.
void addGestureRecognizer(GestureRecognizer recognizer) {
  GestureBinding.instance.pointerRouter.addGlobalRoute((PointerEvent e) {
    if (e is PointerDownEvent) {
      recognizer.addPointer(e);
    }
  });
}
