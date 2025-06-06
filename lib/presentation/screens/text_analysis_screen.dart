import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_editor/image_editor.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/text_analysis_provider.dart';
import '../providers/history_provider.dart';

// 드래그 상태 관리를 위한 핸들 타입
enum _HandleType { topLeft, topRight, bottomLeft, bottomRight, body, none }

/// Screen to analyze text from images
class TextAnalysisScreen extends StatefulWidget {
  final File imageFile;
  
  const TextAnalysisScreen({super.key, required this.imageFile});

  @override
  State<TextAnalysisScreen> createState() => _TextAnalysisScreenState();
}

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

class _TextAnalysisScreenState extends State<TextAnalysisScreen> {
  late TextEditingController _textEditingController;
  File? _processedImage;
  bool _isProcessing = false;
  bool _isTextExtracted = false;
  
  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController();
    _processedImage = widget.imageFile;
    // 자동 텍스트 추출 제거: 버튼 클릭 시 추출하도록 변경
  }
  
  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: _saveToHistory,
          ),
        ],
      ),
      body: Consumer<TextAnalysisProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImageSection(),
                // 추출 버튼 추가
                _buildExtractButton(),
                _buildTextExtractionSection(provider),
                _buildAnalysisSection(provider),
              ],
            ),
          );
        },
      ),
    );
  }
  
  /// 텍스트 추출 버튼 위젯
  Widget _buildExtractButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: ElevatedButton.icon(
        onPressed: _isProcessing ? null : _processImageAndExtractText,
        icon: const Icon(Icons.text_fields),
        label: Text(_isProcessing ? 'Extracting...' : 'Extract Text'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          textStyle: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Build the image display section
  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected Image',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Container(
          height: 250,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _processedImage != null
                    ? Image.file(
                        _processedImage!,
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
              ),
              if (_isProcessing)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: _cropImage,
            icon: const Icon(Icons.crop),
            label: const Text('Crop Image'),
          ),
        ),
      ],
    );
  }
  
  /// Build the text extraction section
  Widget _buildTextExtractionSection(TextAnalysisProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Extracted Text',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[100],
          ),
          child: _isProcessing
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _isTextExtracted // 텍스트가 추출되었을 때만 TextField를 보여줍니다.
                  ? TextField(
                      controller: _textEditingController,
                      maxLines: null, // 여러 줄 입력 허용
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'No text extracted. Try cropping the image to focus on text.',
                      ),
                      onChanged: (newText) {
                        Provider.of<TextAnalysisProvider>(context, listen: false)
                            .setExtractedText(newText);
                      },
                    )
                  : Text( // 텍스트 추출 전 또는 실패 시 메시지 표시
                      provider.extractedText.isEmpty 
                          ? 'No text extracted. Try cropping the image to focus on text.' 
                          : provider.extractedText, 
                      style: const TextStyle(fontSize: 16)
                    ),
        ),
        const SizedBox(height: 16),
        provider.extractedText.isNotEmpty && !_isProcessing
            ? Center(
                child: ElevatedButton.icon(
                  onPressed: () => provider.analyzeText(),
                  icon: const Icon(Icons.translate),
                  label: const Text('Analyze Text'),
                ),
              )
            : const SizedBox.shrink(),
      ],
    );
  }
  
  /// Build the analysis results section
  Widget _buildAnalysisSection(TextAnalysisProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Analyzing text...'),
            ],
          ),
        ),
      );
    }
    
    if (provider.error.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red),
        ),
        child: Text(
          'Error: ${provider.error}',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (provider.translatedText.isNotEmpty || provider.analysisResult.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (provider.translatedText.isNotEmpty) ...[
            Text(
              'Translation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(8),
                color: Colors.blue[50],
              ),
              child: Text(
                provider.translatedText,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (provider.analysisResult.isNotEmpty) ...[
            Text(
              'Analysis',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
                color: Colors.green[50],
              ),
              child: Text(
                provider.analysisResult,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ],
      );
    }

    return const SizedBox.shrink();
  }
  
  /// Show editor to select text area
  Future<void> _cropImage() async {
    try {
      if (_processedImage == null) return;
      
      // 이미지를 바이트로 읽기
      final Uint8List bytes = await _processedImage!.readAsBytes();
      
      // 이미지 크기 계산
      final image = await decodeImageFromList(bytes);
      final int originalWidth = image.width;
      final int originalHeight = image.height;
      
      // 기본 크롭 영역 설정 (처음에는 이미지의 80%)
      double cropX = originalWidth * 0.1;
      double cropY = originalHeight * 0.1;
      double cropWidth = originalWidth * 0.8;
      double cropHeight = originalHeight * 0.8;
      
      // 사용자 선택 크롭 영역 (원본 이미지 기준)
      Rect currentSelectedRect = Rect.fromLTWH(cropX, cropY, cropWidth, cropHeight);
      
      // 드래그 상태 관리를 위한 변수
      _HandleType activeHandle = _HandleType.none;
      bool isDragging = false;
      Offset? panStartLocalPosition; // 드래그 시작 시 로컬 터치 위치 (GestureDetector 기준)
      Rect? initialRectAtPanStart;   // 드래그 시작 시 크롭 사각형 (원본 이미지 기준)

      const double minCropSize = 50.0; // 최소 크롭 크기 (원본 이미지 픽셀 기준)
      const double handleHitboxSize = 30.0; // 핸들 터치 영역 크기 (화면 픽셀 기준)
      
      // 커스텀 UI 표시
      final result = await Navigator.of(context).push<File>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (modalContext) => StatefulBuilder(
            builder: (context, setModalState) {
              return Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.black,
                  title: const Text('이미지 자르기', style: TextStyle(color: Colors.white)),
                  leading: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        final Uint8List? croppedBytes = await _performCrop(
                          bytes,
                          currentSelectedRect.left.toInt(),
                          currentSelectedRect.top.toInt(),
                          currentSelectedRect.width.toInt(),
                          currentSelectedRect.height.toInt(),
                        );
                        if (croppedBytes != null) {
                          final tempDir = await getTemporaryDirectory();
                          final file = File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
                          await file.writeAsBytes(croppedBytes);
                          Navigator.of(context).pop(file);
                        }
                      },
                      child: const Text('완료', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                body: Center(
                  child: LayoutBuilder( // LayoutBuilder를 사용하여 GestureDetector의 크기 얻기
                    builder: (context, constraints) {
                      // 원본 이미지와 화면 표시 영역 간의 스케일 및 오프셋 계산
                      final double scale = math.min(
                        constraints.maxWidth / originalWidth,
                        constraints.maxHeight / originalHeight,
                      );
                      final double displayedImageWidth = originalWidth * scale;
                      final double displayedImageHeight = originalHeight * scale;
                      
                      // GestureDetector 내에서 실제 이미지가 표시되는 좌상단 오프셋
                      final Offset imageOffsetInGestureDetector = Offset(
                        (constraints.maxWidth - displayedImageWidth) / 2,
                        (constraints.maxHeight - displayedImageHeight) / 2,
                      );

                      return GestureDetector(
                        onPanStart: (details) {
                          Offset touchInGestureDetector = details.localPosition;
                          Offset touchOnScreenImage = Offset(
                            touchInGestureDetector.dx - imageOffsetInGestureDetector.dx,
                            touchInGestureDetector.dy - imageOffsetInGestureDetector.dy,
                          );

                          Rect screenHandleRect = Rect.fromLTWH(
                            currentSelectedRect.left * scale,
                            currentSelectedRect.top * scale,
                            currentSelectedRect.width * scale,
                            currentSelectedRect.height * scale,
                          );

                          _HandleType newActiveHandle = _HandleType.none;
                          if (Rect.fromCenter(center: screenHandleRect.topLeft, width: handleHitboxSize, height: handleHitboxSize).contains(touchOnScreenImage)) {
                            newActiveHandle = _HandleType.topLeft;
                          } else if (Rect.fromCenter(center: screenHandleRect.topRight, width: handleHitboxSize, height: handleHitboxSize).contains(touchOnScreenImage)) {
                            newActiveHandle = _HandleType.topRight;
                          } else if (Rect.fromCenter(center: screenHandleRect.bottomLeft, width: handleHitboxSize, height: handleHitboxSize).contains(touchOnScreenImage)) {
                            newActiveHandle = _HandleType.bottomLeft;
                          } else if (Rect.fromCenter(center: screenHandleRect.bottomRight, width: handleHitboxSize, height: handleHitboxSize).contains(touchOnScreenImage)) {
                            newActiveHandle = _HandleType.bottomRight;
                          } else if (screenHandleRect.contains(touchOnScreenImage)) {
                            newActiveHandle = _HandleType.body;
                          }

                          if (newActiveHandle != _HandleType.none) {
                            setModalState(() {
                              isDragging = true;
                              activeHandle = newActiveHandle;
                              panStartLocalPosition = touchOnScreenImage; // 화면 이미지 기준 터치 시작점
                              initialRectAtPanStart = currentSelectedRect; // 원본 이미지 기준 사각형
                            });
                          }
                        },
                        onPanUpdate: (details) {
                          if (!isDragging || panStartLocalPosition == null || initialRectAtPanStart == null) return;

                          Offset touchInGestureDetector = details.localPosition;
                          Offset currentTouchOnScreenImage = Offset(
                            touchInGestureDetector.dx - imageOffsetInGestureDetector.dx,
                            touchInGestureDetector.dy - imageOffsetInGestureDetector.dy,
                          );

                          double dxScreenImage = currentTouchOnScreenImage.dx - panStartLocalPosition!.dx;
                          double dyScreenImage = currentTouchOnScreenImage.dy - panStartLocalPosition!.dy;

                          double dxImage = dxScreenImage / scale;
                          double dyImage = dyScreenImage / scale;

                          Rect newRect = initialRectAtPanStart!;
                          double newLeft = newRect.left;
                          double newTop = newRect.top;
                          double newRight = newRect.right;
                          double newBottom = newRect.bottom;

                          switch (activeHandle) {
                            case _HandleType.body:
                              newLeft += dxImage;
                              newTop += dyImage;
                              newRight += dxImage;
                              newBottom += dyImage;
                              break;
                            case _HandleType.topLeft:
                              newLeft += dxImage;
                              newTop += dyImage;
                              break;
                            case _HandleType.topRight:
                              newRight += dxImage;
                              newTop += dyImage;
                              break;
                            case _HandleType.bottomLeft:
                              newLeft += dxImage;
                              newBottom += dyImage;
                              break;
                            case _HandleType.bottomRight:
                              newRight += dxImage;
                              newBottom += dyImage;
                              break;
                            case _HandleType.none:
                              return;
                          }
                          
                          // Normalize (좌표 순서 및 최소 크기 보장)
                          double tempLeft = math.min(newLeft, newRight);
                          double tempRight = math.max(newLeft, newRight);
                          double tempTop = math.min(newTop, newBottom);
                          double tempBottom = math.max(newTop, newBottom);

                          if (tempRight - tempLeft < minCropSize) {
                            if (activeHandle == _HandleType.topLeft || activeHandle == _HandleType.bottomLeft) {
                              tempLeft = tempRight - minCropSize;
                            } else {
                              tempRight = tempLeft + minCropSize;
                            }
                          }
                          if (tempBottom - tempTop < minCropSize) {
                            if (activeHandle == _HandleType.topLeft || activeHandle == _HandleType.topRight) {
                              tempTop = tempBottom - minCropSize;
                            } else {
                              tempBottom = tempTop + minCropSize;
                            }
                          }
                          
                          // 이미지 경계 내 클램핑
                          tempLeft = tempLeft.clamp(0.0, originalWidth - minCropSize);
                          tempTop = tempTop.clamp(0.0, originalHeight - minCropSize);
                          tempRight = tempRight.clamp(minCropSize, originalWidth.toDouble());
                          tempBottom = tempBottom.clamp(minCropSize, originalHeight.toDouble());

                          // 최종적으로 LTRB 순서와 최소 크기 재확인
                          newLeft = tempLeft.clamp(0.0, tempRight - minCropSize);
                          newRight = tempRight.clamp(newLeft + minCropSize, originalWidth.toDouble());
                          newTop = tempTop.clamp(0.0, tempBottom - minCropSize);
                          newBottom = tempBottom.clamp(newTop + minCropSize, originalHeight.toDouble());

                          setModalState(() {
                            currentSelectedRect = Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
                          });
                        },
                        onPanEnd: (details) {
                          setModalState(() {
                            isDragging = false;
                            activeHandle = _HandleType.none;
                            panStartLocalPosition = null;
                            initialRectAtPanStart = null;
                          });
                        },
                        child: SizedBox( // GestureDetector의 크기를 명확히 하기 위함
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 실제 이미지가 표시될 영역 (CustomPaint와 동일 크기)
                              SizedBox(
                                width: displayedImageWidth,
                                height: displayedImageHeight,
                                child: Stack(
                                  children: [
                                    Image.memory(
                                      bytes,
                                      fit: BoxFit.contain,
                                      width: displayedImageWidth,
                                      height: displayedImageHeight,
                                    ),
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: CropPainter(currentSelectedRect, originalWidth, originalHeight),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
      
      if (result != null) {
        setState(() {
          _processedImage = result;
          // 크롭 후 텍스트 자동 추출 제거 - 사용자가 직접 Extract Text 버튼을 클릭해야 함
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 편집 오류: $e')),
        );
      }
    }
  }
  
  /// 이미지 크롭 수행 함수
  Future<Uint8List?> _performCrop(Uint8List originalImage, int x, int y, int width, int height) async {
    try {
      // image_editor 옵션 생성
      final ImageEditorOption option = ImageEditorOption();
      
      // 크롭 옵션 추가
      option.addOption(ClipOption(
        x: x,
        y: y,
        width: width,
        height: height,
      ));
      
      // 이미지 편집 실행
      final Uint8List? result = await ImageEditor.editImage(
        image: originalImage,
        imageEditorOption: option,
      );
      
      return result;
    } catch (e) {
      debugPrint('이미지 크롭 오류: $e');
      return null;
    }
  }
  
  /// Process the image and extract text using ML Kit
  Future<void> _processImageAndExtractText() async {
    if (_processedImage == null) return;
    
    setState(() {
      _isProcessing = true;
      _isTextExtracted = false;
    });
    
    try {
      final inputImage = InputImage.fromFile(_processedImage!);
      // 일본어 인식을 위해 스크립트 옵션 추가
    final textRecognizer = GoogleMlKit.vision.textRecognizer(script: TextRecognitionScript.japanese);
      final recognizedText = await textRecognizer.processImage(inputImage);
      
      String extractedText = '';
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          extractedText += '${line.text}\n';
        }
      }
      
      if (extractedText.isEmpty) {
        extractedText = 'No text detected in the image. Please try with another image.';
      }
      
      Provider.of<TextAnalysisProvider>(context, listen: false)
          .setExtractedText(extractedText);
          
      setState(() {
        _isTextExtracted = true;
        _isProcessing = false;
      });
      
      // 자동으로 히스토리에 저장
      _saveToHistory();
      
      // 텍스트 인식기 닫기
      textRecognizer.close();

    // TextEditingController 업데이트
    if (mounted) {
      _textEditingController.text = Provider.of<TextAnalysisProvider>(context, listen: false).extractedText;
    }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isTextExtracted = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error extracting text: $e')),
        );
      }
    }
  }
  
  /// Save current analysis to history
  Future<void> _saveToHistory() async {
    if (!_isTextExtracted) return;
    
    final textProvider = Provider.of<TextAnalysisProvider>(context, listen: false);
    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
    
    // 텍스트가 비어 있으면 저장하지 않음
    if (textProvider.extractedText.isEmpty) return;
    
    try {
      // HistoryProvider에 텍스트 데이터를 저장
      await historyProvider.saveToHistory(
        extractedText: textProvider.extractedText,
        translatedText: textProvider.translatedText,
        analysisResult: textProvider.analysisResult,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved to history')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving to history: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }
}
