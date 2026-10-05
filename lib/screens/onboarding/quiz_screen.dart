import 'package:flutter/material.dart';

import '../../services/onboarding_store.dart';
import '../../theme/app_styles.dart';
import '../../widgets/ui.dart';
import '../auth/login_screen.dart';

class _Option {
  final String value;
  final String label;
  final String description;
  final IconData icon;
  const _Option(this.value, this.label, this.description, this.icon);
}

class _ChoiceStep {
  final String key;
  final String question;
  final List<_Option> options;
  const _ChoiceStep(this.key, this.question, this.options);
}

const _steps = <_ChoiceStep>[
  _ChoiceStep('usage', 'What do you mainly use TimeWise for?', [
    _Option('School', 'School', 'Assignments, exams & classes', Icons.school_outlined),
    _Option('Work', 'Work', 'Meetings, projects & deadlines', Icons.work_outline),
    _Option('Personal', 'Personal', 'Goals, habits & self-care', Icons.spa_outlined),
    _Option('Mixed', 'A mix of everything', 'Balance all areas of life', Icons.dashboard_outlined),
  ]),
  _ChoiceStep('scheduleStyle', 'What is your usual schedule?', [
    _Option('Fixed', 'Mostly fixed', 'Regular times, consistent routine', Icons.lock_outline),
    _Option('Flexible', 'Mostly flexible', 'Changes day to day', Icons.shuffle),
    _Option('Both', 'Combination of both', 'Some fixed, some flexible', Icons.balance),
  ]),
];

const _aiStep = _ChoiceStep('aiHelp', 'How much help do you want from AI?', [
  _Option('Minimal', 'Minimal suggestions', 'I prefer to plan manually', Icons.touch_app_outlined),
  _Option('Balanced', 'Balanced', 'AI suggests, I decide', Icons.handshake_outlined),
  _Option('Full', 'Let AI help me plan', 'AI does the heavy lifting', Icons.auto_awesome),
]);

/// Five-step onboarding quiz. The answers are kept on the device and copied
/// into the profile after sign-in; the AI planner uses them as hints.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // Step order: usage, schedule style, wake, sleep, AI help.
  static const _total = 5;

  int _step = 0;
  final Map<String, String> _choices = {};
  int _wakeHour = 8;
  int _sleepHour = 22;

  static String _fmtHour(int h) {
    final suffix = h < 12 ? 'AM' : 'PM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:00 $suffix';
  }

  static String _hhmm(int h) => '${h.toString().padLeft(2, '0')}:00';

  _ChoiceStep? get _choiceStep => switch (_step) {
        0 => _steps[0],
        1 => _steps[1],
        4 => _aiStep,
        _ => null,
      };

  /// The day must end after it starts.
  String? get _timeError => _step == 3 && _sleepHour <= _wakeHour
      ? 'Finish time must be after your start time (${_fmtHour(_wakeHour)}).'
      : null;

  bool get _canContinue {
    final choice = _choiceStep;
    if (choice != null) return _choices.containsKey(choice.key);
    return _timeError == null;
  }

  Future<void> _next() async {
    if (_step < _total - 1) {
      setState(() => _step++);
      return;
    }
    await OnboardingStore.save({
      ..._choices,
      'wake': _hhmm(_wakeHour),
      'sleep': _hhmm(_sleepHour),
    });
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final choice = _choiceStep;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 16, AppSpacing.page, 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        AppBackButton(onPressed: _back),
                        const Spacer(),
                        Text('Question ${_step + 1} of $_total', style: context.label),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: (_step + 1) / _total),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          backgroundColor: context.cs.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
                  children: [
                    Text(
                      choice?.question ??
                          (_step == 2 ? 'What time do you usually start your day?' : 'What time do you usually finish your day?'),
                      style: context.h1.copyWith(fontSize: 24, height: 1.2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      choice != null
                          ? 'Pick one. You can change these later.'
                          : 'The AI planner will not schedule anything outside these hours.',
                      style: context.bodyMuted,
                    ),
                    const SizedBox(height: 20),
                    if (choice != null)
                      for (final option in choice.options)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ChoiceTile(
                            option: option,
                            selected: _choices[choice.key] == option.value,
                            onTap: () => setState(() => _choices[choice.key] = option.value),
                          ),
                        )
                    else
                      _TimeStep(
                        isStart: _step == 2,
                        hour: _step == 2 ? _wakeHour : _sleepHour,
                        error: _timeError,
                        label: _fmtHour,
                        onChanged: (h) => setState(() {
                          if (_step == 2) {
                            _wakeHour = h;
                          } else {
                            _sleepHour = h;
                          }
                        }),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 20),
                child: GradientButton(
                  label: _step == _total - 1 ? 'Finish' : 'Continue',
                  icon: _step == _total - 1 ? Icons.check : Icons.arrow_forward,
                  onPressed: _canContinue ? _next : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final _Option option;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceTile({required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      side: BorderSide(color: selected ? context.primary : context.cs.outline, width: 1.5),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.label}. ${option.description}',
      child: Material(
        color: selected ? context.primary.withValues(alpha: 0.10) : context.cs.surfaceContainer,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconTile(icon: option.icon),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.label, style: context.body.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(option.description, style: context.label),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: context.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeStep extends StatelessWidget {
  final bool isStart;
  final int hour;
  final String? error;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  const _TimeStep({
    required this.isStart,
    required this.hour,
    required this.error,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTile(icon: isStart ? Icons.wb_sunny_outlined : Icons.bedtime_outlined, size: 56),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label(hour), style: context.h1.copyWith(color: context.primary)),
                      Text('Selected time', style: context.label),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Slider(
                value: hour.toDouble(),
                min: 5,
                max: 23,
                divisions: 18,
                label: label(hour),
                semanticFormatterCallback: (v) => label(v.round()),
                onChanged: (v) => onChanged(v.round()),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('5:00 AM', style: context.label), Text('11:00 PM', style: context.label)],
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: context.cs.error),
                const SizedBox(width: 6),
                Expanded(child: Text(error!, style: context.label.copyWith(color: readableOn(context.cs.error, context.cs.surface)))),
              ],
            ),
          ),
        const SizedBox(height: 20),
        const SectionLabel('Quick pick'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final h in isStart ? const [6, 7, 8, 9, 10] : const [17, 18, 20, 22, 23])
              PillChip(label: label(h), selected: hour == h, onTap: () => onChanged(h)),
          ],
        ),
      ],
    );
  }
}
