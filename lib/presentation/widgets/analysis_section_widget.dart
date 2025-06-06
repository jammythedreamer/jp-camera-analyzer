import 'package:flutter/material.dart';
import '../providers/text_analysis_provider.dart';

class AnalysisSectionWidget extends StatelessWidget {
  final TextAnalysisProvider provider;

  const AnalysisSectionWidget({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
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
}
