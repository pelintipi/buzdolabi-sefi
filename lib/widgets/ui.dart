import 'package:flutter/material.dart';

import '../theme/palette.dart';

// Emoji → 3D ikon dosyası (assets/icons/<ad>.png, Fluent UI Emoji).
const _iconFiles = {
  '🥛': 'glass_of_milk',
  '🥣': 'bowl_with_spoon',
  '🧀': 'cheese_wedge',
  '🧈': 'butter',
  '🥚': 'egg',
  '🍗': 'poultry_leg',
  '🥩': 'cut_of_meat',
  '🌭': 'hot_dog',
  '🐟': 'fish',
  '🧅': 'onion',
  '🧄': 'garlic',
  '🍅': 'tomato',
  '🫑': 'bell_pepper',
  '🌶': 'hot_pepper',
  '🥔': 'potato',
  '🥕': 'carrot',
  '🥬': 'leafy_green',
  '🥒': 'cucumber',
  '🍆': 'eggplant',
  '🍄': 'mushroom',
  '🌿': 'herb',
  '🍋': 'lemon',
  '🍌': 'banana',
  '🍚': 'cooked_rice',
  '🌾': 'sheaf_of_rice',
  '🍝': 'spaghetti',
  '🫘': 'beans',
  '🍞': 'bread',
  '🫓': 'flatbread',
  '🍯': 'honey_pot',
  '🌰': 'chestnut',
  '🥜': 'peanuts',
  '🧂': 'salt',
  '🫒': 'olive',
  '🛢': 'oil_drum',
  '🥫': 'canned_food',
  '🍳': 'cooking',
  '🥤': 'cup_with_straw',
  '🥗': 'green_salad',
  '🌯': 'burrito',
  '🥪': 'sandwich',
  '🍟': 'french_fries',
  '🥘': 'shallow_pan_of_food',
  '🍲': 'pot_of_food',
  '🍜': 'steaming_bowl',
  '⏱': 'stopwatch',
  '💪': 'flexed_biceps',
  '💰': 'money_bag',
  '🔥': 'fire',
  '🥑': 'avocado',
  '📊': 'bar_chart',
  '✅': 'check_mark_button',
  '🤏': 'pinching_hand',
  '🔄': 'counterclockwise_arrows_button',
  '🛒': 'shopping_cart',
  '🎉': 'party_popper',
  '🤔': 'thinking_face',
  '⏳': 'hourglass_not_done',
  '🌱': 'seedling',
  '🌳': 'deciduous_tree',
  '🍽': 'fork_and_knife_with_plate',
  '⚠': 'warning',
  '💡': 'light_bulb',
  '⏲': 'timer_clock',
  '🔪': 'kitchen_knife',
  '♨': 'hot_springs',
  '🍤': 'fried_shrimp',
  '🥄': 'spoon',
  '🌀': 'cyclone',
  '💨': 'dashing_away',
  '🔌': 'electric_plug',
  '🏅': 'sports_medal',
  '⭐': 'star',
  '🏠': 'house',
  '🏆': 'trophy',
  '🧺': 'basket',
  '❤': 'red_heart',
  '👋': 'waving_hand',
  '🧑‍🍳': 'cook',
  '🥞': 'pancakes',
  '🍰': 'shortcake',
  '🥯': 'bagel',
  '🍬': 'candy',
  '🫙': 'jar',
  '⚡': 'high_voltage',
  '🪶': 'feather',
  '📝': 'memo',
  '✨': 'sparkles',
  '🗒': 'spiral_notepad',
  '📦': 'package',
  '🥦': 'broccoli',
  '🫛': 'pea_pod',
  '🌽': 'ear_of_corn',
  '🍎': 'red_apple',
  '🍫': 'chocolate_bar',
  '🍮': 'custard',
  '🥧': 'pie',
  '🎬': 'clapper_board',
  '📲': 'mobile_phone_with_arrow',
  '🔗': 'link',
  '📋': 'clipboard',
  '🗑': 'wastebasket',
  '📥': 'inbox_tray',
  '▶': 'play_button',
  '☀': 'sun',
  '🧾': 'receipt',
  '🗓': 'spiral_calendar',
  '🎙': 'studio_microphone',
  '⚖': 'balance_scale',
  '🌐': 'globe_with_meridians',
  '🔒': 'locked',
  '📱': 'mobile_phone',
  '🔔': 'bell',
  '📷': 'camera',
  '🎯': 'bullseye',
  '🥨': 'pretzel',
  '🔖': 'bookmark',
  '🗂': 'card_index_dividers',
};

String? iconAssetFor(String emoji) {
  final name = _iconFiles[emoji.replaceAll('️', '')];
  return name == null ? null : 'assets/icons/$name.png';
}

/// Emojiyi 3D ikon olarak çizer; ikonu olmayan emojiler yazı olarak kalır.
class FoodIcon extends StatelessWidget {
  const FoodIcon(this.emoji, {super.key, this.size = 28});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = iconAssetFor(emoji);
    if (asset == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
            child:
                Text(emoji, style: TextStyle(fontSize: size * 0.8, height: 1))),
      );
    }
    return Image.asset(asset,
        width: size, height: size, filterQuality: FilterQuality.medium);
  }
}

/// Yumuşak renkli daire içinde ikon.
class IconBubble extends StatelessWidget {
  const IconBubble(this.emoji,
      {super.key, this.size = 56, this.color = Palette.basilSoft});

  final String emoji;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(size * 0.32)),
      alignment: Alignment.center,
      child: FoodIcon(emoji, size: size * 0.66),
    );
  }
}

enum ChunkyTone { primary, accent, butter, soft }

class _ToneColors {
  const _ToneColors(this.face, this.fg, {this.border});

  final Color face;
  final Color fg;
  final Color? border;
}

_ToneColors _tone(ChunkyTone t) => switch (t) {
      // Ana eylem: koyu orman yeşili hap (tasarımdaki "Ne pişirsem?", "Ekle").
      ChunkyTone.primary => const _ToneColors(Palette.basil, Colors.white),
      ChunkyTone.accent => const _ToneColors(Palette.basil, Colors.white),
      // İkincil: kum tonu.
      ChunkyTone.butter => const _ToneColors(Palette.sand, Palette.ink),
      // Hafif: açık zemin, ince çerçeve.
      ChunkyTone.soft => const _ToneColors(Palette.surface, Palette.basil,
          border: Palette.lineDeep),
    };

/// Düz, hap şeklinde buton; basınca hafifçe küçülür.
/// (Adı eskiden altında kalınlık olan "tok" butondan kaldı.)
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconData,
    this.tone = ChunkyTone.primary,
    this.expand = true,
    this.height = 54,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Soldaki ikon için emoji (3D ikon olarak çizilir).
  final String? icon;

  /// Ya da çizgi ikon (ör. arama büyüteci).
  final IconData? iconData;
  final ChunkyTone tone;
  final bool expand;
  final double height;
  final String? tooltip;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final c = _tone(widget.tone);
    final face = enabled ? c.face : Palette.line;
    final fg = enabled ? c.fg : Palette.inkSoft;
    final small = widget.height < 48;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.iconData != null) ...[
          Icon(widget.iconData, size: small ? 20 : 24, color: fg),
          SizedBox(width: small ? 6 : 10),
        ] else if (widget.icon != null) ...[
          Opacity(
            opacity: enabled ? 1 : 0.5,
            child: FoodIcon(widget.icon!, size: small ? 20 : 26),
          ),
          SizedBox(width: small ? 6 : 10),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: Fonts.display,
              fontWeight: FontWeight.w700,
              fontSize: small ? 14.5 : 17,
              height: 1.1,
              letterSpacing: -0.2,
              color: fg,
            ),
          ),
        ),
      ],
    );

    Widget button = Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: () => _set(false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            height: widget.height,
            padding: EdgeInsets.symmetric(horizontal: small ? 16 : 24),
            decoration: BoxDecoration(
              color: _down ? Color.lerp(face, Colors.black, 0.08) : face,
              borderRadius: BorderRadius.circular(999),
              border: c.border != null && enabled
                  ? Border.all(color: c.border!, width: 1.2)
                  : null,
            ),
            child: content,
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip, child: button);
    }
    return widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

/// Yumuşak, kenarsız kart; altında hafif gölge. [color] verilirse renkli zemin.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.color = Palette.surface,
    this.borderColor = Palette.line,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  final Widget child;
  final Color color;
  final Color borderColor;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(26);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F3A2A1E), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: borderColor, width: 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Küçük bilgi etiketi: ikon + yazı.
class Pill extends StatelessWidget {
  const Pill(this.text,
      {super.key,
      this.icon,
      this.color = Palette.surface,
      this.fg = Palette.ink,
      this.border = Palette.line,
      this.dense = false});

  final String text;
  final String? icon;
  final Color color;
  final Color fg;
  final Color? border;

  /// Kartlarda yan yana birkaç etiket sığsın diye küçük boy.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: border == null ? null : Border.all(color: border!, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            FoodIcon(icon!, size: dense ? 15 : 18),
            SizedBox(width: dense ? 4 : 5),
          ],
          Text(text,
              style: TextStyle(
                  fontFamily: Fonts.body,
                  fontWeight: FontWeight.w700,
                  fontSize: dense ? 12 : 13,
                  color: fg)),
        ],
      ),
    );
  }
}

/// Bölüm başlığı: 3D ikon + başlık.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.icon, this.trailing});

  final String text;
  final String? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            FoodIcon(icon!, size: 30),
            const SizedBox(width: 8),
          ],
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Kalın, yuvarlak ilerleme çubuğu.
class ChunkyProgress extends StatelessWidget {
  const ChunkyProgress(
      {super.key,
      required this.value,
      this.color = Palette.basil,
      this.track = Palette.basilSoft,
      this.height = 12});

  final double value;
  final Color color;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track)),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0).toDouble(),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Haftalık hedefi (3 pişirme) üç yuvayla gösterir.
class WeeklySlots extends StatelessWidget {
  const WeeklySlots(
      {super.key, required this.done, required this.goal, this.size = 40});

  final int done;
  final int goal;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Hedef 5-7 olunca yuvalar sığsın diye genişliğe göre küçülür.
    return LayoutBuilder(builder: (context, c) {
      final fit =
          c.maxWidth.isFinite ? (c.maxWidth - 8 * (goal - 1)) / goal : size;
      final s = fit < size ? fit : size;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < goal; i++)
            Padding(
              padding: EdgeInsets.only(right: i == goal - 1 ? 0 : 8),
              child: Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  color: i < done ? Palette.butterSoft : Palette.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: i < done ? Palette.butter : Palette.lineDeep,
                      width: 2),
                ),
                alignment: Alignment.center,
                child: i < done
                    ? FoodIcon('🍳', size: s * 0.6)
                    : Text('${i + 1}',
                        style: const TextStyle(
                            fontFamily: Fonts.display,
                            fontWeight: FontWeight.w800,
                            color: Palette.lineDeep,
                            fontSize: 16)),
              ),
            ),
        ],
      );
    });
  }
}
