import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/history_item.dart';

/// Screen to display details of a history item
class HistoryDetailScreen extends StatelessWidget {
  final HistoryItem historyItem;
  
  const HistoryDetailScreen({
    super.key, 
    required this.historyItem,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History Detail'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionCard(
              context: context,
              title: '추출된 텍스트',
              content: historyItem.extractedText,
              borderColor: Colors.blue,
            ),
            const SizedBox(height: 16),
            if (historyItem.translatedText.isNotEmpty)
              _buildSectionCard(
                context: context,
                title: '번역',
                content: historyItem.translatedText,
                borderColor: Colors.green,
              ),
            const SizedBox(height: 16),
            if (historyItem.analysisResult.isNotEmpty)
              _buildSectionCard(
                context: context,
                title: '분석 결과',
                content: historyItem.analysisResult,
                borderColor: Colors.orange,
              ),
            const SizedBox(height: 24),
            _buildDateSection(context),
          ],
        ),
      ),
    );
  }
  
  /// Build a section card with copy functionality
  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required String content,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(8),
            color: borderColor.withOpacity(0.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _copyToClipboard(context, content),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('복사'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// Build the date section
  Widget _buildDateSection(BuildContext context) {
    final createdAt = DateTime.parse(historyItem.createdAt);
    final formattedDate = '${createdAt.year}년 ${createdAt.month}월 ${createdAt.day}일 ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
    
    return Center(
      child: Text(
        '생성 시간: $formattedDate',
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
  
  /// Copy text to clipboard and show a snackbar
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('클립보드에 복사되었습니다')),
    );
  }
}
