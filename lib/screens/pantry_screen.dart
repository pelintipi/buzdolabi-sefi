import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ingredient.dart';
import '../models/pantry_item.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/amount_controls.dart';
import '../widgets/ui.dart';
import 'ingredient_input_screen.dart';

class PantryScreen extends StatelessWidget {
  const PantryScreen({super.key});

  void _add(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const IngredientInputScreen()));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final expiringIds = {for (final p in state.expiringItems) p.id};
    final others = [
      for (final p in state.pantry)
        if (!expiringIds.contains(p.id)) p
    ]..sort((a, b) => state.repo
        .byId(a.ingredientId)
        .name
        .compareTo(state.repo.byId(b.ingredientId).name));

    return Scaffold(
      // "Ekle" üst çubukta: alttaki bildirimler (Geri al vb.) üstünü örtmesin.
      appBar: AppBar(
        title: const Text('Dolabım'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ChunkyButton(
              label: 'Malzeme ekle',
              icon: '🛒',
              tone: ChunkyTone.primary,
              expand: false,
              height: 40,
              onPressed: () => _add(context),
            ),
          ),
        ],
      ),
      body: state.pantry.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FoodIcon('🧺', size: 130),
                    const SizedBox(height: 12),
                    Text('Dolabın boş görünüyor.',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      'Malzeme ekledikçe sana uygun tarifler burada şekillenir.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Palette.inkSoft),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Text(
                  '${state.pantry.length} malzeme · dokunarak miktarı ve tarihi değiştir',
                  style: theme.textTheme.bodySmall,
                ),
                if (expiringIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const SectionTitle('Yakında bozulacak', icon: '⏳'),
                  for (final p in state.expiringItems) _PantryTile(item: p),
                ],
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const SectionTitle('Dolaptakiler', icon: '🧺'),
                  for (final p in others) _PantryTile(item: p),
                ],
              ],
            ),
    );
  }
}

String pantryAmountText(PantryItem item, Ingredient ing) {
  final q = item.quantity;
  if (q != null) return formatBase(ing, q);
  return (item.level ?? ApproxLevel.biraz).label;
}

class _PantryTile extends StatelessWidget {
  const _PantryTile({required this.item});

  final PantryItem item;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final ing = state.repo.byId(item.ingredientId);
    final now = DateTime.now();
    final expiry = expiryText(item.expiresAt, now);
    final soon = item.expiresAt != null &&
        daysUntil(item.expiresAt!, now) <= AppState.expiringDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _PantryEditSheet(item: item),
        ),
        child: Row(
          children: [
            IconBubble(ing.emoji,
                size: 56, color: soon ? Palette.tomatoSoft : Palette.basilSoft),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ing.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(pantryAmountText(item, ing),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Palette.inkSoft)),
                ],
              ),
            ),
            if (expiry.isNotEmpty)
              Pill(expiry,
                  color: soon ? Palette.tomatoSoft : Palette.basilSoft,
                  fg: soon ? Palette.tomatoDeep : Palette.basilDeep,
                  border: null),
          ],
        ),
      ),
    );
  }
}

class _PantryEditSheet extends StatefulWidget {
  const _PantryEditSheet({required this.item});

  final PantryItem item;

  @override
  State<_PantryEditSheet> createState() => _PantryEditSheetState();
}

class _PantryEditSheetState extends State<_PantryEditSheet> {
  late double? _quantity = widget.item.quantity;
  late ApproxLevel? _level = widget.item.level;
  late DateTime? _expiresAt = widget.item.expiresAt;
  final _exact = TextEditingController();

  @override
  void dispose() {
    _exact.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  void _save() {
    final state = context.read<AppState>();
    final exact = double.tryParse(_exact.text.replaceAll(',', '.'));
    final quantity = exact ?? _quantity;
    state.updatePantryItem(PantryItem(
      id: widget.item.id,
      ingredientId: widget.item.ingredientId,
      addedAt: widget.item.addedAt,
      quantity: quantity,
      level: quantity == null ? (_level ?? ApproxLevel.biraz) : null,
      expiresAt: _expiresAt,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final theme = Theme.of(context);
    final ing = state.repo.byId(widget.item.ingredientId);
    final unit = ing.baseUnit == BaseUnit.ml ? 'ml' : 'g';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(ing.emoji, size: 64),
              const SizedBox(width: 14),
              Text(ing.name, style: theme.textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: 18),
          Text('Ne kadar var?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (ing.baseUnit == BaseUnit.piece)
            QuantityStepper(
              value: _quantity ??
                  math.max(
                      1.0,
                      (ing.packageAmount *
                              (_level ?? ApproxLevel.biraz).fraction)
                          .roundToDouble()),
              label: ing.pieceLabel,
              onChanged: (v) => setState(() {
                _quantity = v;
                _level = null;
              }),
            )
          else ...[
            if (_quantity != null)
              Row(
                children: [
                  Pill('Şu an: ${formatBase(ing, _quantity!)}',
                      color: Palette.basilSoft,
                      fg: Palette.basilDeep,
                      border: null),
                  TextButton(
                    onPressed: () => setState(() {
                      _quantity = null;
                      _level = ApproxLevel.biraz;
                    }),
                    child: const Text('Yaklaşık seç'),
                  ),
                ],
              )
            else
              LevelSelector(
                value: _level ?? ApproxLevel.biraz,
                onChanged: (l) => setState(() => _level = l),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _exact,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'Kesin miktar ($unit), isteğe bağlı'),
            ),
          ],
          const SizedBox(height: 14),
          SoftCard(
            padding: const EdgeInsets.all(14),
            onTap: _pickDate,
            child: Row(
              children: [
                const FoodIcon('⏳', size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _expiresAt == null
                        ? 'Son kullanma tarihi yok'
                        : 'Son kullanma: ${formatDate(_expiresAt!)} · ${expiryText(_expiresAt, DateTime.now())}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(Icons.edit_calendar_rounded, color: Palette.basil),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  state.removePantryItem(widget.item.id);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Palette.tomatoDeep),
                label: const Text('Sil',
                    style: TextStyle(color: Palette.tomatoDeep)),
              ),
              const SizedBox(width: 12),
              Expanded(child: ChunkyButton(label: 'Kaydet', onPressed: _save)),
            ],
          ),
        ],
      ),
    );
  }
}
