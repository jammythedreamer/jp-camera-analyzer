import 'package:flutter/material.dart';
import '../providers/text_analysis_provider.dart';

class TextExtractionSectionWidget extends StatelessWidget {
  final TextAnalysisProvider provider;
  final bool isProcessing;
  final bool isTextExtracted;
  final TextEditingController textEditingController;
  final Function(String) onTextChanged;
  final VoidCallback onAnalyzeTextPressed;

  const TextExtractionSectionWidget({
    super.key,
    required this.provider,
    required this.isProcessing,
    required this.isTextExtracted,
    required this.textEditingController,
    required this.onTextChanged,
    required this.onAnalyzeTextPressed,
  });

  @override
  Widget build(BuildContext context) {
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
          child: isProcessing
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : isTextExtracted
                  ? TextField(
                      controller: textEditingController,
                      maxLines: null, // 여러 줄 입력 허용
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'No text extracted. Try cropping the image to focus on text.',
                      ),
                      onChanged: onTextChanged,
                    )
                  : Text(
                      provider.extractedText.isEmpty 
                          ? 'No text extracted. Try cropping the image to focus on text.' 
                          : provider.extractedText, 
                      style: const TextStyle(fontSize: 16)
                    ),
        ),
        const SizedBox(height: 16),
        provider.extractedText.isNotEmpty && !isProcessing
            ? Center(
                child: ElevatedButton.icon(
                  onPressed: onAnalyzeTextPressed,
                  icon: const Icon(Icons.translate),
                  label: const Text('Analyze Text'),
                ),
              )
            : const SizedBox.shrink(),
      ],
    );
  }
}
