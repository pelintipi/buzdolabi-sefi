import 'package:flutter/material.dart';

/// Tek metin kutulu pencere. Metin kutusunun denetleyicisini pencerenin kendisi
/// tutar; pencere kapanma animasyonu bitince bırakılır (önceden kapanırken
/// silinen denetleyici "used after being disposed" hatası veriyordu).
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String confirm,
  String? hint,
  String initial = '',
  int minLines = 1,
  int maxLines = 1,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TextPrompt(
        title: title,
        confirm: confirm,
        hint: hint,
        initial: initial,
        minLines: minLines,
        maxLines: maxLines,
      ),
    );

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.confirm,
    required this.hint,
    required this.initial,
    required this.minLines,
    required this.maxLines,
  });

  final String title;
  final String confirm;
  final String? hint;
  final String initial;
  final int minLines;
  final int maxLines;

  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final single = widget.maxLines == 1;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: single ? (v) => Navigator.pop(context, v) : null,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _controller.text),
            child: Text(widget.confirm)),
      ],
    );
  }
}
