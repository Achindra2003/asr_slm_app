import 'package:flutter/material.dart';
import 'package:cactus/cactus.dart';
import 'package:my_agent_app/tools/device_controls.dart';
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

      // Download and initialize LLM
      await lm!.downloadModel(
        model: 'qwen3-0.6',
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

  // Parse temporal/contextual rules from natural language
  Future<Map<String, dynamic>?> _parseRuleFromText(String text) async {
    final lowerText = text.toLowerCase();
    
    // Detect rule creation patterns: "when X do Y", "while X do Y", "during X do Y"
    final rulePatterns = [
      RegExp(r'(when|while|during)\s+(?:i[' "'" r']?m?\s+)?(.*?)\s+(mute|silence|enable dnd|turn off|disable)(.*)', caseSensitive: false),
      RegExp(r'(mute|silence)\s+(.*?)\s+(when|while|during)\s+(?:i[' "'" r']?m?\s+)?(.*)', caseSensitive: false),
    ];
    
    for (final pattern in rulePatterns) {
      final match = pattern.firstMatch(lowerText);
      if (match != null) {
        String trigger, action;
        
        if (match.groupCount >= 4) {
          // Pattern 1: "when in class mute notifications"
          if (match.group(1) != null && match.group(1)!.startsWith(RegExp(r'when|while|during'))) {
            trigger = match.group(2)!.trim();
            action = match.group(3)!.trim();
          } else {
            // Pattern 2: "mute notifications when in class"
            action = match.group(1)!.trim();
            trigger = match.group(4)!.trim();
          }
          
          print('✓ Rule detected: trigger="$trigger", action="$action"');
          return {
            'function': 'createRule',
            'trigger': trigger,
            'action': action,
            'originalText': text,
          };
        }
      }
    }
    
    // Check for rule management commands
    if (lowerText.contains('show rules') || lowerText.contains('list rules') ||
        lowerText.contains('my rules') || lowerText.contains('what rules')) {
      return {'function': 'listRules'};
    }
    
    if (lowerText.contains('delete') && (lowerText.contains('rule') || lowerText.contains('all'))) {
      return {'function': 'clearRules'};
    }
    
    return null;
  }

  // Keyword-based fallback for handling ASR errors and model failures
  Future<Map<String, dynamic>?> _parseIntentFromText(String text) async {
    final lowerText = text.toLowerCase();
    
    // First check for rule creation
    final ruleIntent = await _parseRuleFromText(text);
    if (ruleIntent != null) return ruleIntent;

    // Flashlight detection
    if (lowerText.contains('flashlight') ||
        lowerText.contains('flash') ||
        lowerText.contains('torch')) {
      final enable =
          lowerText.contains('on') ||
          lowerText.contains('enable') ||
          lowerText.contains('turn on') ||
          lowerText.contains('start');
      print('Keyword: flashlight, enable=$enable');
      return {'function': 'toggleFlashlight', 'enable': enable};
    }

    // DND detection
    if (lowerText.contains('do not disturb') ||
        lowerText.contains('dnd') ||
        lowerText.contains('silent') ||
        lowerText.contains('quiet')) {
      final minutes = RegExp(
        r'(\d+)\s*(minute|min|hour|hr)',
      ).firstMatch(lowerText);
      int duration = 30;
      if (minutes != null) {
        final num = int.tryParse(minutes.group(1) ?? '30') ?? 30;
        final unit = minutes.group(2) ?? 'minute';
        duration = unit.startsWith('h') ? num * 60 : num;
      }
      print('Keyword: DND, duration=$duration');
      return {'function': 'setDoNotDisturb', 'durationMinutes': duration};
    }

    // Volume detection
    if (lowerText.contains('volume') ||
        lowerText.contains('sound') ||
        lowerText.contains('loud')) {
      final percent = RegExp(r'(\d+)\s*%?').firstMatch(lowerText);
      int volume = 50;
      if (percent != null) {
        volume = int.tryParse(percent.group(1) ?? '50') ?? 50;
      } else if (lowerText.contains('max') || lowerText.contains('full')) {
        volume = 100;
      } else if (lowerText.contains('low') || lowerText.contains('quiet')) {
        volume = 30;
      }
      print('Keyword: volume, percent=$volume');
      return {'function': 'setVolume', 'volumePercent': volume};
    }

    return null;
  }

  Future<void> _executeFunctionCall(Map<String, dynamic> functionData) async {
    final functionName = functionData['function'];

    // Handle rule creation
    if (functionName == 'createRule') {
      final trigger = functionData['trigger'] as String;
      final action = functionData['action'] as String;
      final originalText = functionData['originalText'] as String;
      
      // Map natural language action to function
      String mappedAction;
      Map<String, dynamic> parameters = {};
      
      if (action.contains('mute') || action.contains('silence') || 
          action.contains('dnd') || action.contains('do not disturb')) {
        mappedAction = 'setDoNotDisturb';
        parameters['durationMinutes'] = 60; // Default 1 hour
      } else if (action.contains('flashlight') || action.contains('torch')) {
        mappedAction = 'toggleFlashlight';
        parameters['enable'] = action.contains('on') || action.contains('enable');
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
        response = 'Rule created: When "$trigger" → $mappedAction\n\n'
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
          response = 'No rules created yet.\n\n'
                     'Try: "Mute notifications when I\'m in class"';
          status = 'No rules';
        });
      } else {
        final ruleList = _rules.asMap().entries.map((e) {
          final rule = e.value;
          return '${e.key + 1}. ${rule.enabled ? "✓" : "✗"} When "${rule.trigger}" → ${rule.action}';
        }).join('\n');
        
        setState(() {
          response = 'Active Rules (${_rules.length}):\n\n$ruleList\n\n'
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
    }
  }

  Future<void> _sendMessage(String userMessage) async {
    if (lm == null || !lm!.isLoaded()) {
      setState(() {
        status = 'Model not initialized';
      });
      return;
    }

    setState(() {
      status = 'Processing...';
      response = '';
    });

    // First attempt: keyword-based parsing (most robust)
    final keywordIntent = await _parseIntentFromText(userMessage);
    if (keywordIntent != null) {
      print('✓ Keyword match: ${keywordIntent['function']}');
      await _executeFunctionCall(keywordIntent);
      return;
    }

    try {
      final tools = [
        CactusTool(
          name: 'setDoNotDisturb',
          description: 'Enables Do Not Disturb mode for a specified duration.',
          parameters: ToolParametersSchema(
            properties: {
              'durationMinutes': ToolParameter(
                type: 'integer',
                description: 'The number of minutes to keep DND active.',
                required: true,
              ),
            },
          ),
        ),
        CactusTool(
          name: 'toggleFlashlight',
          description: 'Turns the device flashlight on or off.',
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
          description: 'Sets the device volume to a specific percentage.',
          parameters: ToolParametersSchema(
            properties: {
              'volumePercent': ToolParameter(
                type: 'integer',
                description: 'Volume level from 0 to 100 percent.',
                required: true,
              ),
            },
          ),
        ),
      ];

      final messages = [
        ChatMessage(
          content:
              'You are a device control assistant. Call the appropriate function based on the user request.',
          role: 'system',
        ),
        ChatMessage(content: userMessage, role: 'user'),
      ];

      final result = await lm!.generateCompletion(
        messages: messages,
        params: CactusCompletionParams(
          tools: tools,
          maxTokens: 150,
          temperature: 0.0,
        ),
      );

      print('Completion result code: ${result.success}');
      print('LLM Response: ${result.response}');
      print('Tool calls count: ${result.toolCalls.length}');

      setState(() {
        response = result.response.isNotEmpty
            ? result.response
            : 'Processing your request...';
        status = 'Response received';
      });

      // Handle tool calls from LLM
      if (result.success && result.toolCalls.isNotEmpty) {
        print('✓ LLM tool calls: ${result.toolCalls.length}');
        for (final toolCall in result.toolCalls) {
          try {
            print('LLM tool: ${toolCall.name}, args: ${toolCall.arguments}');
            final functionData = {
              'function': toolCall.name,
              ...toolCall.arguments,
            };
            await _executeFunctionCall(functionData);
          } catch (toolError) {
            print('Tool execution error: $toolError');
            setState(() {
              response = 'Error: $toolError';
              status = 'Failed';
            });
          }
        }
      } else {
        print('No tool calls from LLM, using keyword fallback');
        final fallbackIntent = await _parseIntentFromText(userMessage);
        if (fallbackIntent != null) {
          print('✓ Fallback keyword match: ${fallbackIntent['function']}');
          await _executeFunctionCall(fallbackIntent);
        } else {
          setState(() {
            response =
                'Could not understand command. Try: "turn on flashlight", "enable DND", "set volume 50"';
            status = 'No match';
          });
        }
      }
    } catch (e) {
      print('LLM error: $e, trying keyword fallback');
      final fallbackIntent = await _parseIntentFromText(userMessage);
      if (fallbackIntent != null) {
        print('✓ Error recovery via keywords: ${fallbackIntent['function']}');
        await _executeFunctionCall(fallbackIntent);
      } else {
        setState(() {
          status = 'Error: $e';
          response = 'Error: $e';
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('My Agent App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Status: $status',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
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
            ElevatedButton(
              onPressed: isInitializing ? null : _initializeAgent,
              child: const Text('Initialize Models'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await DeviceControls.requestDndPermission();
                setState(() {
                  status = 'DND permission requested';
                });
              },
              child: const Text('Request DND Permission'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Try: "Mute notifications when I\'m in class"',
                border: OutlineInputBorder(),
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
            ElevatedButton(
              onPressed: _transcribeAndSend,
              child: const Text('Record and Send'),
            ),
          ],
        ),
      ),
    );
  }
}
