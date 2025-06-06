import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 이미지 크롭을 위한 커스텀 페인터 클래스
class CropPainter extends CustomPainter {
  final Rect cropRect; // 원본 이미지 기준 크롭 영역
  final int imageWidth;  // 원본 이미지 너비
  final int imageHeight; // 원본 이미지 높이

  CropPainter(this.cropRect, this.imageWidth, this.imageHeight);

  @override
  void paint(Canvas canvas, Size size) { // size는 CustomPaint 위젯의 화면상 크기
    final Paint overlayPaint = Paint()..color = Colors.black.withOpacity(0.5);

    // 원본 이미지에서 화면에 표시되는 크기로의 스케일 비율 계산
    double scale = math.min(size.width / imageWidth, size.height / imageHeight);

    // cropRect (원본 이미지 좌표)를 화면 좌표로 변환
    // CustomPaint 캔버스의 (0,0)은 화면에 표시된 이미지 영역의 좌상단임
    Rect screenCropRect = Rect.fromLTWH(
      cropRect.left * scale,
      cropRect.top * scale,
      cropRect.width * scale,
      cropRect.height * scale,
    );

    // 크롭 영역 외부의 오버레이 그리기
    // 상단 사각형
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, screenCropRect.top), overlayPaint);
    // 하단 사각형
    canvas.drawRect(Rect.fromLTRB(0, screenCropRect.bottom, size.width, size.height), overlayPaint);
    // 좌측 사각형
    canvas.drawRect(Rect.fromLTRB(0, screenCropRect.top, screenCropRect.left, screenCropRect.bottom), overlayPaint);
    // 우측 사각형
    canvas.drawRect(Rect.fromLTRB(screenCropRect.right, screenCropRect.top, size.width, screenCropRect.bottom), overlayPaint);

    // 크롭 영역 테두리 그리기
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(screenCropRect, borderPaint);

    // 모서리 핸들 그리기
    const double handleSize = 10.0;
    final Paint handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // screenCropRect의 모서리 중앙에 핸들 위치
    canvas.drawRect(Rect.fromCenter(center: screenCropRect.topLeft, width: handleSize, height: handleSize), handlePaint);
    canvas.drawRect(Rect.fromCenter(center: screenCropRect.topRight, width: handleSize, height: handleSize), handlePaint);
    canvas.drawRect(Rect.fromCenter(center: screenCropRect.bottomLeft, width: handleSize, height: handleSize), handlePaint);
    canvas.drawRect(Rect.fromCenter(center: screenCropRect.bottomRight, width: handleSize, height: handleSize), handlePaint);
  }

  @override
  bool shouldRepaint(CropPainter oldDelegate) {
    return cropRect != oldDelegate.cropRect || 
           imageWidth != oldDelegate.imageWidth || 
           imageHeight != oldDelegate.imageHeight;
  }
}
