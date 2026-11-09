import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pantry_item.dart';
import '../theme/palette.dart';
import '../utils/format.dart';

class _RoundButton extends StatelessWidget {
  const _RoundButton(
      {required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled ? Palette.basilSoft : Palette.line,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon,
                size: 22, color: enabled ? Palette.basilDeep : Palette.inkSoft),
          ),
        ),
      ),
    );
  }
}

/// Adetle sayılan malzemeler için − / + (1'in altında yarımlık adımlar).
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final double value;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final down = value <= 1 ? 0.5 : 1.0;
    final up = value < 1 ? 0.5 : 1.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(
          icon: Icons.remove_rounded,
          tooltip: 'Azalt',
          onPressed:
              value > 0.5 ? () => onChanged(math.max(0.5, value - down)) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('${formatFraction(value, step: 0.5)} $label',
              style: TextStyle(
                  fontFamily: Fonts.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Palette.ink)),
        ),
        _RoundButton(
          icon: Icons.add_rounded,
          tooltip: 'Artır',
          onPressed: () => onChanged(value + up),
        ),
      ],
    );
  }
}

/// Kesin miktar bilinmediğinde Bol / Biraz / Az.
class LevelSelector extends StatelessWidget {
  const LevelSelector(
      {super.key, required this.value, required this.onChanged});

  final ApproxLevel value;
  final ValueChanged<ApproxLevel> onChanged;

  static const _dots = {
    ApproxLevel.bol: Palette.basil,
    ApproxLevel.biraz: Palette.butterDeep,
    ApproxLevel.az: Palette.tomato,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final level in ApproxLevel.values)
          Semantics(
            selected: level == value,
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: level == value ? _dots[level]! : Palette.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: level == value ? _dots[level]! : Palette.line,
                      width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: level == value ? Colors.white : _dots[level],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(level.label,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: level == value
                                ? (level == ApproxLevel.biraz
                                    ? Palette.ink
                                    : Colors.white)
                                : Palette.ink)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
