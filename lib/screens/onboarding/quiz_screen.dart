import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../auth/login_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _step = 0;
  final Map<int, String> _answers = {
    3: '8',
    4: '22',
  };

  final List<Map<String, dynamic>> _questions = [
    {
      'id': 1,
      'question': 'What do you mainly use TimeWise for?',
      'type': 'choice',
      'options': [
        {'label': 'School', 'emoji': '🎓', 'desc': 'Assignments, exams & classes'},
        {'label': 'Work', 'emoji': '💼', 'desc': 'Meetings, projects & deadlines'},
        {'label': 'Personal', 'emoji': '🌱', 'desc': 'Goals, habits & self-care'},
        {'label': 'A mix of everything', 'emoji': '⚡', 'desc': 'Balance all areas of life'},
      ],
    },
    {
      'id': 2,
      'question': 'What is your usual schedule?',
      'type': 'choice',
      'options': [
        {'label': 'Mostly fixed', 'emoji': '🔒', 'desc': 'Regular times, consistent routine'},
        {'label': 'Mostly flexible', 'emoji': '🔀', 'desc': 'Changes day to day'},
        {'label': 'Combination of both', 'emoji': '⚖️', 'desc': 'Some fixed, some flexible'},
      ],
    },
    {
      'id': 3,
      'question': 'What time do you usually start your day?',
      'type': 'time',
    },
    {
      'id': 4,
      'question': 'What time do you usually finish your day?',
      'type': 'time',
    },
    {
      'id': 5,
      'question': 'How much help do you want from AI?',
      'type': 'choice',
      'options': [
        {'label': 'Minimal suggestions', 'emoji': '🎯', 'desc': 'I prefer to plan manually'},
        {'label': 'Balanced', 'emoji': '🤝', 'desc': 'AI suggests, I decide'},
        {'label': 'Let AI help me plan', 'emoji': '✨', 'desc': 'AI does the heavy lifting'},
      ],
    },
  ];

  String _fmtHour(int h) {
    if (h == 12) return "12:00 PM";
    return h < 12 ? "$h:00 AM" : "${h - 12}:00 PM";
  }

  void _handleNext() {
    if (_step < _questions.length - 1) {
      setState(() => _step++);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _handleBack() {
    if (_step > 0) {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _questions[_step];
    final total = _questions.length;
    final progress = (_step + 1) / total;
    final answer = _answers[q['id']];
    final canNext = q['type'] == 'time' ? true : answer != null;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _step > 0 ? _handleBack : null,
                        child: AnimatedOpacity(
                          opacity: _step > 0 ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            '← Back',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        '${_step + 1}/$total',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 6,
                      width: MediaQuery.of(context).size.width * progress - 48,
                      decoration: BoxDecoration(
                        gradient: AppColors.btnGradient,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Question content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q['question'],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (q['type'] == 'choice')
                      ...List.generate(
                        (q['options'] as List).length,
                        (index) {
                          final opt = q['options'][index];
                          final isSelected = answer == opt['label'];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _answers[q['id']] = opt['label'];
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : theme.colorScheme.outline,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      opt['emoji'],
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            opt['label'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            opt['desc'],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check, size: 12, color: Colors.white),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    if (q['type'] == 'time') ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: theme.colorScheme.outline),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    q['id'] == 3 ? '🌅' : '🌙',
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _fmtHour(int.parse(_answers[q['id']] ?? (q['id'] == 3 ? '8' : '22'))),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Text(
                                      'Selected time',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor: theme.colorScheme.outline,
                                thumbColor: AppColors.primary,
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: double.parse(_answers[q['id']] ?? (q['id'] == 3 ? '8' : '22')),
                                min: 5,
                                max: 23,
                                divisions: 18,
                                onChanged: (val) {
                                  setState(() {
                                    _answers[q['id']] = val.round().toString();
                                  });
                                },
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('5:00 AM', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                                Text('11:00 PM', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [6, 7, 8, 9, 17, 18, 22, 23].map((h) {
                          final isSelected = int.parse(_answers[q['id']] ?? '') == h;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _answers[q['id']] = h.toString();
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : theme.colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : theme.colorScheme.outline,
                                ),
                              ),
                              child: Text(
                                _fmtHour(h),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Continue Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: canNext ? AppColors.btnGradient : null,
                  color: canNext ? null : theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: canNext
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: canNext ? _handleNext : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      child: Text(
                        _step == total - 1 ? 'All done →' : 'Continue →',
                        style: TextStyle(
                          color: canNext ? Colors.white : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
