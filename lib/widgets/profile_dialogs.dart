import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import 'other_allergies.dart';
import 'ui.dart';

Widget _choice(String icon, String label, bool selected,
        ValueChanged<bool> onChanged) =>
    FilterChip(
      avatar: Sym(icon, size: 22),
      label: Text(label),
      selected: selected,
      side:
          BorderSide(color: selected ? Palette.basil : Palette.line, width: 2),
      onSelected: onChanged,
    );

/// İlk tarif detayında bir kez sorulur; "Alerjim yok" ile hızlıca geçilebilir
/// ama kapatılarak atlanamaz.
class AllergyDialog extends StatefulWidget {
  const AllergyDialog({super.key, this.initial = const {}});

  final Set<Allergen> initial;

  @override
  State<AllergyDialog> createState() => _AllergyDialogState();
}

class _AllergyDialogState extends State<AllergyDialog> {
  late final Set<Allergen> _selected = {...widget.initial};
  List<String> _custom = const [];

  void _close(Set<Allergen> result, List<String> custom) {
    final state = context.read<AppState>();
    state.updateProfile(state.profile.copyWith(customAllergies: custom));
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Sym('⚠', size: 64),
      title: const Text('Alerjin var mı?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Güvenliğin için bir kez soruyoruz. Seçtiklerini içeren tarifler '
              'sana hiç gösterilmez. Bu bilgi yalnızca cihazında saklanır.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final a in Allergen.values)
                  _choice(
                      a.emoji,
                      a.label,
                      _selected.contains(a),
                      (on) => setState(
                          () => on ? _selected.add(a) : _selected.remove(a))),
              ],
            ),
            const SizedBox(height: 12),
            OtherAllergies(
              compact: true,
              values: _custom,
              onChanged: (v) => setState(() => _custom = v),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => _close(<Allergen>{}, const []),
          child: const Text('Alerjim yok'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty && _custom.isEmpty
              ? null
              : () => _close(_selected, _custom),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

/// İlk pişirmeden sonra sorulur; tarifler bu aletlere göre süzülür.
class AppliancesDialog extends StatefulWidget {
  const AppliancesDialog({super.key, required this.initial});

  final Set<Appliance> initial;

  @override
  State<AppliancesDialog> createState() => _AppliancesDialogState();
}

class _AppliancesDialogState extends State<AppliancesDialog> {
  late final Set<Appliance> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Sym('🔌', size: 64),
      title: const Text('Mutfağında neler var?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Sahip olmadığın aletleri gerektiren tarifleri gizleriz.',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final a in Appliance.values)
                _choice(
                    a.emoji,
                    a.label,
                    _selected.contains(a),
                    (on) => setState(
                        () => on ? _selected.add(a) : _selected.remove(a))),
            ],
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
