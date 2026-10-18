import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum ButtonVariant { primary, secondary, signal, danger }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonVariant variant;
  final IconData? icon;
  final double? width;
  final double height;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.width,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    BorderSide borderSide;

    switch (variant) {
      case ButtonVariant.primary:
        bgColor = AppColors.inkBlack;
        textColor = AppColors.canvasCream;
        borderSide = const BorderSide(color: AppColors.inkBlack, width: 1.5);
        break;
      case ButtonVariant.secondary:
        bgColor = AppColors.white;
        textColor = AppColors.inkBlack;
        borderSide = const BorderSide(color: AppColors.inkBlack, width: 1.5);
        break;
      case ButtonVariant.signal:
        bgColor = AppColors.signalOrange;
        textColor = AppColors.white;
        borderSide = BorderSide.none;
        break;
      case ButtonVariant.danger:
        bgColor = AppColors.statusOfflineRed;
        textColor = AppColors.white;
        borderSide = BorderSide.none;
        break;
    }

    final isInteractive = !isLoading && onPressed != null;

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isInteractive ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          disabledBackgroundColor: bgColor.withValues(alpha: 0.5),
          disabledForegroundColor: textColor.withValues(alpha: 0.6),
          elevation: 0,
          side: borderSide,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: textColor),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
