/// SQLite database for persistent research data storage
/// Stores all inference logs for later analysis and export

import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'research_logger.dart';

class ResearchDatabase {
  static final ResearchDatabase instance = ResearchDatabase._init();
  static Database? _database;

  ResearchDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('research_logs.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE inference_logs (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        model_id TEXT NOT NULL,
        model_format TEXT NOT NULL,
        model_display_name TEXT NOT NULL,
        command_text TEXT NOT NULL,
        transcribed_text TEXT,
        word_error_rate REAL,
        expected_function TEXT,
        expected_params TEXT,
        actual_function TEXT,
        actual_params TEXT,
        raw_response TEXT,
        latency_ms INTEGER NOT NULL,
        ttft_ms INTEGER,
        ram_usage_mb REAL,
        success INTEGER NOT NULL,
        json_valid INTEGER NOT NULL,
        semantic_correct INTEGER NOT NULL,
        tier TEXT NOT NULL,
        error TEXT,
        category TEXT NOT NULL
      )
    ''');

    // Create indexes for common queries
    await db.execute('CREATE INDEX idx_model_id ON inference_logs(model_id)');
    await db.execute('CREATE INDEX idx_timestamp ON inference_logs(timestamp)');
    await db.execute('CREATE INDEX idx_category ON inference_logs(category)');
    await db.execute('CREATE INDEX idx_success ON inference_logs(success)');
  }

  /// Insert a log entry
  Future<void> insertLog(InferenceLog log) async {
    final db = await database;
    
    await db.insert(
      'inference_logs',
      {
        'id': log.id,
        'timestamp': log.timestamp.toIso8601String(),
        'model_id': log.modelId,
        'model_format': log.modelFormat,
        'model_display_name': log.modelDisplayName,
        'command_text': log.commandText,
        'transcribed_text': log.transcribedText,
        'word_error_rate': log.wordErrorRate,
        'expected_function': log.expectedFunction,
        'expected_params': log.expectedParams != null 
            ? jsonEncode(log.expectedParams) 
            : null,
        'actual_function': log.actualFunction,
        'actual_params': log.actualParams != null 
            ? jsonEncode(log.actualParams) 
            : null,
        'raw_response': log.rawResponse,
        'latency_ms': log.latencyMs,
        'ttft_ms': log.ttftMs,
        'ram_usage_mb': log.ramUsageMB,
        'success': log.success ? 1 : 0,
        'json_valid': log.jsonValid ? 1 : 0,
        'semantic_correct': log.semanticCorrect ? 1 : 0,
        'tier': log.tier,
        'error': log.error,
        'category': log.category,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all logs
  Future<List<InferenceLog>> getAllLogs() async {
    final db = await database;
    final maps = await db.query('inference_logs', orderBy: 'timestamp DESC');
    
    return maps.map((map) => _logFromMap(map)).toList();
  }

  /// Get logs by model
  Future<List<InferenceLog>> getLogsByModel(String modelId) async {
    final db = await database;
    final maps = await db.query(
      'inference_logs',
      where: 'model_id = ?',
      whereArgs: [modelId],
      orderBy: 'timestamp DESC',
    );
    
    return maps.map((map) => _logFromMap(map)).toList();
  }

  /// Get logs by category
  Future<List<InferenceLog>> getLogsByCategory(String category) async {
    final db = await database;
    final maps = await db.query(
      'inference_logs',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'timestamp DESC',
    );
    
    return maps.map((map) => _logFromMap(map)).toList();
  }

  /// Get logs within date range
  Future<List<InferenceLog>> getLogsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final maps = await db.query(
      'inference_logs',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
    
    return maps.map((map) => _logFromMap(map)).toList();
  }

  /// Get summary statistics
  Future<Map<String, dynamic>> getSummaryStats() async {
    final db = await database;
    
    // Total count
    final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM inference_logs');
    final total = Sqflite.firstIntValue(countResult) ?? 0;
    
    if (total == 0) {
      return {
        'total': 0,
        'success_rate': 0.0,
        'avg_latency_ms': 0.0,
        'semantic_accuracy': 0.0,
      };
    }

    // Success rate
    final successResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM inference_logs WHERE success = 1'
    );
    final successCount = Sqflite.firstIntValue(successResult) ?? 0;

    // Semantic accuracy
    final semanticResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM inference_logs WHERE semantic_correct = 1'
    );
    final semanticCount = Sqflite.firstIntValue(semanticResult) ?? 0;

    // Average latency
    final latencyResult = await db.rawQuery(
      'SELECT AVG(latency_ms) as avg FROM inference_logs'
    );
    final avgLatency = latencyResult.first['avg'] as double? ?? 0.0;

    return {
      'total': total,
      'success_rate': successCount / total,
      'avg_latency_ms': avgLatency,
      'semantic_accuracy': semanticCount / total,
    };
  }

  /// Export all logs to CSV file
  Future<File> exportToCsv(String filePath) async {
    final logs = await getAllLogs();
    final buffer = StringBuffer();
    
    buffer.writeln(InferenceLog.csvHeader());
    for (final log in logs) {
      buffer.writeln(log.toCsvRow());
    }

    final file = File(filePath);
    await file.writeAsString(buffer.toString());
    return file;
  }

  /// Export all logs to JSON file
  Future<File> exportToJson(String filePath) async {
    final logs = await getAllLogs();
    final jsonData = logs.map((log) => log.toJson()).toList();

    final file = File(filePath);
    await file.writeAsString(
      JsonEncoder.withIndent('  ').convert(jsonData),
    );
    return file;
  }

  /// Clear all logs
  Future<void> clearAllLogs() async {
    final db = await database;
    await db.delete('inference_logs');
  }

  /// Delete logs older than specified days
  Future<void> deleteOldLogs(int days) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    
    await db.delete(
      'inference_logs',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  /// Convert database map to InferenceLog
  InferenceLog _logFromMap(Map<String, dynamic> map) {
    return InferenceLog(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      modelId: map['model_id'] as String,
      modelFormat: map['model_format'] as String,
      modelDisplayName: map['model_display_name'] as String,
      commandText: map['command_text'] as String,
      transcribedText: map['transcribed_text'] as String?,
      wordErrorRate: map['word_error_rate'] as double?,
      expectedFunction: map['expected_function'] as String?,
      expectedParams: map['expected_params'] != null
          ? jsonDecode(map['expected_params'] as String)
          : null,
      actualFunction: map['actual_function'] as String?,
      actualParams: map['actual_params'] != null
          ? jsonDecode(map['actual_params'] as String)
          : null,
      rawResponse: map['raw_response'] as String?,
      latencyMs: map['latency_ms'] as int,
      ttftMs: map['ttft_ms'] as int?,
      ramUsageMB: map['ram_usage_mb'] as double?,
      success: (map['success'] as int) == 1,
      jsonValid: (map['json_valid'] as int) == 1,
      semanticCorrect: (map['semantic_correct'] as int) == 1,
      tier: map['tier'] as String,
      error: map['error'] as String?,
      category: map['category'] as String,
    );
  }
}
