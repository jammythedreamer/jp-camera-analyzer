import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math; // Keep math import if used elsewhere in this file
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_editor/image_editor.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/text_analysis_provider.dart';
import '../providers/history_provider.dart';
import '../widgets/crop_painter.dart'; // Import the new CropPainter
import '../widgets/text_extraction_section_widget.dart';
import '../widgets/image_section_widget.dart';
import '../widgets/analysis_section_widget.dart';

// 드래그 상태 관리를 위한 핸들 타입
enum _HandleType { topLeft, topRight, bottomLeft, bottomRight, body, none }

/// Screen to analyze text from images
class TextAnalysisScreen extends StatefulWidget {
  final File imageFile;
  
  const TextAnalysisScreen({super.key, required this.imageFile});

  @override
  State<TextAnalysisScreen> createState() => _TextAnalysisScreenState();
}

// CropPainter class has been moved to lib/presentation/widgets/crop_painter.dart

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
                ImageSectionWidget(
                  processedImage: _processedImage,
                  isProcessing: _isProcessing,
                  onCropImagePressed: _cropImage,
                ),
                // 추출 버튼 추가
                _buildExtractButton(),
                TextExtractionSectionWidget(
                  provider: provider,
                  isProcessing: _isProcessing,
                  isTextExtracted: _isTextExtracted,
                  textEditingController: _textEditingController,
                  onTextChanged: (newText) {
                    Provider.of<TextAnalysisProvider>(context, listen: false)
                        .setExtractedText(newText);
                  },
                  onAnalyzeTextPressed: () => provider.analyzeText(),
                ),
                AnalysisSectionWidget(provider: provider),
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
