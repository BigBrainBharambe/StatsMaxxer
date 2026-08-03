import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/habit.dart';
import '../domain/quantity_window_goal.dart';
import 'habits_providers.dart';

Future<void> showAddHabitSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const AddHabitSheet(),
  );
}

class AddHabitSheet extends ConsumerStatefulWidget {
  const AddHabitSheet({super.key});

  @override
  ConsumerState<AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends ConsumerState<AddHabitSheet> {
  final _nameController = TextEditingController();
  final _unitLabelController = TextEditingController(text: 'units');
  int _step = 0;
  HabitKind _kind = HabitKind.repeatable;
  int _interval = 1;
  ScheduleUnit _unit = ScheduleUnit.day;
  final Set<int> _weekdays = {DateTime.now().weekday};
  final Set<int> _monthDays = {DateTime.now().day};
  int _yearMonth = DateTime.now().month;
  int _yearDay = DateTime.now().day;
  TimeOfDay? _reminder;
  String _icon = habitIconOptions.first;
  int _color = habitColorOptions.first;
  DateTime _adhocDue = DateTime.now().add(const Duration(hours: 1));
  bool _saving = false;

  // Quantity goal fields
  QuantityComparator _comparator = QuantityComparator.gt;
  int _targetQty = 3;
  int _windowSize = 1;
  QuantityWindowUnit _windowUnit = QuantityWindowUnit.day;

  @override
  void dispose() {
    _nameController.dispose();
    _unitLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _step == 0
                  ? 'New habit'
                  : _step == 1
                      ? (_kind == HabitKind.quantity
                          ? 'Quantity goal'
                          : 'Schedule')
                      : 'Reminder & look',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildStep()),
            Row(
              children: [
                if (_step > 0)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _step -= 1),
                    child: const Text('Back'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _onPrimary,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_step < 2 ? 'Next' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return ListView(
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<HabitKind>(
              segments: const [
                ButtonSegment(
                  value: HabitKind.repeatable,
                  label: Text('Repeat'),
                  icon: Icon(Icons.repeat),
                ),
                ButtonSegment(
                  value: HabitKind.adhoc,
                  label: Text('Ad-hoc'),
                  icon: Icon(Icons.bolt),
                ),
                ButtonSegment(
                  value: HabitKind.quantity,
                  label: Text('Qty'),
                  icon: Icon(Icons.stacked_bar_chart),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            const SizedBox(height: 12),
            Text(
              switch (_kind) {
                HabitKind.repeatable =>
                  'Repeats on a schedule. Only those days count for streaks.',
                HabitKind.adhoc =>
                  'One-time activity with a due time. Get notified, then mark it done.',
                HabitKind.quantity =>
                  'Log a quantity over a time window (e.g. >3 glasses in 24 hours).',
              },
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      case 1:
        if (_kind == HabitKind.quantity) {
          return _buildQuantityGoalStep();
        }
        if (_kind == HabitKind.adhoc) {
          return ListView(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due date'),
                subtitle: Text(
                  '${_adhocDue.year}-${_adhocDue.month.toString().padLeft(2, '0')}-${_adhocDue.day.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: dateOnlySafe(_adhocDue),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (d != null) {
                    setState(() {
                      _adhocDue = DateTime(
                        d.year,
                        d.month,
                        d.day,
                        _adhocDue.hour,
                        _adhocDue.minute,
                      );
                    });
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due time'),
                subtitle: Text(
                  TimeOfDay.fromDateTime(_adhocDue).format(context),
                ),
                trailing: const Icon(Icons.schedule),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_adhocDue),
                  );
                  if (t != null) {
                    setState(() {
                      _adhocDue = DateTime(
                        _adhocDue.year,
                        _adhocDue.month,
                        _adhocDue.day,
                        t.hour,
                        t.minute,
                      );
                    });
                  }
                },
              ),
            ],
          );
        }
        return ListView(
          children: [
            Row(
              children: [
                const Text('Every'),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _interval <= 1
                      ? null
                      : () => setState(() => _interval--),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_interval', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  onPressed: () => setState(() => _interval++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<ScheduleUnit>(
              segments: const [
                ButtonSegment(value: ScheduleUnit.day, label: Text('Days')),
                ButtonSegment(value: ScheduleUnit.week, label: Text('Weeks')),
                ButtonSegment(value: ScheduleUnit.month, label: Text('Months')),
                ButtonSegment(value: ScheduleUnit.year, label: Text('Years')),
              ],
              selected: {_unit},
              onSelectionChanged: (v) => setState(() => _unit = v.first),
            ),
            const SizedBox(height: 16),
            if (_unit == ScheduleUnit.week) ...[
              const Text('On days'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(const [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ][d - 1]),
                      selected: _weekdays.contains(d),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            _weekdays.add(d);
                          } else if (_weekdays.length > 1) {
                            _weekdays.remove(d);
                          }
                        });
                      },
                    ),
                ],
              ),
            ],
            if (_unit == ScheduleUnit.month) ...[
              const Text('Days of month'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var d = 1; d <= 31; d++)
                    FilterChip(
                      label: Text('$d'),
                      selected: _monthDays.contains(d),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            _monthDays.add(d);
                          } else if (_monthDays.length > 1) {
                            _monthDays.remove(d);
                          }
                        });
                      },
                    ),
                ],
              ),
            ],
            if (_unit == ScheduleUnit.year) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Month'),
                trailing: DropdownButton<int>(
                  value: _yearMonth,
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(value: m, child: Text('$m')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _yearMonth = v);
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Day'),
                trailing: DropdownButton<int>(
                  value: _yearDay,
                  items: [
                    for (var d = 1; d <= 31; d++)
                      DropdownMenuItem(value: d, child: Text('$d')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _yearDay = v);
                  },
                ),
              ),
            ],
          ],
        );
      default:
        return ListView(
          children: [
            if (_kind != HabitKind.quantity)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reminder'),
                subtitle: Text(
                  _reminder == null
                      ? 'Off'
                      : _reminder!.format(context),
                ),
                value: _reminder != null,
                onChanged: (on) async {
                  if (!on) {
                    setState(() => _reminder = null);
                    return;
                  }
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (t != null) setState(() => _reminder = t);
                },
              ),
            if (_kind != HabitKind.quantity && _reminder != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reminder time'),
                trailing: TextButton(
                  onPressed: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: _reminder!,
                    );
                    if (t != null) setState(() => _reminder = t);
                  },
                  child: Text(_reminder!.format(context)),
                ),
              ),
            if (_kind != HabitKind.quantity) const SizedBox(height: 8),
            const Text('Icon'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final icon in habitIconOptions)
                  ChoiceChip(
                    label: Icon(habitIconData(icon)),
                    selected: _icon == icon,
                    onSelected: (_) => setState(() => _icon = icon),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Color'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final c in habitColorOptions)
                  ChoiceChip(
                    label: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                      ),
                    ),
                    selected: _color == c,
                    onSelected: (_) => setState(() => _color = c),
                  ),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildQuantityGoalStep() {
    final preview = QuantityWindowGoal(
      comparator: _comparator,
      target: _targetQty,
      unitLabel: _unitLabelController.text.trim(),
      windowSize: _windowSize,
      windowUnit: _windowUnit,
    );
    return ListView(
      children: [
        Text('Rule', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<QuantityComparator>(
          segments: const [
            ButtonSegment(value: QuantityComparator.gt, label: Text('>')),
            ButtonSegment(value: QuantityComparator.gte, label: Text('≥')),
            ButtonSegment(value: QuantityComparator.lt, label: Text('<')),
            ButtonSegment(value: QuantityComparator.lte, label: Text('≤')),
          ],
          selected: {_comparator},
          onSelectionChanged: (v) => setState(() => _comparator = v.first),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Target'),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _targetQty <= 1
                  ? null
                  : () => setState(() => _targetQty--),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '$_targetQty',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            IconButton(
              onPressed: () => setState(() => _targetQty++),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _unitLabelController,
          decoration: const InputDecoration(
            labelText: 'Unit label',
            hintText: 'glasses, workouts, …',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text('Window', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Last'),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _windowSize <= 1
                  ? null
                  : () => setState(() => _windowSize--),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '$_windowSize',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            IconButton(
              onPressed: () => setState(() => _windowSize++),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<QuantityWindowUnit>(
          segments: const [
            ButtonSegment(
              value: QuantityWindowUnit.hour,
              label: Text('Hours'),
            ),
            ButtonSegment(
              value: QuantityWindowUnit.day,
              label: Text('Days'),
            ),
            ButtonSegment(
              value: QuantityWindowUnit.week,
              label: Text('Weeks'),
            ),
          ],
          selected: {_windowUnit},
          onSelectionChanged: (v) {
            setState(() {
              _windowUnit = v.first;
              if (_windowUnit == QuantityWindowUnit.hour && _windowSize < 24) {
                // leave as-is; user may want 1h
              }
            });
          },
        ),
        const SizedBox(height: 16),
        Text(
          preview.summary,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          _windowUnit == QuantityWindowUnit.hour
              ? 'Hours use a rolling clock window. Streaks count calendar days that meet the rule.'
              : 'Days/weeks use calendar windows. Streaks count consecutive success days.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _onPrimary() async {
    if (_step == 0) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a habit name')),
        );
        return;
      }
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (_kind == HabitKind.quantity &&
          _unitLabelController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a unit label')),
        );
        return;
      }
      setState(() => _step = 2);
      return;
    }

    setState(() => _saving = true);
    try {
      HabitSchedule? schedule;
      QuantityWindowGoal? quantityGoal;
      if (_kind == HabitKind.repeatable) {
        schedule = HabitSchedule(
          interval: _interval,
          unit: _unit,
          weekdays: _unit == ScheduleUnit.week ? _weekdays.toList() : const [],
          monthDays:
              _unit == ScheduleUnit.month ? _monthDays.toList() : const [],
          month: _unit == ScheduleUnit.year ? _yearMonth : null,
          day: _unit == ScheduleUnit.year ? _yearDay : null,
        );
      } else if (_kind == HabitKind.quantity) {
        quantityGoal = QuantityWindowGoal(
          comparator: _comparator,
          target: _targetQty,
          unitLabel: _unitLabelController.text.trim(),
          windowSize: _windowSize,
          windowUnit: _windowUnit,
        );
      }

      final reminderMinutes = _kind == HabitKind.quantity
          ? null
          : (_reminder == null
              ? (_kind == HabitKind.adhoc
                  ? _adhocDue.hour * 60 + _adhocDue.minute
                  : null)
              : _reminder!.hour * 60 + _reminder!.minute);

      await ref.read(habitActionsProvider).createHabit(
            name: _nameController.text,
            kind: _kind,
            schedule: schedule,
            quantityGoal: quantityGoal,
            reminderTimeMinutes: reminderMinutes,
            colorValue: _color,
            iconName: _icon,
            adhocDueAt: _kind == HabitKind.adhoc ? _adhocDue : null,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

DateTime dateOnlySafe(DateTime d) => DateTime(d.year, d.month, d.day);
