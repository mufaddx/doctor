import 'package:flutter/material.dart';

enum AppButtonVariant { filled, outlined, text }

/// Single button used across the app so loading and disabled states behave
/// identically everywhere. The spinner replaces the label in place, which
/// keeps the button from resizing mid-request.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.isLoading = false,
    this.icon,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final bool disabled = isLoading || onPressed == null;

    final Widget child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: variant == AppButtonVariant.filled
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
            ),
          )
        : Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    final Widget button = switch (variant) {
      AppButtonVariant.filled => ElevatedButton(
        onPressed: disabled ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.outlined => OutlinedButton(
        onPressed: disabled ? null : onPressed,
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: disabled ? null : onPressed,
        child: child,
      ),
    };

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
