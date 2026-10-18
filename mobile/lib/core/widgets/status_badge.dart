import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool isVerification;

  const StatusBadge({
    super.key,
    required this.status,
    this.isVerification = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    String label = status.replaceAll('_', ' ');

    if (isVerification) {
      switch (status.toUpperCase()) {
        case 'APPROVED':
          bg = AppColors.statusActiveGreenLight;
          text = AppColors.statusActiveGreen;
          label = 'VERIFIED';
          break;
        case 'REJECTED':
          bg = AppColors.statusOfflineRedLight;
          text = AppColors.statusOfflineRed;
          label = 'REJECTED';
          break;
        case 'PENDING':
        default:
          bg = AppColors.statusPendingAmberLight;
          text = AppColors.statusPendingAmber;
          label = 'PENDING';
          break;
      }
    } else {
      switch (status.toUpperCase()) {
        case 'ACTIVE':
          bg = AppColors.statusActiveGreenLight;
          text = AppColors.statusActiveGreen;
          label = 'ACTIVE';
          break;
        case 'OFFLINE':
          bg = AppColors.statusOfflineRedLight;
          text = AppColors.statusOfflineRed;
          label = 'OFFLINE';
          break;
        case 'UNDER_MAINTENANCE':
          bg = AppColors.statusPendingAmberLight;
          text = AppColors.statusPendingAmber;
          label = 'MAINTENANCE';
          break;
        case 'DAMAGED':
          bg = AppColors.statusOfflineRedLight;
          text = AppColors.statusOfflineRed;
          label = 'DAMAGED';
          break;
        default:
          bg = AppColors.softBone;
          text = AppColors.charcoal;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: text,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
