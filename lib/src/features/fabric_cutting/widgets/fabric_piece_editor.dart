import 'package:flutter/material.dart';

import '../models/fabric_piece.dart';

class FabricPieceEditor extends StatelessWidget {
  final int index;
  final FabricPiece piece;
  final ValueChanged<FabricPiece> onChanged;
  final VoidCallback? onDelete;

  const FabricPieceEditor({
    super.key,
    required this.index,
    required this.piece,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text('${index + 1}'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${index + 1}번 원단',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: '원단 삭제',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: piece.name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: '원단명',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => onChanged(piece.copyWith(name: value)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: '폭 cm',
                    value: piece.widthCm,
                    onChanged: (value) =>
                        onChanged(piece.copyWith(widthCm: value)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumberField(
                    label: '길이 cm',
                    value: piece.lengthCm,
                    onChanged: (value) =>
                        onChanged(piece.copyWith(lengthCm: value)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    label: '시접 cm',
                    value: piece.seamAllowanceCm,
                    onChanged: (value) =>
                        onChanged(piece.copyWith(seamAllowanceCm: value)),
                  ),
                ),
                const SizedBox(width: 10),
                _ColorButton(
                  color: piece.color,
                  onTap: () => _showColorSheet(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showColorSheet(BuildContext context) {
    const colors = [
      Color(0xFF1F3F73),
      Color(0xFFF7F4EA),
      Color(0xFF2E7D32),
      Color(0xFFC62828),
      Color(0xFF6A4C93),
      Color(0xFFE6A23C),
      Color(0xFF222222),
      Color(0xFFDDDDDD),
      Color(0xFF7FB3D5),
      Color(0xFFF4A6A6),
      Color(0xFF8D6E63),
      Color(0xFF26A69A),
    ];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('색상 선택', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final color in colors)
                      InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          Navigator.pop(context);
                          onChanged(piece.copyWith(colorValue: color.toARGB32()));
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color.toARGB32() == piece.colorValue
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.black26,
                              width: color.toARGB32() == piece.colorValue ? 3 : 1,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _NumberField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: _fmt(value),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (raw) {
        final parsed = double.tryParse(raw.replaceAll(',', '.'));
        if (parsed != null) onChanged(parsed < 0 ? 0 : parsed);
      },
    );
  }
}

class _ColorButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _ColorButton({
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 86,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.black26),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.palette_outlined, size: 20),
          ],
        ),
      ),
    );
  }
}

String _fmt(double n) => n.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
