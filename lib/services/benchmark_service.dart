/// Automated benchmark service for testing multiple models across dataset
/// Runs all 120 commands from realistic dataset across all available models
/// Exports results to CSV for analysis and chart generation

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cactus/cactus.dart';
import '../models/cactus_provider.dart';
import '../models/model_provider.dart';

class BenchmarkResult {
  final String modelName;
  final String command;
  final String transcribedText;
  final String category;
  final String expectedFunction;
  final Map<String, dynamic> expectedParams;
  final String? actualFunction;
  final Map<String, dynamic>? actualParams;
  final bool success;
  final bool correctFunction;
  final bool correctParams;
  final int latencyMs;
  final String? error;
  final double wordErrorRate;

  BenchmarkResult({
    required this.modelName,
    required this.command,
    required this.transcribedText,
    required this.category,
    required this.expectedFunction,
    required this.expectedParams,
    this.actualFunction,
    this.actualParams,
    required this.success,
    required this.correctFunction,
    required this.correctParams,
    required this.latencyMs,
    this.error,
    required this.wordErrorRate,
  });

  Map<String, dynamic> toJson() => {
    'model': modelName,
    'command': command,
    'transcribed_text': transcribedText,
    'category': category,
    'expected_function': expectedFunction,
    'expected_params': jsonEncode(expectedParams),
    'actual_function': actualFunction ?? '',
    'actual_params': jsonEncode(actualParams ?? {}),
    'success': success,
    'correct_function': correctFunction,
    'correct_params': correctParams,
    'latency_ms': latencyMs,
    'error': error ?? '',
    'word_error_rate': wordErrorRate,
  };

  String toCsvRow() {
    return [
      modelName,
      _escapeCsv(command),
      _escapeCsv(transcribedText),
      category,
      expectedFunction,
      _escapeCsv(jsonEncode(expectedParams)),
      actualFunction ?? '',
      _escapeCsv(jsonEncode(actualParams ?? {})),
      success ? '1' : '0',
      correctFunction ? '1' : '0',
      correctParams ? '1' : '0',
      latencyMs.toString(),
      _escapeCsv(error ?? ''),
      wordErrorRate.toStringAsFixed(3),
    ].join(',');
  }

  static String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String csvHeader() {
    return 'model,command,transcribed_text,category,expected_function,'
        'expected_params,actual_function,actual_params,success,'
        'correct_function,correct_params,latency_ms,error,word_error_rate';
  }
}

/// Simplified test case structure for headless runner
class TestCase {
  final String participant;
  final String command;
  final String transcription;
  final String category;
  final double wordErrorRate;
  final String expectedFunction;
  final Map<String, dynamic> expectedParameters;

  TestCase({
    required this.participant,
    required this.command,
    required this.transcription,
    required this.category,
    required this.wordErrorRate,
    required this.expectedFunction,
    required this.expectedParameters,
  });

  factory TestCase.fromJson(Map<String, dynamic> json) {
    return TestCase(
      participant: json['participant_id'].toString(),
      command: json['original_command'] as String,
      transcription: json['transcribed_text'] as String,
      category: json['category'] as String,
      wordErrorRate: (json['word_error_rate'] as num).toDouble(),
      expectedFunction: json['expected_function'] as String,
      expectedParameters:
          jsonDecode(json['expected_params'] as String) as Map<String, dynamic>,
    );
  }
}

class BenchmarkService {
  final List<CactusTool> tools;
  final String systemPrompt;

  BenchmarkService({required this.tools, required this.systemPrompt});

  /// Load test cases as TestCase objects (for headless runner)
  static Future<List<TestCase>> loadTestCases() async {
    try {
      // Try loading from app assets first (for deployed APK)
      final content = await rootBundle.loadString(
        'assets/realistic_dataset.json',
      );
      final List<dynamic> data = jsonDecode(content);
      return data
          .map((item) => TestCase.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Fallback to file system (for development)
      final file = File('assets/realistic_dataset.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> data = jsonDecode(content);
        return data
            .map((item) => TestCase.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      // Try results folder as final fallback
      final resultsFile = File('results/realistic_dataset.json');
      if (await resultsFile.exists()) {
        final content = await resultsFile.readAsString();
        final List<dynamic> data = jsonDecode(content);
        return data
            .map((item) => TestCase.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Dataset not found in assets or file system');
    }
  }

  /// Load commands from realistic dataset (embedded in app assets)
  Future<List<Map<String, dynamic>>> loadDataset() async {
    try {
      // Try loading from app assets first (for deployed APK)
      final content = await rootBundle.loadString(
        'assets/realistic_dataset.json',
      );
      final List<dynamic> data = jsonDecode(content);
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      // Fallback to file system (for development)
      final file = File('results/realistic_dataset.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> data = jsonDecode(content);
        return data.cast<Map<String, dynamic>>();
      }
      throw Exception('Dataset not found in assets or file system');
    }
  }

  /// Run benchmark for a single model
  Future<List<BenchmarkResult>> benchmarkModel({
    required String modelId,
    required Function(String) onProgress,
  }) async {
    onProgress('Loading dataset...');
    final dataset = await loadDataset();

    onProgress('Initializing model: $modelId');
    final provider = CactusProvider.fromId(modelId);

    await provider.downloadModel(
      downloadCallback: (progress, msg, isError) {
        if (!isError) {
          onProgress('Downloading $modelId: ${(progress ?? 0) * 100}%');
        }
      },
    );

    await provider.initializeModel();
    onProgress('Model $modelId ready');

    final results = <BenchmarkResult>[];

    for (int i = 0; i < dataset.length; i++) {
      final item = dataset[i];
      onProgress('Testing $modelId: ${i + 1}/${dataset.length}');

      final result = await _testCommand(
        provider: provider,
        command: item['original_command'] as String,
        transcribedText: item['transcribed_text'] as String,
        category: item['category'] as String,
        expectedFunction: item['expected_function'] as String,
        expectedParams: jsonDecode(item['expected_params'] as String),
        wordErrorRate: item['word_error_rate'] as double,
      );

      results.add(result);

      // Small delay to prevent overheating
      await Future.delayed(const Duration(milliseconds: 100));
    }

    await provider.dispose();
    onProgress('Completed $modelId: ${results.length} tests');

    return results;
  }

  /// Test a single command
  Future<BenchmarkResult> _testCommand({
    required ModelProvider provider,
    required String command,
    required String transcribedText,
    required String category,
    required String expectedFunction,
    required Map<String, dynamic> expectedParams,
    required double wordErrorRate,
  }) async {
    final startTime = DateTime.now();

    try {
      final response = await provider.infer(
        systemPrompt: systemPrompt,
        userMessage: transcribedText,
        tools: tools,
        maxTokens: 50, // Aggressive optimization for function calling
        temperature: 0.1,
      );

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      if (!response.success ||
          response.toolCalls == null ||
          response.toolCalls!.isEmpty) {
        return BenchmarkResult(
          modelName: provider.modelName,
          command: command,
          transcribedText: transcribedText,
          category: category,
          expectedFunction: expectedFunction,
          expectedParams: expectedParams,
          success: false,
          correctFunction: false,
          correctParams: false,
          latencyMs: latency,
          error: response.error ?? 'No tool calls generated',
          wordErrorRate: wordErrorRate,
        );
      }

      final toolCall = response.toolCalls!.first;
      final correctFunction = toolCall.name == expectedFunction;
      final correctParams = _compareParams(
        toolCall.arguments,
        expectedParams,
        expectedFunction,
      );

      return BenchmarkResult(
        modelName: provider.modelName,
        command: command,
        transcribedText: transcribedText,
        category: category,
        expectedFunction: expectedFunction,
        expectedParams: expectedParams,
        actualFunction: toolCall.name,
        actualParams: toolCall.arguments,
        success: correctFunction && correctParams,
        correctFunction: correctFunction,
        correctParams: correctParams,
        latencyMs: latency,
        wordErrorRate: wordErrorRate,
      );
    } catch (e) {
      final latency = DateTime.now().difference(startTime).inMilliseconds;
      return BenchmarkResult(
        modelName: provider.modelName,
        command: command,
        transcribedText: transcribedText,
        category: category,
        expectedFunction: expectedFunction,
        expectedParams: expectedParams,
        success: false,
        correctFunction: false,
        correctParams: false,
        latencyMs: latency,
        error: e.toString(),
        wordErrorRate: wordErrorRate,
      );
    }
  }

  /// Compare parameters with tolerance for reasonable variations
  bool _compareParams(
    Map<String, dynamic> actual,
    Map<String, dynamic> expected,
    String functionName,
  ) {
    // Check all expected keys are present
    for (final key in expected.keys) {
      if (!actual.containsKey(key)) return false;

      final expectedVal = expected[key];
      final actualVal = actual[key];

      // Handle numeric parameters with tolerance
      if (expectedVal is num && actualVal is num) {
        // Allow ±10% tolerance for numeric values
        final diff = (expectedVal - actualVal).abs();
        final tolerance = expectedVal * 0.1;
        if (diff > tolerance && diff > 5)
          return false; // 10% or 5 units tolerance
      } else if (expectedVal is bool && actualVal is bool) {
        if (expectedVal != actualVal) return false;
      } else if (expectedVal is String && actualVal is String) {
        // Case insensitive string comparison
        if (expectedVal.toLowerCase() != actualVal.toLowerCase()) return false;
      } else {
        // Exact match for other types
        if (expectedVal != actualVal) return false;
      }
    }

    return true;
  }

  /// Run benchmark across all models
  Future<void> runFullBenchmark({
    required List<String> modelIds,
    required Function(String) onProgress,
  }) async {
    final allResults = <BenchmarkResult>[];

    for (final modelId in modelIds) {
      try {
        final results = await benchmarkModel(
          modelId: modelId,
          onProgress: onProgress,
        );
        allResults.addAll(results);
      } catch (e) {
        onProgress('Error benchmarking $modelId: $e');
      }
    }

    await saveResults(allResults);
    onProgress(
      'Benchmark complete! Results saved to results/benchmark_results.csv',
    );
  }

  /// Save results to CSV file
  Future<void> saveResults(List<BenchmarkResult> results) async {
    final file = File('results/benchmark_results.csv');
    final sink = file.openWrite();

    sink.writeln(BenchmarkResult.csvHeader());
    for (final result in results) {
      sink.writeln(result.toCsvRow());
    }

    await sink.close();

    // Also save as JSON
    final jsonFile = File('results/benchmark_results.json');
    await jsonFile.writeAsString(
      jsonEncode(results.map((r) => r.toJson()).toList()),
    );

    // Generate summary
    await _generateSummary(results);
  }

  /// Generate benchmark summary statistics
  Future<void> _generateSummary(List<BenchmarkResult> results) async {
    final summary = StringBuffer();
    summary.writeln('# Benchmark Summary\n');
    summary.writeln('Generated: ${DateTime.now()}\n');
    summary.writeln('Total Tests: ${results.length}\n');

    // Group by model
    final byModel = <String, List<BenchmarkResult>>{};
    for (final result in results) {
      byModel.putIfAbsent(result.modelName, () => []).add(result);
    }

    summary.writeln('## Model Comparison\n');
    summary.writeln(
      '| Model | Tests | Success | Correct Fn | Correct Params | Avg Latency |',
    );
    summary.writeln(
      '|-------|-------|---------|------------|----------------|-------------|',
    );

    for (final entry in byModel.entries) {
      final modelResults = entry.value;
      final successCount = modelResults.where((r) => r.success).length;
      final correctFnCount = modelResults
          .where((r) => r.correctFunction)
          .length;
      final correctParamCount = modelResults
          .where((r) => r.correctParams)
          .length;
      final avgLatency =
          modelResults.map((r) => r.latencyMs).reduce((a, b) => a + b) /
          modelResults.length;

      summary.writeln(
        '| ${entry.key} | ${modelResults.length} | '
        '${successCount} (${(successCount / modelResults.length * 100).toStringAsFixed(1)}%) | '
        '${correctFnCount} (${(correctFnCount / modelResults.length * 100).toStringAsFixed(1)}%) | '
        '${correctParamCount} (${(correctParamCount / modelResults.length * 100).toStringAsFixed(1)}%) | '
        '${avgLatency.toStringAsFixed(0)}ms |',
      );
    }

    final summaryFile = File('results/benchmark_summary.md');
    await summaryFile.writeAsString(summary.toString());
  }
}
