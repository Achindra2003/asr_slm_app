/// Research logging service for collecting experiment data
/// Logs all inference attempts with detailed metrics for paper analysis

import 'package:my_agent_app/models/model_provider.dart';

/// Single inference log entry for research analysis
class InferenceLog {
  final String id;                    // Unique log ID
  final DateTime timestamp;           // When inference occurred
  
  // Model information
  final String modelId;               // HuggingFace model ID
  final String modelFormat;           // "cactus" or "onnx"
  final String modelDisplayName;      // Human-readable name
  
  // Input data
  final String commandText;           // Original user command
  final String? transcribedText;      // ASR output (if different from command)
  final double? wordErrorRate;        // WER if ASR was used
  
  // Expected output (ground truth)
  final String? expectedFunction;     // Expected function name
  final Map<String, dynamic>? expectedParams;  // Expected parameters
  
  // Actual output
  final String? actualFunction;       // Function called by model
  final Map<String, dynamic>? actualParams;    // Actual parameters
  final String? rawResponse;          // Raw model output
  
  // Performance metrics
  final int latencyMs;                // Total inference time
  final int? ttftMs;                  // Time to first token
  final double? ramUsageMB;           // RAM used during inference
  
  // Quality metrics
  final bool success;                 // Did execution succeed?
  final bool jsonValid;               // Was output valid JSON?
  final bool semanticCorrect;         // Did it call correct function?
  final String tier;                  // "llm" or "fallback"
  final String? error;                // Error message if failed
  
  // Categorization
  final String category;              // e.g., "temporal", "contextual", "simple"

  InferenceLog({
    required this.id,
    required this.timestamp,
    required this.modelId,
    required this.modelFormat,
    required this.modelDisplayName,
    required this.commandText,
    this.transcribedText,
    this.wordErrorRate,
    this.expectedFunction,
    this.expectedParams,
    this.actualFunction,
    this.actualParams,
    this.rawResponse,
    required this.latencyMs,
    this.ttftMs,
    this.ramUsageMB,
    required this.success,
    required this.jsonValid,
    required this.semanticCorrect,
    required this.tier,
    this.error,
    required this.category,
  });

  /// Create from ModelResponse and additional context
  factory InferenceLog.fromResponse({
    required ModelResponse response,
    required ModelSpec modelSpec,
    required String commandText,
    required String category,
    required String tier,
    String? transcribedText,
    double? wordErrorRate,
    String? expectedFunction,
    Map<String, dynamic>? expectedParams,
  }) {
    // Extract actual function from tool calls
    String? actualFunction;
    Map<String, dynamic>? actualParams;
    
    if (response.toolCalls != null && response.toolCalls!.isNotEmpty) {
      final firstCall = response.toolCalls!.first;
      actualFunction = firstCall.name;
      actualParams = firstCall.arguments;
    }

    // Check semantic correctness
    final semanticCorrect = expectedFunction != null && 
                           actualFunction != null &&
                           actualFunction == expectedFunction;

    return InferenceLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      modelId: modelSpec.id,
      modelFormat: modelSpec.format.name,
      modelDisplayName: modelSpec.displayName,
      commandText: commandText,
      transcribedText: transcribedText,
      wordErrorRate: wordErrorRate,
      expectedFunction: expectedFunction,
      expectedParams: expectedParams,
      actualFunction: actualFunction,
      actualParams: actualParams,
      rawResponse: response.text,
      latencyMs: response.latencyMs,
      ttftMs: response.ttftMs,
      ramUsageMB: response.ramUsageMB,
      success: response.success,
      jsonValid: response.jsonValid,
      semanticCorrect: semanticCorrect,
      tier: tier,
      error: response.error,
      category: category,
    );
  }

  /// Create from Cactus-specific result (for direct logging)
  factory InferenceLog.fromCactusResult({
    required dynamic cactusResult, // CactusCompletionResult
    required ModelSpec modelSpec,
    required String commandText,
    required String category,
    required String tier,
    required int latencyMs,
    String? transcribedText,
  }) {
    // Extract tool calls from Cactus result
    String? actualFunction;
    Map<String, dynamic>? actualParams;
    bool success = false;
    
    try {
      if (cactusResult.success && cactusResult.toolCalls != null && cactusResult.toolCalls.isNotEmpty) {
        final firstCall = cactusResult.toolCalls.first;
        actualFunction = firstCall.name;
        actualParams = firstCall.arguments;
        success = true;
      }
    } catch (e) {
      // Handle any extraction errors
    }

    return InferenceLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      modelId: modelSpec.id,
      modelFormat: modelSpec.format.name,
      modelDisplayName: modelSpec.displayName,
      commandText: commandText,
      transcribedText: transcribedText,
      wordErrorRate: null,
      expectedFunction: null,
      expectedParams: null,
      actualFunction: actualFunction,
      actualParams: actualParams,
      rawResponse: cactusResult.text ?? '',
      latencyMs: latencyMs,
      ttftMs: null,
      ramUsageMB: null,
      success: success,
      jsonValid: success,
      semanticCorrect: success,
      tier: tier,
      error: success ? null : 'Failed to generate tool calls',
      category: category,
    );
  }


  /// Convert to JSON for export
  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'model_id': modelId,
    'model_format': modelFormat,
    'model_display_name': modelDisplayName,
    'command_text': commandText,
    'transcribed_text': transcribedText,
    'word_error_rate': wordErrorRate,
    'expected_function': expectedFunction,
    'expected_params': expectedParams,
    'actual_function': actualFunction,
    'actual_params': actualParams,
    'raw_response': rawResponse,
    'latency_ms': latencyMs,
    'ttft_ms': ttftMs,
    'ram_usage_mb': ramUsageMB,
    'success': success,
    'json_valid': jsonValid,
    'semantic_correct': semanticCorrect,
    'tier': tier,
    'error': error,
    'category': category,
  };

  /// Convert to CSV row
  String toCsvRow() {
    return [
      id,
      timestamp.toIso8601String(),
      modelId,
      modelFormat,
      modelDisplayName,
      _escapeCsv(commandText),
      _escapeCsv(transcribedText ?? ''),
      wordErrorRate?.toStringAsFixed(3) ?? '',
      expectedFunction ?? '',
      _escapeCsv(expectedParams?.toString() ?? ''),
      actualFunction ?? '',
      _escapeCsv(actualParams?.toString() ?? ''),
      _escapeCsv(rawResponse ?? ''),
      latencyMs.toString(),
      ttftMs?.toString() ?? '',
      ramUsageMB?.toStringAsFixed(1) ?? '',
      success.toString(),
      jsonValid.toString(),
      semanticCorrect.toString(),
      tier,
      _escapeCsv(error ?? ''),
      category,
    ].join(',');
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// CSV header
  static String csvHeader() {
    return [
      'id',
      'timestamp',
      'model_id',
      'model_format',
      'model_display_name',
      'command_text',
      'transcribed_text',
      'word_error_rate',
      'expected_function',
      'expected_params',
      'actual_function',
      'actual_params',
      'raw_response',
      'latency_ms',
      'ttft_ms',
      'ram_usage_mb',
      'success',
      'json_valid',
      'semantic_correct',
      'tier',
      'error',
      'category',
    ].join(',');
  }
}

/// Research logger service
class ResearchLogger {
  final List<InferenceLog> _logs = [];
  bool _enabled = false;

  /// Enable/disable logging
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  bool get isEnabled => _enabled;

  /// Log an inference
  void logInference(InferenceLog log) {
    if (_enabled) {
      _logs.add(log);
      print('[ResearchLog] ${log.modelDisplayName}: ${log.commandText} → '
            '${log.success ? "✓" : "✗"} (${log.latencyMs}ms)');
    }
  }

  /// Get all logs
  List<InferenceLog> get logs => List.unmodifiable(_logs);

  /// Get logs count
  int get count => _logs.length;

  /// Clear all logs
  void clear() {
    _logs.clear();
  }

  /// Get summary statistics
  Map<String, dynamic> getSummary() {
    if (_logs.isEmpty) {
      return {
        'total': 0,
        'success_rate': 0.0,
        'avg_latency_ms': 0.0,
        'semantic_accuracy': 0.0,
      };
    }

    final successful = _logs.where((l) => l.success).length;
    final semanticCorrect = _logs.where((l) => l.semanticCorrect).length;
    final avgLatency = _logs.map((l) => l.latencyMs).reduce((a, b) => a + b) / _logs.length;

    return {
      'total': _logs.length,
      'success_rate': successful / _logs.length,
      'avg_latency_ms': avgLatency,
      'semantic_accuracy': semanticCorrect / _logs.length,
      'by_model': _getModelBreakdown(),
      'by_category': _getCategoryBreakdown(),
      'by_tier': _getTierBreakdown(),
    };
  }

  Map<String, dynamic> _getModelBreakdown() {
    final byModel = <String, List<InferenceLog>>{};
    for (final log in _logs) {
      byModel.putIfAbsent(log.modelDisplayName, () => []).add(log);
    }

    return byModel.map((model, logs) {
      final successful = logs.where((l) => l.success).length;
      final avgLatency = logs.map((l) => l.latencyMs).reduce((a, b) => a + b) / logs.length;
      return MapEntry(model, {
        'count': logs.length,
        'success_rate': successful / logs.length,
        'avg_latency_ms': avgLatency,
      });
    });
  }

  Map<String, dynamic> _getCategoryBreakdown() {
    final byCategory = <String, List<InferenceLog>>{};
    for (final log in _logs) {
      byCategory.putIfAbsent(log.category, () => []).add(log);
    }

    return byCategory.map((category, logs) {
      final successful = logs.where((l) => l.success).length;
      return MapEntry(category, {
        'count': logs.length,
        'success_rate': successful / logs.length,
      });
    });
  }

  Map<String, dynamic> _getTierBreakdown() {
    final byTier = <String, List<InferenceLog>>{};
    for (final log in _logs) {
      byTier.putIfAbsent(log.tier, () => []).add(log);
    }

    return byTier.map((tier, logs) {
      final successful = logs.where((l) => l.success).length;
      return MapEntry(tier, {
        'count': logs.length,
        'success_rate': successful / logs.length,
      });
    });
  }

  /// Export to CSV string
  String exportToCsv() {
    if (_logs.isEmpty) return InferenceLog.csvHeader();
    
    final buffer = StringBuffer();
    buffer.writeln(InferenceLog.csvHeader());
    for (final log in _logs) {
      buffer.writeln(log.toCsvRow());
    }
    return buffer.toString();
  }

  /// Export to JSON string
  String exportToJson() {
    return '[\n${_logs.map((l) => '  ${l.toJson()}').join(',\n')}\n]';
  }
}

/// Global research logger instance
final researchLogger = ResearchLogger();
