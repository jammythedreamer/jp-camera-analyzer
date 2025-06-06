import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Text analysis provider to handle API requests and responses
class TextAnalysisProvider extends ChangeNotifier {
  String _extractedText = '';
  String _translatedText = '';
  String _analysisResult = '';
  bool _isLoading = false;
  String _error = '';

  // Getters
  String get extractedText => _extractedText;
  String get translatedText => _translatedText;
  String get analysisResult => _analysisResult;
  bool get isLoading => _isLoading;
  String get error => _error;

  /// Set the extracted text from OCR
  void setExtractedText(String text) {
    _extractedText = text;
    notifyListeners();
  }

  /// Clear all data
  void clearData() {
    _extractedText = '';
    _translatedText = '';
    _analysisResult = '';
    _error = '';
    notifyListeners();
  }

  /// Analyze the extracted text using custom API
  Future<void> analyzeText() async {
    if (_extractedText.isEmpty) {
      _error = 'No text extracted to analyze';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _error = '';
      notifyListeners();

      // Replace with your API endpoint
      final apiUrl = 'https://your-custom-api-endpoint/analyze';
      
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': _extractedText}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _translatedText = data['translated'] ?? '';
        _analysisResult = data['analysis'] ?? '';
      } else {
        _error = 'Failed to analyze text. Status code: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Error analyzing text: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
