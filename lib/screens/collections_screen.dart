import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../services/collections.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/recipe_card.dart';
import '../widgets/ui.dart';
import 'recipe_detail_screen.dart';

/// Kaç tanesi şu an dolabındakilerle yapılabilir.
int readyCount(AppState state, List<Recipe> recipes) {
  final snap = state.snapshot;
  return recipes
      .where((r) => state.matcher.evaluate(r, snap).problems.isEmpty)
      .length;
}

void _open(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

/// Üç tür koleksiyon: Yaptıklarım (pişirdikçe dolar), kendi koleksiyonların
/// (Favoriler dahil) ve hazır koleksiyonlar (yemek türü ve besin değeri).
class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final cooked = state.cookedSummaries;
    final favorites = state.favorites;

    return Scaffold(
      appBar: AppBar(title: const Text('Koleksiyonlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          // ------------------------------------------------ Yaptıklarım
          SoftCard(
            color: Palette.butterSoft,
            borderColor: Palette.butter,
            onTap: () => _open(context, const CookedHistoryScreen()),
            child: Row(
              children: [
                const FoodIcon('🧑‍🍳', size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Yaptıklarım', style: theme.textTheme.titleLarge),
                      Text(
                          cooked.isEmpty
                              ? 'Pişirdiğin her tarif buraya kendiliğinden eklenir.'
                              : '${cooked.length} farklı tarif · ${state.totalCooks} pişirme',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                for (final c in cooked.take(3))
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: FoodIcon(c.recipe.emoji, size: 30),
                  ),
                const Icon(Icons.chevron_right_rounded, color: Palette.inkSoft),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ------------------------------------------------ Kendi koleksiyonlarım
          SectionTitle('Koleksiyonlarım',
              icon: '🔖',
              trailing: TextButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Yeni'),
                onPressed: () => createCollection(context),
              )),
          _CollectionTile(
            emoji: '❤',
            title: 'Favoriler',
            subtitle:
                '${favorites.length} tarif · ${readyCount(state, favorites)} tanesi hazır',
            color: Palette.tomatoSoft,
            onTap: () =>
                _open(context, const CollectionDetailScreen.favorites()),
          ),
          for (final c in state.collections)
            Builder(builder: (_) {
              final rs = state.recipesIn(c);
              return _CollectionTile(
                emoji: c.emoji,
                title: c.name,
                subtitle:
                    '${rs.length} tarif · ${readyCount(state, rs)} tanesi hazır',
                color: Palette.surface,
                onTap: () => _open(context, CollectionDetailScreen.user(c.id)),
              );
            }),
          if (state.collections.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                  '"Misafir menüsü", "Diyet haftası" gibi kendi koleksiyonunu oluştur; '
                  'tarif sayfasındaki kitap ayracıyla tarif ekle.',
                  style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: 12),

          // ------------------------------------------------ Hazır koleksiyonlar
          const SectionTitle('Hazır koleksiyonlar', icon: '🗂'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              for (final s in smartCollections)
                Builder(builder: (_) {
                  final rs = state.recipesInSmart(s);
                  return SoftCard(
                    padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
                    onTap: () =>
                        _open(context, CollectionDetailScreen.smart(s.id)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FoodIcon(s.emoji, size: 34),
                        const Spacer(),
                        Text(s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium),
                        Text(
                            '${rs.length} tarif · ${readyCount(state, rs)} hazır',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              'Besin değerleri tahminidir; "hafif" ve "doyurucu" porsiyon başı kaloriye göre.',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        onTap: onTap,
        child: Row(
          children: [
            IconBubble(emoji,
                size: 50,
                color: color == Palette.surface ? Palette.basilSoft : color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Palette.inkSoft),
          ],
        ),
      ),
    );
  }
}

enum _Kind { favorites, user, smart }

/// Bir koleksiyonun tarifleri: şimdi yapılabilenler önde.
class CollectionDetailScreen extends StatelessWidget {
  const CollectionDetailScreen.favorites({super.key})
      : _kind = _Kind.favorites,
        id = '';
  const CollectionDetailScreen.user(this.id, {super.key}) : _kind = _Kind.user;
  const CollectionDetailScreen.smart(this.id, {super.key})
      : _kind = _Kind.smart;

  final _Kind _kind;
  final String id;

  Future<void> _confirmDelete(BuildContext context, UserCollection c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Koleksiyon silinsin mi?'),
        content: Text('"${c.name}" silinir; içindeki tarifler silinmez.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final state = context.read<AppState>();
    Navigator.of(context).pop();
    state.deleteCollection(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final user = _kind == _Kind.user ? state.collectionById(id) : null;
    final smart = _kind == _Kind.smart
        ? smartCollections.firstWhere((s) => s.id == id)
        : null;
    if (_kind == _Kind.user && user == null) return const Scaffold();

    final (title, emoji, description, recipes) = switch (_kind) {
      _Kind.favorites => (
          'Favoriler',
          '❤',
          'Kalp verdiğin tarifler',
          state.favorites
        ),
      _Kind.user => (
          user!.name,
          user.emoji,
          'Senin koleksiyonun',
          state.recipesIn(user)
        ),
      _Kind.smart => (
          smart!.title,
          smart.emoji,
          smart.description,
          state.recipesInSmart(smart)
        ),
    };
    final snap = state.snapshot;
    final matches = [for (final r in recipes) state.matcher.evaluate(r, snap)]
      ..sort((a, b) {
        final p = a.problems.length.compareTo(b.problems.length);
        return p != 0 ? p : b.score.compareTo(a.score);
      });
    final ready = matches.where((m) => m.problems.isEmpty).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (user != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Düzenle',
              onPressed: () => createCollection(context, editing: user),
            ),
            IconButton(
              icon: const FoodIcon('🗑', size: 24),
              tooltip: 'Koleksiyonu sil',
              onPressed: () => _confirmDelete(context, user),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Row(
            children: [
              IconBubble(emoji, size: 64, color: Palette.butterSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(description, style: theme.textTheme.bodySmall),
                    Text(
                        recipes.isEmpty
                            ? 'Henüz tarif yok'
                            : '${recipes.length} tarif · $ready tanesini şimdi yapabilirsin',
                        style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (recipes.isEmpty)
            Text(
                _kind == _Kind.user
                    ? 'Bir tarifi açıp sağ üstteki kitap ayracına dokun, bu koleksiyonu seç.'
                    : 'Bir tarifte kalbe dokununca buraya gelir.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Palette.inkSoft))
          else
            for (final m in matches)
              if (user == null)
                RecipeCard(match: m)
              else
                Dismissible(
                  key: ValueKey('${user.id}-${m.recipe.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: Palette.tomatoSoft,
                        borderRadius: BorderRadius.circular(24)),
                    child: const Text('Çıkar',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Palette.tomatoDeep)),
                  ),
                  onDismissed: (_) =>
                      state.toggleInCollection(user.id, m.recipe.id),
                  child: RecipeCard(match: m),
                ),
          if (user != null && recipes.isNotEmpty)
            Text('Çıkarmak için tarifi sola kaydır.',
                style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// "Yaptıklarım": pişirilen tarifler, kaç kez ve en son ne zaman.
class CookedHistoryScreen extends StatelessWidget {
  const CookedHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final cooked = state.cookedSummaries;
    final most = [...cooked]..sort((a, b) => b.times.compareTo(a.times));
    final now = DateTime.now();

    String ago(DateTime d) {
      final days = DateTime(now.year, now.month, now.day)
          .difference(DateTime(d.year, d.month, d.day))
          .inDays;
      return days == 0
          ? 'bugün'
          : days == 1
              ? 'dün'
              : '$days gün önce';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Yaptıklarım')),
      body: cooked.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                    'Bir tarifi pişirip "Kaydet" dediğinde burada birikir.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                if (most.first.times > 1) ...[
                  const SectionTitle('En çok yaptıkların', icon: '🏆'),
                  SizedBox(
                    height: 108,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final c in most.where((c) => c.times > 1).take(5))
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: SoftCard(
                              padding: const EdgeInsets.all(10),
                              onTap: () => _open(context,
                                  RecipeDetailScreen(recipeId: c.recipe.id)),
                              child: SizedBox(
                                width: 96,
                                child: Column(
                                  children: [
                                    FoodIcon(c.recipe.emoji, size: 40),
                                    Text(c.recipe.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13)),
                                    Text('${c.times} kez',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: Palette.basilDeep)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const SectionTitle('Son pişirdiklerin', icon: '🍳'),
                for (final c in cooked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SoftCard(
                      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                      onTap: () => _open(
                          context, RecipeDetailScreen(recipeId: c.recipe.id)),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: c.photoPath != null && !kIsWeb
                                  ? Image.file(File(c.photoPath!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          IconBubble(c.recipe.emoji, size: 56))
                                  : IconBubble(c.recipe.emoji, size: 56),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.recipe.title,
                                    style: theme.textTheme.titleMedium),
                                Text(
                                    [
                                      '${c.times} kez',
                                      'son: ${ago(c.last)}',
                                      if (c.bestRating != null)
                                        '${c.bestRating}/5',
                                    ].join(' · '),
                                    style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                          ChunkyButton(
                            label: 'Tekrar yap',
                            tone: ChunkyTone.soft,
                            expand: false,
                            height: 40,
                            onPressed: () => _open(context,
                                RecipeDetailScreen(recipeId: c.recipe.id)),
                          ),
                        ],
                      ),
                    ),
                  ),
                Text(
                    state.totalRescuedGrams > 0
                        ? 'Toplam ${state.totalCooks} pişirme, ${formatGrams(state.totalRescuedGrams)} gıda israftan kurtarıldı.'
                        : 'Toplam ${state.totalCooks} pişirme.',
                    style: theme.textTheme.bodySmall),
              ],
            ),
    );
  }
}

/// Tarifi koleksiyonlara ekleme penceresi (tarif sayfasındaki kitap ayracı).
Future<void> showAddToCollection(BuildContext context, String recipeId) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Palette.ground,
    isScrollControlled: true,
    builder: (sheetContext) {
      final state = sheetContext.watch<AppState>();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Koleksiyona ekle',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: state.isFavorite(recipeId),
                onChanged: (_) => state.toggleFavorite(recipeId),
                secondary: const FoodIcon('❤', size: 30),
                title: const Text('Favoriler',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              for (final c in state.collections)
                CheckboxListTile(
                  value: c.recipeIds.contains(recipeId),
                  onChanged: (_) => state.toggleInCollection(c.id, recipeId),
                  secondary: FoodIcon(c.emoji, size: 30),
                  title: Text(c.name,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${c.recipeIds.length} tarif'),
                ),
              const SizedBox(height: 6),
              ChunkyButton(
                label: 'Yeni koleksiyon',
                icon: '🔖',
                tone: ChunkyTone.soft,
                height: 48,
                onPressed: () =>
                    createCollection(sheetContext, firstRecipe: recipeId),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Yeni koleksiyon (ya da [editing] varsa ad/ikon değiştirme) penceresi.
Future<void> createCollection(BuildContext context,
    {String? firstRecipe, UserCollection? editing}) async {
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (_) => _CollectionDialog(editing: editing),
  );
  if (result == null || result.$1.trim().isEmpty || !context.mounted) return;
  final state = context.read<AppState>();
  if (editing != null) {
    state.renameCollection(editing.id, result.$1, result.$2);
  } else {
    state.createCollection(result.$1, result.$2, firstRecipe: firstRecipe);
  }
}

class _CollectionDialog extends StatefulWidget {
  const _CollectionDialog({this.editing});

  final UserCollection? editing;

  @override
  State<_CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<_CollectionDialog> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late String _emoji = widget.editing?.emoji ?? collectionEmojis.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.editing == null ? 'Yeni koleksiyon' : 'Koleksiyonu düzenle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                hintText: 'Misafir menüsü, Diyet haftası…'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in collectionEmojis)
                GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color:
                          e == _emoji ? Palette.basilSoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: e == _emoji ? Palette.basil : Palette.line,
                          width: 2),
                    ),
                    child: FoodIcon(e, size: 28),
                  ),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç')),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (_name.text, _emoji)),
          child: Text(widget.editing == null ? 'Oluştur' : 'Kaydet'),
        ),
      ],
    );
  }
}
