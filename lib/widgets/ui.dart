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
  // Meyveler ve deniz ürünleri (alerji için genişletilen malzeme listesi).
  '🍓': 'strawberry',
  '🥝': 'kiwi_fruit',
  '🍍': 'pineapple',
  '🥭': 'mango',
  '🍑': 'peach',
  '🍒': 'cherries',
  '🍇': 'grapes',
  '🍐': 'pear',
  '🍊': 'tangerine',
  '🍉': 'watermelon',
  '🍈': 'melon',
  '🫐': 'blueberries',
  '🥥': 'coconut',
  '🦪': 'oyster',
  '🦑': 'squid',
  '🐙': 'octopus',
  '🦀': 'crab',
  '🦞': 'lobster',
};

String? iconAssetFor(String emoji) {
  final name = _iconFiles[emoji.replaceAll('️', '')];
  return name == null ? null : 'assets/icons/$name.png';
}

/// Açılışta tüm 3D ikonları arka planda indirip hazırlar. Telefonda (web)
/// ikonlar ancak ekrana gelince tek tek indiriliyordu; artık sayfalara
/// geçildiğinde hazır olurlar. Önce ilk ekran çizilir, sonra yüklenir.
class IconPrecache extends StatefulWidget {
  const IconPrecache({super.key, required this.child});

  final Widget child;

  @override
  State<IconPrecache> createState() => _IconPrecacheState();
}

class _IconPrecacheState extends State<IconPrecache> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final name in _iconFiles.values.toSet()) {
        // Hata (ör. eksik dosya) açılışı bozmasın.
        precacheImage(AssetImage('assets/icons/$name.png'), context,
            onError: (_, __) {});
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        // Henüz hazır değilse birden belirmek yerine yumuşakça görünür.
        frameBuilder: (_, child, frame, sync) => sync
            ? child
            : AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: child));
  }
}

/// Yumuşak renkli daire içinde ikon.
class IconBubble extends StatelessWidget {
  const IconBubble(this.emoji, {super.key, this.size = 56, this.color});

  final String emoji;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: color ?? Palette.sand,
          borderRadius: BorderRadius.circular(size * 0.32)),
      alignment: Alignment.center,
      child: FoodIcon(emoji, size: size * 0.62),
    );
  }
}

/// Uygulamanın kendi simgeleri (zamanlayıcı, kalori, liste...) için ince çizgi
/// ikonlar. Eskiden her yerde 3D emoji vardı; yemek ve malzeme dışındaki
/// emojiler burada çizgi ikona çevrilir. Karşılığı olmayan (yemek) emojiler
/// 3D ikon olarak kalır.
const _symbols = <String, IconData>{
  '⏱': Icons.schedule_rounded,
  '⏲': Icons.timer_outlined,
  '⏳': Icons.hourglass_bottom_rounded,
  '▶': Icons.play_circle_outline_rounded,
  '⚠': Icons.warning_amber_rounded,
  '✅': Icons.check_circle_outline_rounded,
  '✨': Icons.auto_awesome_outlined,
  '❤': Icons.favorite_rounded,
  '⭐': Icons.star_outline_rounded,
  '🌱': Icons.eco_outlined,
  '🌳': Icons.park_outlined,
  '🎉': Icons.celebration_outlined,
  '🎙': Icons.mic_none_rounded,
  '🎬': Icons.smart_display_outlined,
  '🏅': Icons.military_tech_outlined,
  '🏠': Icons.home_outlined,
  '🏆': Icons.emoji_events_outlined,
  '💡': Icons.lightbulb_outline_rounded,
  '💪': Icons.fitness_center_rounded,
  '💰': Icons.savings_outlined,
  '📊': Icons.insights_outlined,
  '📝': Icons.edit_note_rounded,
  '📥': Icons.download_rounded,
  '📦': Icons.qr_code_scanner_rounded,
  '📲': Icons.ios_share_rounded,
  '📷': Icons.photo_camera_outlined,
  '📋': Icons.content_paste_rounded,
  '📱': Icons.smartphone_rounded,
  '🔄': Icons.sync_alt_rounded,
  '🔌': Icons.kitchen_outlined,
  '🔒': Icons.lock_outline_rounded,
  '🔗': Icons.link_rounded,
  '🔥': Icons.local_fire_department_outlined,
  '🔪': Icons.content_cut_rounded,
  '🔔': Icons.notifications_none_rounded,
  '🔖': Icons.bookmark_border_rounded,
  '🗂': Icons.folder_copy_outlined,
  '🗑': Icons.delete_outline_rounded,
  '🗓': Icons.calendar_month_outlined,
  '🗒': Icons.sticky_note_2_outlined,
  '🛒': Icons.shopping_cart_outlined,
  '🤏': Icons.opacity_rounded,
  '🤔': Icons.help_outline_rounded,
  '🧺': Icons.shopping_basket_outlined,
  '🧾': Icons.receipt_long_outlined,
  '🧑‍🍳': Icons.restaurant_menu_rounded,
  '⚖': Icons.balance_rounded,
  '🌐': Icons.public_rounded,
  '🎯': Icons.track_changes_rounded,
  '☀': Icons.wb_sunny_outlined,
  '⚡': Icons.bolt_rounded,
  '🪶': Icons.spa_outlined,
  '🌀': Icons.blender_outlined,
  '💨': Icons.air_rounded,
  '♨': Icons.whatshot_outlined,
  '🥄': Icons.soup_kitchen_outlined,
  '🍤': Icons.outdoor_grill_outlined,
  '🍳': Icons.egg_alt_outlined,
  '🍽': Icons.restaurant_rounded,
  '🍲': Icons.soup_kitchen_outlined,
  '🥗': Icons.eco_outlined,
  '🥨': Icons.cookie_outlined,
  '🍰': Icons.cake_outlined,
  '👋': Icons.waving_hand_outlined,
};

/// Uygulama simgesi: karşılığı varsa çizgi ikon, yoksa 3D yemek ikonu.
class Sym extends StatelessWidget {
  const Sym(this.emoji, {super.key, this.size = 24, this.color});

  final String emoji;
  final double size;

  /// Verilmezse koyu yeşil.
  final Color? color;

  static IconData? iconFor(String emoji) => _symbols[emoji.replaceAll('️', '')];

  @override
  Widget build(BuildContext context) {
    final icon = iconFor(emoji);
    if (icon == null) return FoodIcon(emoji, size: size);
    // Çizgi ikonlar emojiden iri görünür; aynı kutuya biraz küçük çizilir.
    return SizedBox(
      width: size,
      height: size,
      child: Icon(icon, size: size * 0.82, color: color ?? Palette.accent),
    );
  }
}

/// Nötr zeminli yuvarlak kare içinde uygulama simgesi.
class SymBubble extends StatelessWidget {
  const SymBubble(this.emoji,
      {super.key, this.size = 56, this.color, this.iconColor});

  final String emoji;
  final double size;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: color ?? Palette.sand,
          borderRadius: BorderRadius.circular(size * 0.32)),
      alignment: Alignment.center,
      child: Sym(emoji, size: size * 0.52, color: iconColor),
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
      ChunkyTone.butter => _ToneColors(Palette.sand, Palette.ink),
      // Hafif: açık zemin, ince çerçeve.
      ChunkyTone.soft =>
        _ToneColors(Palette.surface, Palette.accent, border: Palette.lineDeep),
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
            child: Sym(widget.icon!, size: small ? 20 : 24, color: fg),
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
    this.color,
    this.borderColor,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  final Widget child;
  final Color? color;
  final Color? borderColor;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Palette.surface;
    final border = borderColor ?? Palette.line;
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
        color: bg,
        shape: RoundedRectangleBorder(
            borderRadius: radius, side: BorderSide(color: border, width: 1)),
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
      this.color,
      this.fg,
      this.bordered = true,
      this.border,
      this.dense = false});

  final String text;
  final String? icon;
  final Color? color;
  final Color? fg;
  final bool bordered;
  final Color? border;

  /// Kartlarda yan yana birkaç etiket sığsın diye küçük boy.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Palette.surface;
    final textColor = fg ?? Palette.ink;
    final edge = border ?? Palette.line;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: bordered ? Border.all(color: edge, width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Sym(icon!, size: dense ? 15 : 18, color: Palette.inkSoft),
            SizedBox(width: dense ? 4 : 5),
          ],
          Text(text,
              style: TextStyle(
                  fontFamily: Fonts.body,
                  fontWeight: FontWeight.w700,
                  fontSize: dense ? 12 : 13,
                  color: textColor)),
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
            Sym(icon!, size: 24),
            const SizedBox(width: 10),
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
      this.color,
      this.track,
      this.height = 12});

  final double value;

  /// Verilmezse yazı yeşili (koyu temada açık nane; koyu zeminde görünsün).
  final Color? color;
  final Color? track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final trackColor = track ?? Palette.basilSoft;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: trackColor)),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0).toDouble(),
              child: Container(
                decoration: BoxDecoration(
                  color: color ?? Palette.accent,
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
    // Hedef aşıldıysa fazlası sonda "+2" rozeti olarak (5/3 → 3 dolu + "+2").
    final extra = done - goal;
    final slots = goal + (extra > 0 ? 1 : 0);
    return LayoutBuilder(builder: (context, c) {
      final fit =
          c.maxWidth.isFinite ? (c.maxWidth - 8 * (slots - 1)) / slots : size;
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
                        style: TextStyle(
                            fontFamily: Fonts.display,
                            fontWeight: FontWeight.w800,
                            color: Palette.lineDeep,
                            fontSize: 16)),
              ),
            ),
          if (extra > 0)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Semantics(
                label: 'Hedefin $extra fazlası',
                child: Container(
                  height: s,
                  constraints: BoxConstraints(minWidth: s),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Palette.butter,
                    borderRadius: BorderRadius.circular(s),
                  ),
                  alignment: Alignment.center,
                  child: Text('+$extra',
                      style: TextStyle(
                          fontFamily: Fonts.display,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: s * 0.38)),
                ),
              ),
            ),
        ],
      );
    });
  }
}
