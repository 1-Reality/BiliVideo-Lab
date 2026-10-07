import 'package:PiliBro/utils/extension/num_ext.dart';
import 'package:material_ui/material_ui.dart';

class DualSliderDialog extends StatefulWidget {
  final double value1;
  final double value2;
  final Widget title;
  final Widget description1;
  final Widget description2;
  final double min;
  final double max;
  final int? divisions;
  final String suffix;
  final int precise;
  final bool enableInput;

  const DualSliderDialog({
    super.key,
    required this.value1,
    required this.value2,
    required this.description1,
    required this.description2,
    required this.title,
    required this.min,
    required this.max,
    this.divisions,
    this.suffix = '',
    this.precise = 1,
    this.enableInput = false,
  });

  @override
  State<DualSliderDialog> createState() => _DualSliderDialogState();
}

class _DualSliderDialogState extends State<DualSliderDialog> {
  late double _tempValue1;
  late double _tempValue2;
  TextEditingController? _input1;
  TextEditingController? _input2;

  @override
  void initState() {
    super.initState();
    _tempValue1 = widget.value1;
    _tempValue2 = widget.value2;
    if (widget.enableInput) {
      _input1 = TextEditingController(text: _tempValue1.toString());
      _input2 = TextEditingController(text: _tempValue2.toString());
    }
  }

  @override
  void dispose() {
    _input1?.dispose();
    _input2?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: widget.title,
      contentPadding: const EdgeInsets.only(
        top: 20,
        left: 8,
        right: 8,
        bottom: 8,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: .min,
          children: [
            widget.description1,
            Builder(
              builder: (context) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.enableInput)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _input1,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: InputDecoration(suffixText: widget.suffix),
                          onSubmitted: (value) {
                            _tempValue1 = double.parse(value);
                            (context as Element).markNeedsBuild();
                          },
                        ),
                      ),
                    Slider(
                      value: widget.enableInput
                          ? _tempValue1.clamp(widget.min, widget.max).toDouble()
                          : _tempValue1,
                      min: widget.min,
                      max: widget.max,
                      divisions: widget.divisions,
                      label:
                          '${_tempValue1.toStringAsFixed(widget.precise)}${widget.suffix}',
                      onChanged: (double value) {
                        _tempValue1 = value.toPrecision(widget.precise);
                        _input1?.text = _tempValue1.toString();
                        (context as Element).markNeedsBuild();
                      },
                    ),
                  ],
                );
              },
            ),
            widget.description2,
            Builder(
              builder: (context) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.enableInput)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _input2,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: InputDecoration(suffixText: widget.suffix),
                          onSubmitted: (value) {
                            _tempValue2 = double.parse(value);
                            (context as Element).markNeedsBuild();
                          },
                        ),
                      ),
                    Slider(
                      value: widget.enableInput
                          ? _tempValue2.clamp(widget.min, widget.max).toDouble()
                          : _tempValue2,
                      min: widget.min,
                      max: widget.max,
                      divisions: widget.divisions,
                      label:
                          '${_tempValue2.toStringAsFixed(widget.precise)}${widget.suffix}',
                      onChanged: (double value) {
                        _tempValue2 = value.toPrecision(widget.precise);
                        _input2?.text = _tempValue2.toString();
                        (context as Element).markNeedsBuild();
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: Text(
            '取消',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, (
            widget.enableInput ? double.parse(_input1!.text) : _tempValue1,
            widget.enableInput ? double.parse(_input2!.text) : _tempValue2,
          )),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
