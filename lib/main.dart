import 'package:flutter/material.dart';
import 'package:cactus/cactus.dart';
import 'package:my_agent_app/tools/device_controls.dart';
import 'package:my_agent_app/services/benchmark_service.dart';
import 'package:my_agent_app/services/headless_benchmark_runner.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Agent App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

// Rule-based automation for temporal/contextual reasoning
class AutomationRule {
  final String id;
  final String trigger; // e.g., "in class", "at work", "sleeping"
  final String action; // e.g., "mute", "enable DND", "dim screen"
  final Map<String, dynamic> parameters;
  final DateTime created;
  bool enabled;

  AutomationRule({
    required this.id,
    required this.trigger,
    required this.action,
    required this.parameters,
    required this.created,
    this.enabled = true,
  });

  @override
  String toString() => 'Rule: When "$trigger" → $action';
}

class _MainScreenState extends State<MainScreen> {
  CactusLM? lm;
  CactusSTT? stt;
  String status = 'Not initialized';
  bool isInitializing = false;
  final TextEditingController _messageController = TextEditingController();
  String response = '';
  final List<AutomationRule> _rules = [];

  // Model selection for benchmarking
  String _currentModel = 'qwen3-0.6';
  final List<Map<String, String>> _availableModels = [
    // Baseline models
    {
      'id': 'qwen3-0.6',
      'name': 'Qwen 3 (0.6B)',
      'size': '0.6B',
      'type': 'generalist',
    },
    {
      'id': 'smollm-1.7b',
      'name': 'SmolLM (1.7B)',
      'size': '1.7B',
      'type': 'generalist',
    },

    // NEW: Gemma 3 (SOTA 2025)
    {
      'id': 'gemma-3-2b',
      'name': 'Gemma 3 (2B) [SOTA 2025]',
      'size': '2B',
      'type': 'generalist',
    },

    // NEW: Function-Calling Specialists
    {
      'id': 'functiongemma-270m',
      'name': 'Function-Gemma (270M) [Specialist]',
      'size': '270M',
      'type': 'specialist',
    },
    {
      'id': 'functiongemma-270m-pro',
      'name': 'Function-Gemma Pro (270M)',
      'size': '270M',
      'type': 'specialist',
    },

    // NEW: Liquid Foundation Models (Temporal Reasoning)
    {
      'id': 'lfm2-350m',
      'name': 'Liquid LFM-2 (350M) [Temporal]',
      'size': '350M',
      'type': 'liquid',
    },
    {
      'id': 'lfm2-700m',
      'name': 'Liquid LFM-2 (700M) [Temporal]',
      'size': '700M',
      'type': 'liquid',
    },
    {
      'id': 'lfm2-1.2b',
      'name': 'Liquid LFM-2 (1.2B) [Temporal]',
      'size': '1.2B',
      'type': 'liquid',
    },
    {
      'id': 'lfm2-1.2b-tool',
      'name': 'Liquid LFM-2 Tool (1.2B)',
      'size': '1.2B',
      'type': 'liquid',
    },

    // Larger models (comparison)
    {
      'id': 'qwen3-1.7',
      'name': 'Qwen 3 (1.7B)',
      'size': '1.7B',
      'type': 'generalist',
    },
    {
      'id': 'llama-3.2-3b',
      'name': 'Llama 3.2 (3B)',
      'size': '3B',
      'type': 'generalist',
    },
    {
      'id': 'phi-3.5-mini',
      'name': 'Phi 3.5 Mini (3.8B)',
      'size': '3.8B',
      'type': 'generalist',
    },
  ];

  // Research metrics
  int _commandCount = 0;
  int _llmCount = 0;
  int _fallbackCount = 0;
  int _totalLatencyMs = 0;
  String _currentTier = '';
  bool _showOnboarding = true;
  bool _isDemoRunning = false;
  bool _isBenchmarkRunning = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _initializeAgent() async {
    if (isInitializing) return;

    setState(() {
      isInitializing = true;
      status = 'Downloading and initializing models...';
    });

    try {
      lm = CactusLM();
      stt = CactusSTT();

      // Download and initialize LLM with selected model
      setState(() {
        status = 'Downloading $_currentModel...';
      });

      await lm!.downloadModel(
        model: _currentModel,
        downloadProcessCallback: (progress, statusMsg, isError) {
          if (!isError && mounted) {
            setState(() {
              status =
                  '$statusMsg ${progress != null ? '(${(progress * 100).toStringAsFixed(0)}%)' : ''}';
            });
          }
        },
      );
      await lm!.initializeModel();

      // Download and initialize STT (using Whisper provider)
      setState(() {
        status = 'Downloading STT model...';
      });

      final downloadSuccess = await stt!.download(
        model: 'whisper-tiny',
        downloadProcessCallback: (progress, statusMsg, isError) {
          if (!isError && mounted) {
            setState(() {
              status =
                  'STT: $statusMsg ${progress != null ? '(${(progress * 100).toStringAsFixed(0)}%)' : ''}';
            });
          }
        },
      );

      if (downloadSuccess) {
        setState(() {
          status = 'Initializing STT model...';
        });
        final initSuccess = await stt!.init(model: 'whisper-tiny');

        if (!initSuccess) {
          throw Exception('Failed to initialize STT model');
        }
      } else {
        throw Exception('Failed to download STT model');
      }

      setState(() {
        status =
            'Models initialized successfully. STT ready: ${stt!.isReady()}';
        isInitializing = false;
      });
    } catch (e) {
      setState(() {
        status = 'Failed to initialize: $e';
        isInitializing = false;
      });
    }
  }

  // ========================================================================
  // KEYWORD FALLBACK REMOVED FOR PURE LLM EVALUATION
  // This app now relies 100% on LLM function calling for research purposes
  // ========================================================================

  Future<void> _executeFunctionCall(Map<String, dynamic> functionData) async {
    final functionName = functionData['function'];

    // Handle rule creation
    if (functionName == 'createRule') {
      final trigger = functionData['trigger'] as String;
      final action = functionData['action'] as String;

      // Map natural language action to function
      String mappedAction;
      Map<String, dynamic> parameters = {};

      if (action.contains('mute') ||
          action.contains('silence') ||
          action.contains('dnd') ||
          action.contains('do not disturb')) {
        mappedAction = 'setDoNotDisturb';
        parameters['durationMinutes'] = 60; // Default 1 hour
      } else if (action.contains('flashlight') || action.contains('torch')) {
        mappedAction = 'toggleFlashlight';
        parameters['enable'] =
            action.contains('on') || action.contains('enable');
      } else if (action.contains('volume')) {
        mappedAction = 'setVolume';
        parameters['volumePercent'] = 0; // Mute
      } else {
        setState(() {
          response = 'Could not understand action: "$action"';
          status = 'Rule creation failed';
        });
        return;
      }

      final rule = AutomationRule(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        trigger: trigger,
        action: mappedAction,
        parameters: parameters,
        created: DateTime.now(),
      );

      _rules.add(rule);
      print('✓ Rule created: $rule');

      setState(() {
        response =
            'Rule created: When "$trigger" → $mappedAction\n\n'
            'Note: This is a prototype. In production, you would:\n'
            '• Use calendar/location APIs to detect context\n'
            '• Store rules in local database\n'
            '• Run background service to monitor triggers\n\n'
            'Total rules: ${_rules.length}';
        status = 'Rule created';
      });
      return;
    }

    // Handle rule listing
    if (functionName == 'listRules') {
      if (_rules.isEmpty) {
        setState(() {
          response =
              'No rules created yet.\n\n'
              'Try: "Mute notifications when I\'m in class"';
          status = 'No rules';
        });
      } else {
        final ruleList = _rules
            .asMap()
            .entries
            .map((e) {
              final rule = e.value;
              return '${e.key + 1}. ${rule.enabled ? "✓" : "✗"} When "${rule.trigger}" → ${rule.action}';
            })
            .join('\n');

        setState(() {
          response =
              'Active Rules (${_rules.length}):\n\n$ruleList\n\n'
              'Research Note: Measuring rule accuracy requires:\n'
              '• Context detection (calendar, location)\n'
              '• Trigger evaluation frequency\n'
              '• False positive/negative rates';
          status = 'Rules listed';
        });
      }
      return;
    }

    // Handle rule clearing
    if (functionName == 'clearRules') {
      final count = _rules.length;
      _rules.clear();
      setState(() {
        response = 'Deleted $count rule${count != 1 ? "s" : ""}';
        status = 'Rules cleared';
      });
      return;
    }

    if (functionName == 'setDoNotDisturb') {
      final durationMinutes = (functionData['durationMinutes'] is int)
          ? functionData['durationMinutes']
          : int.tryParse(functionData['durationMinutes']?.toString() ?? '30') ??
                30;
      print('Executing DND: $durationMinutes minutes');
      final success = await DeviceControls.setDoNotDisturb(
        durationMinutes: durationMinutes,
      );
      setState(() {
        response =
            'DND ${success ? 'enabled' : 'failed'} for $durationMinutes minutes';
        status = success ? 'Success' : 'Failed';
      });
    } else if (functionName == 'toggleFlashlight') {
      final enable =
          functionData['enable'] == true ||
          functionData['enable']?.toString().toLowerCase() == 'true';
      print('Executing flashlight: $enable');
      final success = await DeviceControls.toggleFlashlight(enable: enable);
      setState(() {
        response =
            'Flashlight ${success ? (enable ? 'turned on' : 'turned off') : 'failed'}';
        status = success ? 'Success' : 'Failed';
      });
    } else if (functionName == 'setVolume') {
      final volumePercent = (functionData['volumePercent'] is int)
          ? functionData['volumePercent']
          : int.tryParse(functionData['volumePercent']?.toString() ?? '50') ??
                50;
      print('Executing volume: $volumePercent%');
      final success = await DeviceControls.setVolume(
        volumePercent: volumePercent,
      );
      setState(() {
        response = 'Volume ${success ? 'set to $volumePercent%' : 'failed'}';
        status = success ? 'Success' : 'Failed';
      });
    } else if (functionName == 'setScreenBrightness') {
      final brightnessPercent = (functionData['brightnessPercent'] is int)
          ? functionData['brightnessPercent']
          : int.tryParse(
                  functionData['brightnessPercent']?.toString() ?? '50',
                ) ??
                50;
      print('Executing brightness: $brightnessPercent%');
      final success = await DeviceControls.setScreenBrightness(
        brightnessPercent: brightnessPercent,
      );
      setState(() {
        response =
            'Brightness ${success ? 'set to $brightnessPercent%' : 'failed'}';
        status = success ? 'Success' : 'Failed';
      });
    } else if (functionName == 'toggleWifi') {
      final enable =
          functionData['enable'] == true ||
          functionData['enable']?.toString().toLowerCase() == 'true';
      print('Executing wifi: $enable');
      final success = await DeviceControls.toggleWifi(enable: enable);
      setState(() {
        response =
            'Wi-Fi ${success ? (enable ? 'enabled' : 'disabled') : 'failed'}';
        status = success ? 'Success' : 'Failed';
      });
    }
  }

  Future<void> _sendMessage(String userMessage) async {
    if (lm == null || !lm!.isLoaded()) {
      setState(() {
        status = 'Model not initialized';
      });
      return;
    }

    final stopwatch = Stopwatch()..start();
    setState(() {
      status = 'Processing with LLM...';
      response = '';
      _currentTier = 'llm';
    });

    // LLM-FIRST ARCHITECTURE: Try complex reasoning first
    try {
      final tools = _buildToolsList();

      // Use adaptive system prompt based on model type
      final systemPrompt = _getSystemPrompt(_currentModel);

      final modelType = _availableModels.firstWhere(
        (m) => m['id'] == _currentModel,
        orElse: () => {'type': 'unknown'},
      )['type'];
      print('→ LLM ($_currentModel) analyzing: "$userMessage"');
      print('   Using ${systemPrompt.length} char prompt ($modelType type)');

      // Temporarily keep inline tools for compatibility
      final inlineTools = [
        CactusTool(
          name: 'setDoNotDisturb',
          description:
              'Enables Do Not Disturb mode for a specified duration. Use when user wants silence, quiet, focus time, or mentions time-based contexts like "during meetings", "while studying", "next 2 hours", etc.',
          parameters: ToolParametersSchema(
            properties: {
              'durationMinutes': ToolParameter(
                type: 'integer',
                description:
                    'Duration in minutes. Extract from phrases like "30 minutes", "next hour" (60), "2 hours" (120), "until 5pm" (calculate from current time), etc.',
                required: true,
              ),
            },
          ),
        ),
        CactusTool(
          name: 'toggleFlashlight',
          description:
              'Controls device flashlight/torch. Use for lighting, visibility, emergency signals, or when user mentions "light", "torch", "flash".',
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
          description:
              'Adjusts device volume. Use for "louder", "quieter", "max volume", specific percentages, or contextual requests like "suitable for sleeping" (low), "loud enough for music" (high).',
          parameters: ToolParametersSchema(
            properties: {
              'volumePercent': ToolParameter(
                type: 'integer',
                description:
                    'Volume from 0-100. Map contexts: sleeping=10, quiet=30, medium=50, loud=80, max=100.',
                required: true,
              ),
            },
          ),
        ),
        CactusTool(
          name: 'createRule',
          description:
              'Creates automation rules for temporal/contextual scenarios. Use when user mentions "when", "during", "while", "if" with context triggers like "in class", "at work", "sleeping".',
          parameters: ToolParametersSchema(
            properties: {
              'trigger': ToolParameter(
                type: 'string',
                description:
                    'Context trigger: "in class", "at work", "sleeping", "driving", "gym", etc.',
                required: true,
              ),
              'action': ToolParameter(
                type: 'string',
                description:
                    'Action to perform: "mute", "enable_dnd", "set_low_volume", "turn_off_flashlight".',
                required: true,
              ),
              'durationMinutes': ToolParameter(
                type: 'integer',
                description: 'Optional duration for the action in minutes.',
                required: false,
              ),
            },
          ),
        ),
        CactusTool(
          name: 'setScreenBrightness',
          description:
              'Adjusts screen brightness. Use for "brighter", "dimmer", "max brightness", specific percentages, or contextual requests like "reading mode" (70%), "night mode" (20%), "suitable for outdoors" (100%).',
          parameters: ToolParametersSchema(
            properties: {
              'brightnessPercent': ToolParameter(
                type: 'integer',
                description:
                    'Brightness from 0-100. Map contexts: night=20, indoor=50, reading=70, outdoors=100.',
                required: true,
              ),
            },
          ),
        ),
        CactusTool(
          name: 'toggleWifi',
          description:
              'Controls Wi-Fi connection. Use for connectivity management, data saving, or when user mentions "wifi", "internet", "connection", "online", "offline".',
          parameters: ToolParametersSchema(
            properties: {
              'enable': ToolParameter(
                type: 'boolean',
                description: 'True to enable Wi-Fi, false to disable.',
                required: true,
              ),
            },
          ),
        ),
      ];

      final messages = [
        ChatMessage(content: systemPrompt, role: 'system'),
        ChatMessage(content: userMessage, role: 'user'),
      ];
      final result = await lm!.generateCompletion(
        messages: messages,
        params: CactusCompletionParams(
          tools: inlineTools,
          maxTokens: 300,
          temperature: 0.1,
        ),
      );

      print(
        'LLM result: success=${result.success}, toolCalls=${result.toolCalls.length}',
      );

      if (result.success && result.toolCalls.isNotEmpty) {
        // LLM SUCCESS - Primary reasoning tier
        print(
          '✓ LLM successfully generated ${result.toolCalls.length} tool call(s)',
        );
        setState(() {
          _commandCount++;
          _llmCount++;
          status = 'LLM extracted intent';
        });

        for (final toolCall in result.toolCalls) {
          print('  Tool: ${toolCall.name}, Args: ${toolCall.arguments}');
          try {
            await _executeFunctionCall({
              'function': toolCall.name,
              ...toolCall.arguments,
            });
          } catch (e) {
            print('  Tool execution error: $e');
            setState(() {
              response = 'Execution error: $e';
            });
          }
        }

        stopwatch.stop();
        setState(() {
          _totalLatencyMs += stopwatch.elapsedMilliseconds;
          _currentTier = '';
        });
        return;
      } else {
        // LLM returned no tool calls - PURE LLM EVALUATION
        print('⚠ LLM did not generate tool calls');
        setState(() {
          _commandCount++;
          _fallbackCount++;
          status = 'LLM failed to generate tool calls';
          response =
              'LLM Error: Failed to extract function call from "$userMessage"\n\n'
              'This is logged for research purposes. The LLM should have called a function.\n\n'
              'Expected behavior: Always call one of the available functions.\n'
              'Actual behavior: No tool calls generated.';
        });
        stopwatch.stop();
        setState(() {
          _totalLatencyMs += stopwatch.elapsedMilliseconds;
          _currentTier = '';
        });
      }
    } catch (e) {
      // LLM FAILURE - NO FALLBACK (Pure LLM evaluation for research)
      print('❌ LLM error: $e');
      setState(() {
        _commandCount++;
        _fallbackCount++;
        status = 'LLM inference failed';
        response =
            'LLM Inference Error: $e\n\n'
            'Command: "$userMessage"\n\n'
            'This failure is logged for benchmarking purposes.\n'
            'In production, consider fallback mechanisms.';
      });
      stopwatch.stop();
      setState(() {
        _totalLatencyMs += stopwatch.elapsedMilliseconds;
        _currentTier = '';
      });
    }
  }

  Future<void> _runDemoSequence() async {
    if (_isDemoRunning) return;

    setState(() {
      _isDemoRunning = true;
    });

    final demoCommands = [
      ('I need silence for the next 2 hours', 'Demo 1/4: Temporal extraction'),
      ('Make my phone suitable for sleeping', 'Demo 2/4: Context reasoning'),
      ('Turn on do not disturb for 45 minutes', 'Demo 3/4: Time parsing'),
      ('Mute notifications when I\'m in class', 'Demo 4/4: Rule creation'),
    ];

    for (var i = 0; i < demoCommands.length; i++) {
      setState(() {
        status = demoCommands[i].$2;
        _messageController.text = demoCommands[i].$1;
      });
      await Future.delayed(const Duration(seconds: 2));
      await _sendMessage(demoCommands[i].$1);
      await Future.delayed(const Duration(seconds: 4));
    }

    setState(() {
      _isDemoRunning = false;
      status = 'Demo completed! Check metrics above.';
    });
  }

  Future<void> _runAutomatedBenchmark() async {
    if (_isBenchmarkRunning) return;

    setState(() {
      _isBenchmarkRunning = true;
      status = 'Starting automated benchmark...';
    });

    try {
      // Get the tools list (same as used in _sendMessage)
      final tools = _buildToolsList();

      // Get system prompt (same as used in _sendMessage)
      const systemPrompt =
          'You are an intelligent device control assistant with function calling capabilities. '
          'Your task is to analyze voice commands and call the appropriate function with correct parameters.\n\n'
          '## Reasoning Process (Think Step-by-Step):\n'
          '1. Parse the user intent: What action do they want?\n'
          '2. Identify synonyms: silence=mute=quiet=dnd, torch=flashlight=light, brightness=screen\n'
          '3. Extract parameters: numbers, time durations, context clues\n'
          '4. Handle temporal expressions: "next hour"=60min, "2 hours"=120min\n'
          '5. Map contextual requests: "sleeping"→low volume/brightness, "reading"→70% brightness\n'
          '6. Choose function and validate parameters\n\n'
          '## Examples:\n'
          '- "Turn on flashlight" → toggleFlashlight(enable=true)\n'
          '- "I need quiet for 2 hours" → setDoNotDisturb(durationMinutes=120)\n'
          '- "Set volume to 75 percent" → setVolume(volumePercent=75)\n'
          '- "Brightness for reading" → setScreenBrightness(brightnessPercent=70)\n'
          '- "Enable wifi" → toggleWifi(enable=true)\n'
          '- "Mute when in class" → createRule(trigger="in class", action="mute")\n\n'
          '## Rules:\n'
          '- ALWAYS call a function - never respond with plain text\n'
          '- Extract exact numeric values when present\n'
          '- Use reasonable defaults for contextual requests\n'
          '- Handle ASR errors gracefully (recognize phonetic variations)';

      final service = BenchmarkService(
        tools: tools,
        systemPrompt: systemPrompt,
      );

      // Run benchmark for all models
      await service.runFullBenchmark(
        modelIds: _availableModels.map((m) => m['id']!).toList(),
        onProgress: (msg) {
          if (mounted) {
            setState(() {
              status = msg;
            });
          }
        },
      );

      setState(() {
        status =
            'Benchmark completed! Results saved to results/benchmark_results.csv';
        response =
            'Successfully tested ${_availableModels.length} models across 120 commands.\n\n'
            'Results exported to:\n'
            '• results/benchmark_results.csv\n'
            '• results/benchmark_results.json\n'
            '• results/benchmark_summary.md\n\n'
            'Run generate_realistic_charts.py to visualize results.';
      });
    } catch (e) {
      setState(() {
        status = 'Benchmark failed: $e';
        response = 'Error during benchmark: $e';
      });
    } finally {
      setState(() {
        _isBenchmarkRunning = false;
      });
    }
  }

  Future<void> _runHeadlessBenchmark() async {
    if (_isBenchmarkRunning) return;

    setState(() {
      _isBenchmarkRunning = true;
      status = 'Starting headless benchmark (crash-resistant)...';
    });

    try {
      await HeadlessBenchmarkRunner.run(
        onProgress: (msg) {
          if (mounted) {
            setState(() {
              status = msg;
            });
          }
        },
      );

      setState(() {
        status =
            'Headless benchmark completed! Results saved with incremental checkpointing.';
        response =
            'Successfully tested 12 models across 30 commands (360 total tests).\n\n'
            'Crash-resistant features:\n'
            '• Incremental CSV saving (no data loss)\n'
            '• Progress checkpointing (auto-resume)\n'
            '• Memory leak prevention\n'
            '• Aggressive cleanup every 5 commands\n\n'
            'Results exported to:\n'
            '• results/headless_benchmark_results.csv\n'
            '• results/headless_benchmark_summary.md\n'
            '• results/benchmark_progress.json\n\n'
            'Run analysis scripts to visualize results.';
      });
    } catch (e) {
      setState(() {
        status = 'Headless benchmark failed: $e';
        response = 'Error during headless benchmark: $e';
      });
    } finally {
      setState(() {
        _isBenchmarkRunning = false;
      });
    }
  }

  List<CactusTool> _buildToolsList() {
    return [
      CactusTool(
        name: 'toggleFlashlight',
        description: 'Turn device flashlight on or off',
        parameters: ToolParametersSchema(
          properties: {
            'enable': ToolParameter(
              type: 'boolean',
              description: 'true to turn on, false to turn off',
              required: true,
            ),
          },
        ),
      ),
      CactusTool(
        name: 'setDoNotDisturb',
        description:
            'Enable Do Not Disturb mode for specified duration. Handles "next hour", "2 hours", temporal expressions.',
        parameters: ToolParametersSchema(
          properties: {
            'durationMinutes': ToolParameter(
              type: 'integer',
              description: 'Duration in minutes (e.g., 60 for 1 hour)',
              required: true,
            ),
          },
        ),
      ),
      CactusTool(
        name: 'setVolume',
        description: 'Set device volume level',
        parameters: ToolParametersSchema(
          properties: {
            'volumePercent': ToolParameter(
              type: 'integer',
              description: 'Volume level 0-100',
              required: true,
            ),
          },
        ),
      ),
      CactusTool(
        name: 'createRule',
        description:
            'Create automation rule for contextual actions. Example: "Mute when in class" creates rule.',
        parameters: ToolParametersSchema(
          properties: {
            'trigger': ToolParameter(
              type: 'string',
              description:
                  'Context trigger (e.g., "in class", "at work", "sleeping")',
              required: true,
            ),
            'action': ToolParameter(
              type: 'string',
              description: 'Action to perform (e.g., "mute", "enable dnd")',
              required: true,
            ),
          },
        ),
      ),
      CactusTool(
        name: 'setScreenBrightness',
        description:
            'Set screen brightness level. Context-aware: "reading"=70%, "night"=20%, "outdoors"=100%.',
        parameters: ToolParametersSchema(
          properties: {
            'brightnessPercent': ToolParameter(
              type: 'integer',
              description: 'Brightness level 0-100',
              required: true,
            ),
          },
        ),
      ),
      CactusTool(
        name: 'toggleWifi',
        description: 'Enable or disable WiFi connection',
        parameters: ToolParametersSchema(
          properties: {
            'enable': ToolParameter(
              type: 'boolean',
              description: 'true to enable, false to disable',
              required: true,
            ),
          },
        ),
      ),
    ];
  }

  String _getSystemPrompt(String modelId) {
    final modelInfo = _availableModels.firstWhere(
      (m) => m['id'] == modelId,
      orElse: () => {'type': 'generalist'},
    );

    final modelType = modelInfo['type'] ?? 'generalist';

    switch (modelType) {
      case 'specialist':
        // Function-Gemma: Minimal prompt (pre-trained for tool use)
        return '''
You are a function-calling specialist. Your only task is to call the appropriate device control function.

Available functions:
• toggleFlashlight(enable: bool) - Control flashlight
• setDoNotDisturb(durationMinutes: int) - Enable DND mode
• setVolume(volumePercent: int) - Set volume 0-100
• setScreenBrightness(brightnessPercent: int) - Set brightness 0-100
• toggleWifi(enable: bool) - Control WiFi
• createRule(trigger: string, action: string) - Create automation rule

ALWAYS call a function. Extract parameters from user intent.
''';

      case 'liquid':
        // Liquid LFM: Emphasize temporal reasoning
        return '''
You are a temporal reasoning assistant specialized in time-aware device control.

TEMPORAL REASONING FOCUS:
• "next hour" = 60 minutes
• "2 hours" = 120 minutes
• "until 5pm" = calculate duration from now
• "while sleeping" = 480 minutes (8 hours)
• "during meeting" = 60 minutes default

Available functions:
• setDoNotDisturb(durationMinutes: int) - TIME-CRITICAL: Extract exact duration
• toggleFlashlight(enable: bool)
• setVolume(volumePercent: int)
• setScreenBrightness(brightnessPercent: int)
• toggleWifi(enable: bool)
• createRule(trigger: string, action: string)

Your strength is understanding temporal expressions. Always call a function with precise time values.
''';

      case 'generalist':
      default:
        // Full detailed prompt for general models (including Gemma 3)
        return '''
You are an intelligent device control assistant with function calling capabilities.
Your task is to analyze voice commands and call the appropriate function with correct parameters.

## Reasoning Process (Think Step-by-Step):
1. Parse the user intent: What action do they want?
2. Identify synonyms: silence=mute=quiet=dnd, torch=flashlight=light, brightness=screen
3. Extract parameters: numbers, time durations, context clues
4. Handle temporal expressions: "next hour"=60min, "2 hours"=120min
5. Map contextual requests: "sleeping"→low volume/brightness, "reading"→70% brightness
6. Choose function and validate parameters

## Examples:
- "Turn on flashlight" → toggleFlashlight(enable=true)
- "I need quiet for 2 hours" → setDoNotDisturb(durationMinutes=120)
- "Set volume to 75 percent" → setVolume(volumePercent=75)
- "Brightness for reading" → setScreenBrightness(brightnessPercent=70)
- "Enable wifi" → toggleWifi(enable=true)
- "Mute when in class" → createRule(trigger="in class", action="mute")

## Rules:
- ALWAYS call a function - never respond with plain text
- Extract exact numeric values when present
- Use reasonable defaults for contextual requests
- Handle ASR errors gracefully (recognize phonetic variations)
''';
    }
  }

  Future<void> _transcribeAndSend() async {
    // Check microphone permission
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        setState(() {
          status = 'Microphone permission denied';
        });
        return;
      }
    }

    if (stt == null || !stt!.isReady()) {
      setState(() {
        status = 'STT not initialized. Press Initialize Models first.';
      });
      return;
    }

    setState(() {
      status = 'Recording... Speak now!';
    });

    try {
      print('Starting transcription...');
      final result = await stt!.transcribe(
        params: SpeechRecognitionParams(
          maxDuration: 10000, // 10 seconds
          sampleRate: 16000,
        ),
      );

      print(
        'Transcription result: success=${result?.success}, text="${result?.text}"',
      );

      if (result != null) {
        if (result.success && result.text.isNotEmpty) {
          print('Transcription successful: ${result.text}');
          setState(() {
            status = 'Transcribed: ${result.text}';
            _messageController.text = result.text;
          });
          await _sendMessage(result.text);
        } else if (result.text.isEmpty) {
          print('Empty transcription result');
          setState(() {
            status = 'No speech detected. Speak louder, hold phone closer.';
          });
        } else {
          print('Transcription failed with success=false');
          setState(() {
            status = 'Transcription failed. Try speaking more clearly.';
          });
        }
      } else {
        print('Transcription returned null');
        setState(() {
          status = 'Recording failed. Check microphone permission.';
        });
      }
    } catch (e, stackTrace) {
      print('Transcription error: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        status = 'Error: $e';
      });
    }
  }

  @override
  void dispose() {
    lm?.unload();
    stt?.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _switchModel(String newModel) async {
    if (newModel == _currentModel) return;

    setState(() {
      status = 'Switching to $newModel...';
      isInitializing = true;
    });

    try {
      // CRITICAL: Properly unload old model to prevent memory leak
      if (lm != null) {
        await lm!.unload();
        lm = null;
      }

      // Update current model
      setState(() {
        _currentModel = newModel;
      });

      // Initialize new model
      lm = CactusLM();
      await lm!.downloadModel(
        model: _currentModel,
        downloadProcessCallback: (progress, statusMsg, isError) {
          if (!isError && mounted) {
            setState(() {
              status =
                  '$statusMsg ${progress != null ? '(${(progress * 100).toStringAsFixed(0)}%)' : ''}';
            });
          }
        },
      );
      await lm!.initializeModel();

      setState(() {
        status = 'Model switched to $_currentModel successfully';
        isInitializing = false;
      });
    } catch (e) {
      setState(() {
        status = 'Model switch failed: $e';
        isInitializing = false;
      });
    }
  }

  Widget _buildModelSelector() {
    final currentModelInfo = _availableModels.firstWhere(
      (m) => m['id'] == _currentModel,
      orElse: () => _availableModels[0],
    );

    return Card(
      color: Colors.blue[50],
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Model Selection',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _currentModel,
                    decoration: const InputDecoration(
                      labelText: 'Active Model',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: _availableModels.map((model) {
                      // Show model type emoji
                      String typeEmoji;
                      switch (model['type']) {
                        case 'specialist':
                          typeEmoji = '🎯';
                          break;
                        case 'liquid':
                          typeEmoji = '⏱️';
                          break;
                        default:
                          typeEmoji = '🤖';
                      }

                      return DropdownMenuItem(
                        value: model['id'],
                        child: Text(
                          '$typeEmoji ${model['name']}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: isInitializing
                        ? null
                        : (value) {
                            if (value != null) {
                              _switchModel(value);
                            }
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '📊 ${currentModelInfo['name']} (${currentModelInfo['size']})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              _getModelTypeDescription(
                currentModelInfo['type'] ?? 'generalist',
              ),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lm != null
                  ? '✓ Model loaded and ready'
                  : '⚠ Initialize model first',
              style: TextStyle(
                fontSize: 11,
                color: lm != null ? Colors.green : Colors.orange,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getModelTypeDescription(String type) {
    switch (type) {
      case 'specialist':
        return '🎯 Optimized for function calling accuracy';
      case 'liquid':
        return '⏱️ Temporal reasoning specialist (CfC architecture)';
      default:
        return '🤖 General-purpose transformer model';
    }
  }

  Widget _buildOnboardingCard() {
    return Card(
      color: Colors.amber[50],
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Quick Start Guide',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('1. Select a model type:'),
            const Text(
              '   🎯 Specialist - Best for function accuracy',
              style: TextStyle(fontSize: 12),
            ),
            const Text(
              '   ⏱️ Liquid - Best for temporal reasoning',
              style: TextStyle(fontSize: 12),
            ),
            const Text(
              '   🤖 Generalist - Balanced performance',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text('2. Press "Initialize Models" (wait ~30s)'),
            const Text('3. Press "Request DND Permission"'),
            const Text('4. Try commands or run benchmark'),
            const SizedBox(height: 8),
            const Text(
              'Test commands:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const Text(
              '  • "I need silence for 2 hours" (temporal)',
              style: TextStyle(fontSize: 11),
            ),
            const Text(
              '  • "Turn on flashlight" (direct)',
              style: TextStyle(fontSize: 11),
            ),
            const Text(
              '  • "Set volume to 73 percent" (parameter)',
              style: TextStyle(fontSize: 11),
            ),
            const Text(
              '  • "Mute when I\'m in class" (rule)',
              style: TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => setState(() => _showOnboarding = false),
              child: const Text('Got it!'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsPanel() {
    final llmPct = _commandCount > 0
        ? (_llmCount / _commandCount * 100).toStringAsFixed(0)
        : '0';
    final fallbackPct = _commandCount > 0
        ? (_fallbackCount / _commandCount * 100).toStringAsFixed(0)
        : '0';
    final avgLatency = _commandCount > 0
        ? (_totalLatencyMs / _commandCount).toStringAsFixed(0)
        : '0';

    return Card(
      color: Colors.blue[50],
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Research Metrics (Pure LLM)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Model: $_currentModel',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total Commands: $_commandCount',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              '├─ Successful: $_llmCount ($llmPct%)',
              style: const TextStyle(fontSize: 13, color: Colors.green),
            ),
            Text(
              '└─ Failed: $_fallbackCount ($fallbackPct%)',
              style: const TextStyle(fontSize: 13, color: Colors.red),
            ),
            const SizedBox(height: 8),
            Text(
              'Average Latency: ${avgLatency}ms',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '💡 Switch models to compare performance',
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierIndicator() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Processing Mode (Pure LLM - No Fallback)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTierBadge(
                  'LLM Inference',
                  _currentTier == 'llm',
                  Colors.green,
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward, size: 20),
                const SizedBox(width: 12),
                _buildTierBadge(
                  'Success/Fail',
                  _currentTier == '',
                  Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ Keyword fallback disabled for research',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierBadge(String label, bool active, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? color : Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? color.withOpacity(0.5) : Colors.grey,
          width: 2,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : Colors.black54,
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('My Agent App'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showOnboarding) _buildOnboardingCard(),
            _buildModelSelector(),
            if (_commandCount > 0) _buildMetricsPanel(),
            _buildTierIndicator(),
            Text(
              'Status: $status',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (response.isNotEmpty) ...[
              Text('Response:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(response),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isInitializing ? null : _initializeAgent,
                    child: const Text('Initialize Models'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isDemoRunning ? null : _runDemoSequence,
                    child: Text(_isDemoRunning ? 'Running...' : 'Run Demo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await DeviceControls.requestDndPermission();
                      setState(() {
                        status = 'DND permission requested';
                      });
                    },
                    child: const Text('Request DND Permission'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _commandCount = 0;
                        _llmCount = 0;
                        _fallbackCount = 0;
                        _totalLatencyMs = 0;
                        status = 'Metrics reset for $_currentModel';
                      });
                    },
                    child: const Text('Reset Metrics'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _isBenchmarkRunning || lm == null
                  ? null
                  : _runAutomatedBenchmark,
              icon: _isBenchmarkRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.speed),
              label: Text(
                _isBenchmarkRunning
                    ? 'Running Benchmark...'
                    : 'Run Full Benchmark (120 cmds × 5 models)',
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _isBenchmarkRunning
                  ? null
                  : _runHeadlessBenchmark,
              icon: _isBenchmarkRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.nightlight_round),
              label: Text(
                _isBenchmarkRunning
                    ? 'Running...'
                    : 'Headless Benchmark (30 cmds × 12 models)',
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Type Command',
                hintText:
                    'Try: "I need silence for 2 hours" or "Make phone suitable for sleeping"',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.chat_bubble_outline),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_messageController.text.isNotEmpty) {
                        _sendMessage(_messageController.text);
                      }
                    },
                    child: const Text('Send'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _sendMessage('show rules');
                  },
                  child: Text('Rules (${_rules.length})'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _transcribeAndSend,
              icon: const Icon(Icons.mic),
              label: const Text('Record Voice Command'),
            ),
          ],
        ),
      ),
    );
  }
}
