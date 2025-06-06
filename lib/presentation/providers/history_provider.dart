import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/history_item.dart';

/// Provider to manage the history of text analysis
class HistoryProvider extends ChangeNotifier {
  static Database? _database;
  List<HistoryItem> _historyItems = [];
  bool _isLoading = false;
  
  // Getters
  List<HistoryItem> get historyItems => _historyItems;
  bool get isLoading => _isLoading;
  
  // Initialize database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }
  
  // Initialize database
  Future<Database> _initDB() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'history.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }
  
  // Create database table
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        extractedText TEXT,
        translatedText TEXT,
        analysisResult TEXT,
        createdAt TEXT
      )
    ''');
  }
  
  /// Save item to history
  Future<void> saveToHistory({
    required String extractedText, 
    required String translatedText, 
    required String analysisResult,
  }) async {
    final db = await database;
    
    final historyItem = HistoryItem(
      id: DateTime.now().millisecondsSinceEpoch,
      extractedText: extractedText,
      translatedText: translatedText,
      analysisResult: analysisResult,
      createdAt: DateTime.now().toIso8601String(),
    );
    
    await db.insert(
      'history',
      historyItem.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    await fetchHistory();
  }
  
  /// Fetch all history items
  Future<void> fetchHistory() async {
    _isLoading = true;
    notifyListeners();
    
    final db = await database;
    final maps = await db.query(
      'history',
      orderBy: 'createdAt DESC',
    );
    
    _historyItems = List.generate(
      maps.length,
      (i) => HistoryItem.fromMap(maps[i]),
    );
    
    _isLoading = false;
    notifyListeners();
  }
  
  /// Delete history item by id
  Future<void> deleteHistoryItem(int id) async {
    final db = await database;
    
    await db.delete(
      'history',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    await fetchHistory();
  }
  
  /// Clear all history
  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('history');
    await fetchHistory();
  }
}
