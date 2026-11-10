import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/body_profile.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import 'ui.dart';

/// "Bana göre hesapla": boy, kilo, yaş, cinsiyet, hareket ve hedeften günlük
/// kalori ve protein hedefi. Kaydedince İlerleme'deki çubuklar buna göre olur.
Future<void> showBodyTargetsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _BodyTargetsSheet(),
    );

class _BodyTargetsSheet extends StatefulWidget {
  const _BodyTargetsSheet();

  @override
  State<_BodyTargetsSheet> createState() => _BodyTargetsSheetState();
}

class _BodyTargetsSheetState extends State<_BodyTargetsSheet> {
  late final BodyProfile? _old = context.read<AppState>().profile.body;
  late Sex _sex = _old?.sex ?? Sex.female;
  late ActivityLevel _activity = _old?.activity ?? ActivityLevel.light;
  late WeightGoal _goal = _old?.goal ?? WeightGoal.keep;
  late final _age = TextEditingController(text: _old?.age.toString() ?? '');
  late final _height =
      TextEditingController(text: _old == null ? '' : _num(_old.heightCm));
  late final _weight =
      TextEditingController(text: _old == null ? '' : _num(_old.weightKg));

  static String _num(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  static double? _parse(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  BodyProfile? get _body {
    final age = _parse(_age)?.round();
    final h = _parse(_height), w = _parse(_weight);
    if (BodyProfile.problem(age: age, heightCm: h, weightKg: w) != null) {
      return null;
    }
    return BodyProfile(
        sex: _sex,
        age: age!,
        heightCm: h!,
        weightKg: w!,
        activity: _activity,
        goal: _goal);
  }

  void _save(BodyProfile body) {
    final state = context.read<AppState>();
    final t = body.targets;
    state.updateProfile(state.profile
        .copyWith(body: body, dailyKcal: t.kcal, dailyProtein: t.protein));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = _body;
    final anyTyped = [_age, _height, _weight].any((c) => c.text.isNotEmpty);
    final problem = BodyProfile.problem(
        age: _parse(_age)?.round(),
        heightCm: _parse(_height),
        weightKg: _parse(_weight));

    Widget field(TextEditingController c, String label, String suffix) =>
        Expanded(
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            ],
            decoration: InputDecoration(
                labelText: label, suffixText: suffix, isDense: true),
            onChanged: (_) => setState(() {}),
          ),
        );

    Widget segment<T>(List<T> values, T value, String Function(T) label,
            ValueChanged<T> onChanged) =>
        SegmentedButton<T>(
          showSelectedIcon: false,
          segments: [
            for (final v in values)
              ButtonSegment(value: v, label: Text(label(v)))
          ],
          selected: {value},
          onSelectionChanged: (s) => setState(() => onChanged(s.first)),
        );

    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Günlük hedefimi hesapla',
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
                'Bilgilerin yalnızca bu cihazda saklanır. Tahmindir, tıbbi '
                'tavsiye değildir.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Palette.inkSoft)),
            const SizedBox(height: 16),
            segment(Sex.values, _sex, (s) => s.label, (v) => _sex = v),
            const SizedBox(height: 14),
            Row(children: [
              field(_age, 'Yaş', ''),
              const SizedBox(width: 10),
              field(_height, 'Boy', 'cm'),
              const SizedBox(width: 10),
              field(_weight, 'Kilo', 'kg'),
            ]),
            const SizedBox(height: 18),
            Text('Ne kadar hareketlisin?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final a in ActivityLevel.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                selected: a == _activity,
                leading: Icon(
                    a == _activity
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: a == _activity ? Palette.accent : Palette.inkSoft),
                title: Text(a.label,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(a.hint),
                onTap: () => setState(() => _activity = a),
              ),
            const SizedBox(height: 10),
            Text('Hedefin ne?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            segment(WeightGoal.values, _goal, (g) => g.label, (v) => _goal = v),
            const SizedBox(height: 18),
            if (body != null)
              _Result(body: body)
            else if (anyTyped && problem != null)
              Text(problem,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Palette.tomato)),
            const SizedBox(height: 16),
            ChunkyButton(
              label: body == null ? 'Bilgilerini yaz' : 'Hedefim bu olsun',
              tone: ChunkyTone.accent,
              onPressed: body == null ? null : () => _save(body),
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.body});

  final BodyProfile body;

  @override
  Widget build(BuildContext context) {
    final t = body.targets;
    final theme = Theme.of(context);
    final perKg = t.protein / body.weightKg;
    return SoftCard(
      color: Palette.basilSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SANA ÖNERİLEN',
              style: theme.textTheme.labelSmall
                  ?.copyWith(letterSpacing: 1.2, color: Palette.inkSoft)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              for (final (icon, text) in [
                ('🔥', '${t.kcal.round()} kcal'),
                ('💪', '${t.protein.round()} g protein'),
              ])
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Sym(icon, size: 26),
                  const SizedBox(width: 8),
                  Text(text,
                      style: const TextStyle(
                          fontFamily: Fonts.display,
                          fontWeight: FontWeight.w800,
                          fontSize: 24)),
                ]),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dinlenirken vücudun günde yaklaşık ${body.bmr.round()} kcal '
            'harcıyor; hareketinle birlikte '
            '${(body.bmr * body.activity.factor).round()} kcal. '
            '${switch (body.goal) {
              WeightGoal.lose =>
                'Kilo vermek için bunun yaklaşık %20 altı önerilir (haftada '
                    'yaklaşık yarım kilo).',
              WeightGoal.keep => 'Kilonu korumak için bu kadarı yeterli.',
              WeightGoal.gain =>
                'Kilo/kas almak için günde yaklaşık 300 kcal fazlası önerilir.',
            }} Protein kilogram başına ${perKg.toStringAsFixed(1)} g.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
