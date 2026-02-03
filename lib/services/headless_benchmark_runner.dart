/// Headless Benchmark Runner - Crash-resistant with incremental saving
/// Runs 120 commands (30 per model) with proper memory management
/// Saves results after each command to prevent data loss on crash
///
/// Usage: dart run lib/services/headless_benchmark_runner.dart
/// Or from Flutter: HeadlessBenchmarkRunner.run()

import 'dart:convert';
import 'dart:io';
import 'package:cactus/cactus.dart';
import 'benchmark_service.dart';

class HeadlessBenchmarkRunner {
  /// Incremental results file - appended after each test
  static const String resultsFile = 'results/headless_benchmark_results.csv';
  static const String jsonResultsFile = 'results/headless_benchmark_results.json';
  static const String progressFile = 'results/benchmark_progress.json';
  
  /// Memory management: Aggressive cleanup intervals
  static const int cleanupInterval = 5; // Cleanup every 5 commands
  static const int delayBetweenCommandsMs = 500; // Cool down period
  
  /// Available models for benchmarking
  static final List<Map<String, dynamic>> availableModels = [
    {'id': 'qwen3-0.6b', 'name': 'Qwen 3 0.6B', 'type': 'specialist'},
    {'id': 'qwen3-1.7b', 'name': 'Qwen 3 1.7B', 'type': 'generalist'},
    {'id': 'gemma-3-2b', 'name': 'Gemma 3 2B', 'type': 'generalist'},
    {'id': 'function-gemma-270m', 'name': 'Function-Gemma 270M', 'type': 'specialist'},
    {'id': 'function-gemma-270m-pro', 'name': 'Function-Gemma 270M Pro', 'type': 'specialist'},
    {'id': 'liquid-lfm-2-350m', 'name': 'Liquid LFM-2 350M', 'type': 'liquid'},
    {'id': 'liquid-lfm-2-700m', 'name': 'Liquid LFM-2 700M', 'type': 'liquid'},
    {'id': 'liquid-lfm-2-1.2b', 'name': 'Liquid LFM-2 1.2B', 'type': 'liquid'},
    {'id': 'liquid-lfm-2-1.2b-tool', 'name': 'Liquid LFM-2 1.2B Tool', 'type': 'liquid'},
    {'id': 'smollm-1.7b', 'name': 'SmolLM 1.7B', 'type': 'generalist'},
    {'id': 'llama-3.2-3b', 'name': 'Llama 3.2 3B', 'type': 'generalist'},
    {'id': 'phi-3.5-mini', 'name': 'Phi 3.5 Mini 3.8B', 'type': 'generalist'},
  ];

  /// Tool definitions for function calling
  static List<CactusTool> buildTools() {
    return [
      CactusTool(
        name: 'setDoNotDisturb',
        description: 'Enables Do Not Disturb mode for a specified duration.',
        parameters: ToolParametersSchema(
          properties: {
            'durationMinutes': ToolParameter(
              type: 'integer',
              description: 'Duration in minutes.',
              required: true,
            ),
          },
        ),
      ),
      CactusTool(
        name: 'toggleFlashlight',
        description: 'Controls device flashlight.',
        parameters: ToolParametersSchema(
          properties: {
            'enable': ToolParameter(
              type: 'boolean',
              description: 'True to turn on, false to turn off.',
              required: true,
            ),
          },
        ),
      ),
      CactusTool(
        name: 'setVolume',
        description: 'Adjusts device volume.',
        parameters: ToolParametersSchema(
          properties: {
            'volumePercent': ToolParameter(
              type: 'integer',
              description: 'Volume from 0-100.',
              required: true,
            ),
          },
        ),
      ),
      CactusTool(
        name: 'setScreenBrightness',
        description: 'Adjusts screen brightness.',
        parameters: ToolParametersSchema(
          properties: {
            'brightnessPercent': ToolParameter(
              type: 'integer',
              description: 'Brightness from 0-100.',
              required: true,
            ),
          },
        ),
      ),
      CactusTool(
        name: 'toggleWifi',
        description: 'Enables or disables Wi-Fi.',
        parameters: ToolParametersSchema(
          properties: {
            'enable': ToolParameter(
              type: 'boolean',
              description: 'True to enable, false to disable.',
              required: true,
            ),
          },
        ),
      ),
      CactusTool(
        name: 'createRule',
        description: 'Creates automation rules.',
        parameters: ToolParametersSchema(
          properties: {
            'trigger': ToolParameter(
              type: 'string',
              description: 'Context trigger.',
              required: true,
            ),
            'action': ToolParameter(
              type: 'string',
              description: 'Action to perform.',
              required: true,
            ),
          },
        ),
      ),
    ];
  }

  /// Adaptive system prompts based on model type
  static String getSystemPrompt(String modelType) {
    switch (modelType) {
      case 'specialist':
        // Minimal prompt for Function-Gemma (200 chars)
        return 'Function calling assistant. Parse command, call function with parameters. '
            'Examples: "silence 2h"→setDoNotDisturb(120), "torch on"→toggleFlashlight(true)';
      
      case 'liquid':
        // Temporal-focused prompt for Liquid models (400 chars)
        return 'Temporal reasoning assistant with function calling.\n'
            'Extract: action + parameters + temporal context.\n'
            'Examples:\n'
            '- "silence next hour" → setDoNotDisturb(60)\n'
            '- "brightness for reading" → setScreenBrightness(70)\n'
            '- "mute when in class" → createRule(trigger="in class", action="mute")\n'
            'Always call a function. Handle time expressions.';
      
      case 'generalist':
      default:
        // Full reasoning prompt for large models (1200 chars)
        return 'You are an intelligent device control assistant with function calling capabilities.\n\n'
            '## Reasoning Process:\n'
            '1. Parse user intent: What action?\n'
            '2. Identify synonyms: silence=mute=quiet=dnd, torch=flashlight\n'
            '3. Extract parameters: numbers, time durations\n'
            '4. Handle temporal: "next hour"=60min, "2 hours"=120min\n'
            '5. Map context: "sleeping"→low volume/brightness\n'
            '6. Choose function and validate parameters\n\n'
            '## Examples:\n'
            '- "Turn on flashlight" → toggleFlashlight(enable=true)\n'
            '- "Quiet for 2 hours" → setDoNotDisturb(durationMinutes=120)\n'
            '- "Volume 75 percent" → setVolume(volumePercent=75)\n'
            '- "Brightness for reading" → setScreenBrightness(brightnessPercent=70)\n'
            '- "Enable wifi" → toggleWifi(enable=true)\n'
            '- "Mute in class" → createRule(trigger="in class", action="mute")\n\n'
            '## Rules:\n'
            '- ALWAYS call a function\n'
            '- Extract exact numeric values\n'
            '- Use reasonable defaults\n'
            '- Handle ASR errors gracefully';
    }
  }

  /// Load progress from previous run (if crashed)
  static Future<Map<String, dynamic>> loadProgress() async {
    final file = File(progressFile);
    if (await file.exists()) {
      final content = await file.readAsString();
      return jsonDecode(content);
    }
    return {'completed': <String>[], 'lastModel': null, 'lastCommandIndex': -1};
  }

  /// Save progress after each command
  static Future<void> saveProgress(Map<String, dynamic> progress) async {
    final file = File(progressFile);
    await file.writeAsString(jsonEncode(progress));
  }

  /// Save single result incrementally (append to CSV)
  static Future<void> saveResultIncremental(BenchmarkResult result) async {
    final file = File(resultsFile);
    final exists = await file.exists();
    
    final sink = file.openWrite(mode: FileMode.append);
    
    // Write header if new file
    if (!exists) {
      sink.writeln(BenchmarkResult.csvHeader());
    }
    
    sink.writeln(result.toCsvRow());
    await sink.close();
    
    // Also append to JSON array (more complex, but useful)
    await _appendToJsonResults(result);
  }

  /// Append result to JSON file
  static Future<void> _appendToJsonResults(BenchmarkResult result) async {
    final file = File(jsonResultsFile);
    List<dynamic> results = [];
    
    if (await file.exists()) {
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        results = jsonDecode(content);
      }
    }
    
    results.add(result.toJson());
    await file.writeAsString(jsonEncode(results));
  }

  /// Main benchmark execution
  static Future<void> run({
    List<String>? modelIds,
    int? commandsPerModel,
    Function(String)? onProgress,
  }) async {
    final models = modelIds ?? availableModels.map((m) => m['id'] as String).toList();
    final commandLimit = commandsPerModel ?? 30; // Default 30 commands per model
    
    void log(String message) {
      print('[${DateTime.now().toIso8601String()}] $message');
      onProgress?.call(message);
    }

    log('=== Headless Benchmark Runner ===');
    log('Models: ${models.join(", ")}');
    log('Commands per model: $commandLimit');
    log('Memory management: Cleanup every $cleanupInterval commands');
    
    // Load dataset
    log('Loading test dataset...');
    final testCases = await BenchmarkService.loadTestCases();
    log('Loaded ${testCases.length} test cases');
    
    // Limit to 30 commands per model
    final limitedTestCases = testCases.take(commandLimit).toList();
    log('Using first $commandLimit commands per model');
    
    // Load progress from previous run
    final progress = await loadProgress();
    final completedTests = (progress['completed'] as List).cast<String>();
    log('Resuming from checkpoint: ${completedTests.length} tests already completed');
    
    final tools = buildTools();
    int totalTests = 0;
    int successfulTests = 0;
    
    // Run benchmark for each model
    for (final modelId in models) {
      final modelInfo = availableModels.firstWhere((m) => m['id'] == modelId);
      final modelName = modelInfo['name'] as String;
      final modelType = modelInfo['type'] as String;
      
      log('');
      log('╔════════════════════════════════════════════════════════════╗');
      log('║ Starting: $modelName ($modelType)');
      log('╚════════════════════════════════════════════════════════════╝');
      
      CactusLM? lm;
      
      try {
        // Initialize model
        log('Initializing $modelName...');
        lm = CactusLM();
        
        await lm.downloadModel(
          model: modelId,
          downloadProcessCallback: (progress, statusMsg, isError) {
            if (!isError && progress != null && progress % 0.1 < 0.01) {
              log('  Downloading: ${(progress * 100).toStringAsFixed(0)}%');
            }
          },
        );
        
        await lm.initializeModel();
        log('✓ Model loaded successfully');
        
        // Get adaptive prompt
        final systemPrompt = getSystemPrompt(modelType);
        log('Using ${systemPrompt.length}-char prompt for $modelType type');
        
        // Run tests
        for (int i = 0; i < limitedTestCases.length; i++) {
          final testCase = limitedTestCases[i];
          final testId = '${modelId}_${i}';
          
          // Skip if already completed
          if (completedTests.contains(testId)) {
            log('  Skipping test ${i + 1}/$commandLimit (already completed)');
            continue;
          }
          
          log('  Test ${i + 1}/$commandLimit: "${testCase.command}"');
          
          final startTime = DateTime.now();
          BenchmarkResult? result;
          
          try {
            // Run inference with timeout
            final response = await lm.infer(
              systemPrompt: systemPrompt,
              userMessage: testCase.transcription,
              params: CactusCompletionParams(
                tools: tools,
                maxTokens: 100,
                temperature: 0.1,
              ),
            ).timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException('Inference timeout'),
            );
            
            final latency = DateTime.now().difference(startTime).inMilliseconds;
            
            // Parse result
            if (!response.success || response.toolCalls.isEmpty) {
              result = BenchmarkResult(
                modelName: modelName,
                command: testCase.command,
                transcribedText: testCase.transcription,
                category: testCase.category,
                expectedFunction: testCase.expectedFunction,
                expectedParams: testCase.expectedParameters,
                success: false,
                correctFunction: false,
                correctParams: false,
                latencyMs: latency,
                error: response.error ?? 'No tool calls generated',
                wordErrorRate: testCase.wordErrorRate,
              );
            } else {
              final toolCall = response.toolCalls.first;
              final correctFunction = toolCall.name == testCase.expectedFunction;
              final correctParams = _compareParams(
                toolCall.arguments,
                testCase.expectedParameters,
              );
              
              result = BenchmarkResult(
                modelName: modelName,
                command: testCase.command,
                transcribedText: testCase.transcription,
                category: testCase.category,
                expectedFunction: testCase.expectedFunction,
                expectedParams: testCase.expectedParameters,
                actualFunction: toolCall.name,
                actualParams: toolCall.arguments,
                success: correctFunction && correctParams,
                correctFunction: correctFunction,
                correctParams: correctParams,
                latencyMs: latency,
                wordErrorRate: testCase.wordErrorRate,
              );
              
              if (result.success) successfulTests++;
            }
          } catch (e) {
            final latency = DateTime.now().difference(startTime).inMilliseconds;
            log('    ❌ Error: $e');
            
            result = BenchmarkResult(
              modelName: modelName,
              command: testCase.command,
              transcribedText: testCase.transcription,
              category: testCase.category,
              expectedFunction: testCase.expectedFunction,
              expectedParams: testCase.expectedParameters,
              success: false,
              correctFunction: false,
              correctParams: false,
              latencyMs: latency,
              error: e.toString(),
              wordErrorRate: testCase.wordErrorRate,
            );
          }
          
          // Save result immediately (crash-resistant)
          await saveResultIncremental(result);
          totalTests++;
          
          // Update progress
          completedTests.add(testId);
          await saveProgress({
            'completed': completedTests,
            'lastModel': modelId,
            'lastCommandIndex': i,
            'timestamp': DateTime.now().toIso8601String(),
          });
          
          log('    ${result.success ? "✓" : "✗"} ${result.actualFunction ?? "none"} | ${result.latencyMs}ms');
          
          // Memory management: Periodic cleanup
          if ((i + 1) % cleanupInterval == 0) {
            log('    🧹 Memory cleanup checkpoint (${i + 1}/$commandLimit)');
            await Future.delayed(Duration(milliseconds: delayBetweenCommandsMs * 2));
          } else {
            await Future.delayed(Duration(milliseconds: delayBetweenCommandsMs));
          }
        }
        
        log('✓ Completed $modelName: ${limitedTestCases.length} tests');
        
      } catch (e) {
        log('❌ Fatal error with $modelName: $e');
      } finally {
        // CRITICAL: Proper cleanup to prevent memory leaks
        if (lm != null) {
          log('Unloading $modelName...');
          try {
            await lm.unload();
            log('✓ Model unloaded');
          } catch (e) {
            log('⚠ Unload error: $e');
          }
        }
        lm = null;
        
        // Force garbage collection hint
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    
    log('');
    log('╔════════════════════════════════════════════════════════════╗');
    log('║ BENCHMARK COMPLETE');
    log('╠════════════════════════════════════════════════════════════╣');
    log('║ Total tests: $totalTests');
    log('║ Successful: $successfulTests (${(successfulTests / totalTests * 100).toStringAsFixed(1)}%)');
    log('║ Results: $resultsFile');
    log('║ Progress: $progressFile');
    log('╚════════════════════════════════════════════════════════════╝');
    
    // Generate final summary
    await _generateFinalSummary();
  }

  /// Compare parameters with tolerance
  static bool _compareParams(
    Map<String, dynamic> actual,
    Map<String, dynamic> expected,
  ) {
    for (final key in expected.keys) {
      if (!actual.containsKey(key)) return false;
      
      final expectedVal = expected[key];
      final actualVal = actual[key];
      
      if (expectedVal is num && actualVal is num) {
        final diff = (expectedVal - actualVal).abs();
        final tolerance = expectedVal * 0.1;
        if (diff > tolerance && diff > 5) return false;
      } else if (expectedVal is String && actualVal is String) {
        if (expectedVal.toLowerCase() != actualVal.toLowerCase()) return false;
      } else {
        if (expectedVal != actualVal) return false;
      }
    }
    
    return true;
  }

  /// Generate final summary report
  static Future<void> _generateFinalSummary() async {
    final resultsFile = File(jsonResultsFile);
    if (!await resultsFile.exists()) return;
    
    final content = await resultsFile.readAsString();
    final List<dynamic> rawResults = jsonDecode(content);
    final results = rawResults.map((r) => BenchmarkResult(
      modelName: r['model'],
      command: r['command'],
      transcribedText: r['transcribed_text'],
      category: r['category'],
      expectedFunction: r['expected_function'],
      expectedParams: jsonDecode(r['expected_params']),
      actualFunction: r['actual_function'].isEmpty ? null : r['actual_function'],
      actualParams: r['actual_params'].isEmpty ? null : jsonDecode(r['actual_params']),
      success: r['success'],
      correctFunction: r['correct_function'],
      correctParams: r['correct_params'],
      latencyMs: r['latency_ms'],
      error: r['error'].isEmpty ? null : r['error'],
      wordErrorRate: r['word_error_rate'],
    )).toList();
    
    final summary = StringBuffer();
    summary.writeln('# Headless Benchmark Summary');
    summary.writeln('Generated: ${DateTime.now()}');
    summary.writeln('Total Tests: ${results.length}\n');
    
    // Group by model
    final byModel = <String, List<BenchmarkResult>>{};
    for (final result in results) {
      byModel.putIfAbsent(result.modelName, () => []).add(result);
    }
    
    summary.writeln('## Model Performance\n');
    summary.writeln('| Model | Tests | Success Rate | Function Acc | Param Acc | Avg Latency |');
    summary.writeln('|-------|-------|--------------|--------------|-----------|-------------|');
    
    for (final entry in byModel.entries) {
      final modelResults = entry.value;
      final success = modelResults.where((r) => r.success).length;
      final correctFn = modelResults.where((r) => r.correctFunction).length;
      final correctParam = modelResults.where((r) => r.correctParams).length;
      final avgLatency = modelResults.map((r) => r.latencyMs).reduce((a, b) => a + b) / modelResults.length;
      
      summary.writeln(
        '| ${entry.key} | ${modelResults.length} | '
        '${(success / modelResults.length * 100).toStringAsFixed(1)}% | '
        '${(correctFn / modelResults.length * 100).toStringAsFixed(1)}% | '
        '${(correctParam / modelResults.length * 100).toStringAsFixed(1)}% | '
        '${avgLatency.toStringAsFixed(0)}ms |'
      );
    }
    
    final summaryFile = File('results/headless_benchmark_summary.md');
    await summaryFile.writeAsString(summary.toString());
    print('\n✓ Summary saved: ${summaryFile.path}');
  }
}

/// Standalone CLI entry point
void main(List<String> args) async {
  // Parse CLI arguments
  List<String>? models;
  int? commandsPerModel;
  
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--models' && i + 1 < args.length) {
      models = args[i + 1].split(',');
    } else if (args[i] == '--commands' && i + 1 < args.length) {
      commandsPerModel = int.tryParse(args[i + 1]);
    }
  }
  
  await HeadlessBenchmarkRunner.run(
    modelIds: models,
    commandsPerModel: commandsPerModel,
  );
  
  exit(0);
}
