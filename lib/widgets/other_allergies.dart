import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/palette.dart';

/// Listede olmayan alerjiler: "Diğer"e dokununca yazı kutusu açılır,
/// kullanıcı "çilek", "karides" gibi yazıp ekler. Malzeme listemizde
/// karşılığı bulunan alerjilerde o malzemeyi içeren tarifler gizlenir;
/// bulunamayanlar için bunu açıkça söyleriz (uydurmayız).
class OtherAllergies extends StatefulWidget {
  const OtherAllergies({
    super.key,
    required this.values,
    required this.onChanged,
    this.compact = false,
  });

  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  /// Profil sayfasında: "Diğer" satırı daha küçük, çip gibi.
  final bool compact;

  @override
  State<OtherAllergies> createState() => _OtherAllergiesState();
}

class _OtherAllergiesState extends State<OtherAllergies> {
  final _controller = TextEditingController();
  late bool _open = widget.values.isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    // "çilek, karides" tek seferde yazılabilir.
    final parts = _controller.text
        .split(RegExp(r'[,;\n]+|\s+ve\s+'))
        .map((s) => s.trim())
        .where((s) => s.length >= 2);
    final next = [...widget.values];
    for (final p in parts) {
      if (!next.any((v) => v.toLowerCase() == p.toLowerCase())) next.add(p);
    }
    _controller.clear();
    if (next.length != widget.values.length) widget.onChanged(next);
  }

  void _toggle() {
    setState(() => _open = !_open);
    // Kapatınca yazılanlar da kaldırılır; "Diğer" seçili değilse alerji yok.
    if (!_open && widget.values.isNotEmpty) widget.onChanged(const []);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matcher = context.read<AppState>().matcher;
    final selected = _open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          selected: selected,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: _toggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: widget.compact
                    ? const EdgeInsets.fromLTRB(12, 8, 12, 8)
                    : const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: selected ? Palette.basilSoft : Palette.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: selected ? Palette.accent : Palette.line,
                      width: selected ? 1.6 : 1),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: widget.compact ? 24 : 34,
                      child: Icon(Icons.edit_note_rounded,
                          size: widget.compact ? 22 : 28,
                          color: Palette.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Diğer',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: widget.compact ? 14 : 16)),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: selected ? Palette.basil : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: selected ? Palette.basil : Palette.lineDeep,
                            width: 2),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              size: 18, color: Colors.white)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: widget.values.isEmpty,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    hintText: 'Alerjini yaz: çilek, karides…',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _add(),
                  // "Ekle"ye basmadan "Devam"a dokunulursa yazılan kaybolmasın.
                  onTapOutside: (_) {
                    if (_controller.text.trim().isNotEmpty) _add();
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _add,
                child: const Text('Ekle'),
              ),
            ],
          ),
          for (final v in widget.values) ...[
            const SizedBox(height: 8),
            Builder(builder: (_) {
              final label = matcher.customAllergyLabel(v);
              return Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                decoration: BoxDecoration(
                  color: Palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Palette.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          Text(
                            label != null
                                ? '$label içeren tarifler gizlenir'
                                : 'Malzeme listemizde bulamadık; tariflerde '
                                    'kendin kontrol et',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: label != null
                                    ? Palette.inkSoft
                                    : Palette.tomato),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '$v alerjisini kaldır',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () =>
                          widget.onChanged([...widget.values]..remove(v)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ],
    );
  }
}
