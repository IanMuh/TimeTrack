import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import 'activity_colors.dart';

class ActivityColorPicker extends StatelessWidget {
  const ActivityColorPicker({
    required this.selectedColor,
    required this.onColorChanged,
    this.palette = activityPalette,
    super.key,
  });

  final int selectedColor;
  final ValueChanged<int> onColorChanged;
  final List<int> palette;

  @override
  Widget build(BuildContext context) {
    final color = Color(selectedColor);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final colorValue in palette)
              IconButton(
                tooltip: AppLocalizations.of(context)!
                    .selectColorTooltip(_formatHexColor(colorValue)),
                onPressed: () => onColorChanged(colorValue),
                icon: Icon(
                  selectedColor == colorValue
                      ? Icons.check_circle
                      : Icons.circle,
                  color: Color(colorValue),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: const Icon(Icons.tune),
          title: Text(AppLocalizations.of(context)!.rgbTuner),
          subtitle: Text(_formatHexColor(selectedColor)),
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _formatHexColor(selectedColor),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RgbChannelControl(
              label: 'R',
              value: _redOf(selectedColor),
              color: Colors.red,
              onChanged: (value) => onColorChanged(
                _withRgb(selectedColor, red: value),
              ),
            ),
            _RgbChannelControl(
              label: 'G',
              value: _greenOf(selectedColor),
              color: Colors.green,
              onChanged: (value) => onColorChanged(
                _withRgb(selectedColor, green: value),
              ),
            ),
            _RgbChannelControl(
              label: 'B',
              value: _blueOf(selectedColor),
              color: Colors.blue,
              onChanged: (value) => onColorChanged(
                _withRgb(selectedColor, blue: value),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RgbChannelControl extends StatefulWidget {
  const _RgbChannelControl({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  State<_RgbChannelControl> createState() => _RgbChannelControlState();
}

class _RgbChannelControlState extends State<_RgbChannelControl> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant _RgbChannelControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != widget.value.toString()) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final slider = Slider(
          label: '${widget.label} ${widget.value}',
          min: 0,
          max: 255,
          divisions: 255,
          value: widget.value.toDouble(),
          activeColor: widget.color,
          onChanged: (value) => widget.onChanged(value.round()),
        );
        final input = SizedBox(
          width: 86,
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              labelText: widget.label,
              prefixIcon: Icon(Icons.tag, color: widget.color),
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value);
              if (parsed == null) {
                return;
              }
              widget.onChanged(parsed.clamp(0, 255));
            },
          ),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              input,
              slider,
            ],
          );
        }
        return Row(
          children: [
            input,
            const SizedBox(width: 12),
            Expanded(child: slider),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

String _formatHexColor(int color) {
  final rgb = color & 0x00ffffff;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

int _redOf(int color) => (color >> 16) & 0xff;

int _greenOf(int color) => (color >> 8) & 0xff;

int _blueOf(int color) => color & 0xff;

int _withRgb(
  int color, {
  int? red,
  int? green,
  int? blue,
}) {
  final nextRed = (red ?? _redOf(color)).clamp(0, 255).toInt();
  final nextGreen = (green ?? _greenOf(color)).clamp(0, 255).toInt();
  final nextBlue = (blue ?? _blueOf(color)).clamp(0, 255).toInt();
  return 0xff000000 | (nextRed << 16) | (nextGreen << 8) | nextBlue;
}
