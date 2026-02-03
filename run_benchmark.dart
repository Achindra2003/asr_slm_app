#!/usr/bin/env dart
/// Headless Benchmark CLI
/// 
/// Run automated benchmarks without Flutter UI
/// Usage:
///   dart run_benchmark.dart                    # All models, 30 commands each
///   dart run_benchmark.dart --models qwen3-0.6b,gemma-3-2b --commands 10
///   dart run_benchmark.dart --models liquid-lfm-2-350m --commands 120

import 'package:flutter/foundation.dart' show kIsWeb;
import 'lib/services/headless_benchmark_runner.dart';

void main(List<String> args) async {
  if (kIsWeb) {
    print('Error: Headless benchmark cannot run on web platform');
    return;
  }
  
  print('╔════════════════════════════════════════════════════════════╗');
  print('║   On-Device Voice Agent Headless Benchmark Runner         ║');
  print('║   MediaTek Dimensity 7050 - Cactus v16 Framework          ║');
  print('╚════════════════════════════════════════════════════════════╝\n');
  
  await HeadlessBenchmarkRunner.run(
    modelIds: _parseModels(args),
    commandsPerModel: _parseCommands(args),
  );
}

List<String>? _parseModels(List<String> args) {
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--models' && i + 1 < args.length) {
      return args[i + 1].split(',');
    }
  }
  return null; // Use all models
}

int? _parseCommands(List<String> args) {
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--commands' && i + 1 < args.length) {
      return int.tryParse(args[i + 1]);
    }
  }
  return null; // Use default (30)
}
