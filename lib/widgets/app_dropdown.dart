import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Global custom dropdown: styled trigger + custom overlay menu (no default Material menu).
class AppDropdown extends StatefulWidget {
  const AppDropdown({
    super.key,
    required this.hint,
    required this.items,
    this.value,
    this.onChanged,
    this.suffixIcon,
  });

  static const double _inputRadius = 12;

  final String hint;
  final List<String> items;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final IconData? suffixIcon;

  @override
  State<AppDropdown> createState() => _AppDropdownState();
}

class _AppDropdownState extends State<AppDropdown> {
  OverlayEntry? _overlayEntry;

  void _openMenu() {
    if (widget.items.isEmpty) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;

    final size = renderObject.size;
    final offset = renderObject.localToGlobal(Offset.zero);
    final overlay = Overlay.of(context);
    final top = offset.dy + size!.height + 4;
    final left = offset.dx;
    final width = size.width;

    _overlayEntry = OverlayEntry(
      builder: (context) => _DropdownOverlay(
        left: left,
        top: top,
        width: width,
        items: widget.items,
        selectedValue: (widget.value != null && widget.items.contains(widget.value))
            ? widget.value!
            : null,
        onSelected: (item) {
          widget.onChanged?.call(item);
          _closeMenu();
        },
        onDismiss: _closeMenu,
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _closeMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveValue = (widget.value != null && widget.items.contains(widget.value))
        ? widget.value!
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(AppDropdown._inputRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: _openMenu,
        borderRadius: BorderRadius.circular(AppDropdown._inputRadius),
        child: Row(
          children: [
            Expanded(
              child: Text(
                effectiveValue ?? widget.hint,
                style: TextStyle(
                  color: effectiveValue != null ? AppColors.dark : AppColors.from_heading,
                  fontSize: 14,
                ),
              ),
            ),
            if (widget.suffixIcon != null) ...[
              Icon(widget.suffixIcon, size: 20, color: AppColors.from_heading),
              const SizedBox(width: 8),
            ],
            Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.grey, size: 22),
          ],
        ),
      ),
    );
  }
}

class _DropdownOverlay extends StatelessWidget {
  const _DropdownOverlay({
    required this.left,
    required this.top,
    required this.width,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
    required this.onDismiss,
  });

  final double left;
  final double top;
  final double width;
  final List<String> items;
  final String? selectedValue;
  final ValueChanged<String> onSelected;
  final VoidCallback onDismiss;

  static const double _menuRadius = 12;
  static const double _maxHeight = 240;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: const SizedBox.expand(),
        ),
        Positioned(
          left: left,
          top: top,
          width: width,
          child: Material(
            elevation: 8,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(_menuRadius),
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: _maxHeight),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(_menuRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_menuRadius),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = item == selectedValue;
                    return InkWell(
                      onTap: () => onSelected(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Text(
                          item,
                          style: TextStyle(
                            color: isSelected ? AppColors.mainAppColor : AppColors.dark,
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
