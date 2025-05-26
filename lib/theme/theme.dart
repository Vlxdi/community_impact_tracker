import 'dart:ui';

import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, gradient }

ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
);

ThemeData darkMode = ThemeData(
  brightness: Brightness.dark,
);

// Helper for gradient background animation
class GradientThemeData {
  static LinearGradient animatedGradient(double animationValue) {
    return LinearGradient(
      begin: Alignment(-1.0 + 2.0 * animationValue, -1.0),
      end: Alignment(1.0 - 2.0 * animationValue, 1.0),
      colors: [
        const Color.fromARGB(255, 189, 240, 255).withOpacity(0.95),
        const Color(0xFFB3E5FC).withOpacity(0.95),
        const Color.fromARGB(255, 126, 203, 255).withOpacity(0.7),
        const Color.fromARGB(255, 73, 166, 241).withOpacity(0.7),
      ],
    );
  }

  // Widget for shader-based animated background (like login page)
  static Widget shaderBackground(Animation<double> animation) {
    return FutureBuilder<FragmentProgram>(
      future: FragmentProgram.fromAsset('assets/shaders/moving_gradient.frag'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final program = snapshot.data!;
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return CustomPaint(
              painter: ShaderPainter(
                program: program,
                time: animation.value * 10.0,
              ),
            );
          },
        );
      },
    );
  }
}

// Copied from login.dart for reuse
class ShaderPainter extends CustomPainter {
  final FragmentProgram program;
  final double time;

  ShaderPainter({required this.program, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    shader.setFloat(0, size.width); // iResolution.x
    shader.setFloat(1, size.height); // iResolution.y
    shader.setFloat(2, time); // iTime

    // colorPrimary: deep blue
    shader.setFloat(3, 0.0); // R
    shader.setFloat(4, 0.2); // G
    shader.setFloat(5, 0.8); // B

    // colorAccent: lighter blue
    shader.setFloat(6, 0.4); // R
    shader.setFloat(7, 0.7); // G
    shader.setFloat(8, 1.0); // B

    // colorBlend: soft green (Color(0xFF71CD8C) ~ rgb(113, 205, 140))
    shader.setFloat(9, 113 / 255); // R
    shader.setFloat(10, 205 / 255); // G
    shader.setFloat(11, 140 / 255); // B

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant ShaderPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}
