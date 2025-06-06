/// Model class for history items
class HistoryItem {
  final int id;
  final String extractedText;
  final String translatedText;
  final String analysisResult;
  final String createdAt;
  
  HistoryItem({
    required this.id,
    required this.extractedText,
    required this.translatedText,
    required this.analysisResult,
    required this.createdAt,
  });
  
  /// Convert to map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'extractedText': extractedText,
      'translatedText': translatedText,
      'analysisResult': analysisResult,
      'createdAt': createdAt,
    };
  }
  
  /// Create from database map
  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      id: map['id'],
      extractedText: map['extractedText'],
      translatedText: map['translatedText'],
      analysisResult: map['analysisResult'],
      createdAt: map['createdAt'],
    );
  }
}
