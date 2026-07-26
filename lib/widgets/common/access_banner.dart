import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import 'app_card.dart';
import 'app_button.dart';

class AccessBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final AccessBannerPreset? preset;
  final String? presetReason;

  const AccessBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.preset,
    this.presetReason,
  });

  factory AccessBanner.fullAccess() {
    return const AccessBanner(
      icon: Icons.check_circle_rounded,
      color: AppColors.telegramGreen,
      title: '',
      message: '',
      preset: AccessBannerPreset.fullAccess,
    );
  }

  factory AccessBanner.freeCategory() {
    return const AccessBanner(
      icon: Icons.lock_open_rounded,
      color: AppColors.telegramGreen,
      title: '',
      message: '',
      preset: AccessBannerPreset.freeCategory,
    );
  }

  factory AccessBanner.limitedAccess({VoidCallback? onPurchase}) {
    return AccessBanner(
      icon: Icons.lock_rounded,
      color: AppColors.telegramBlue,
      title: '',
      message: '',
      preset: AccessBannerPreset.limitedAccess,
      onAction: onPurchase,
    );
  }

  factory AccessBanner.paymentPending({String? message}) {
    return AccessBanner(
      icon: Icons.schedule_rounded,
      color: AppColors.pending,
      title: '',
      message: message ?? '',
      preset: AccessBannerPreset.paymentPending,
    );
  }

  factory AccessBanner.paymentRejected({
    required String reason,
    required VoidCallback onPayNow,
  }) {
    return AccessBanner(
      icon: Icons.error_outline_rounded,
      color: AppColors.telegramRed,
      title: '',
      message: '',
      preset: AccessBannerPreset.paymentRejected,
      presetReason: reason,
      onAction: onPayNow,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    final resolvedTitle = _resolveTitle(settingsProvider);
    final resolvedMessage = _resolveMessage(settingsProvider);
    final resolvedActionText = _resolveActionText(settingsProvider);
    final isLimitedAccess = preset == AccessBannerPreset.limitedAccess;
    final horizontalMargin = ResponsiveValues.sectionPadding(context);
    final verticalMargin = isLimitedAccess
        ? ResponsiveValues.spacingXS(context)
        : ResponsiveValues.spacingS(context);
    final innerPadding = EdgeInsets.symmetric(
      horizontal: isLimitedAccess
          ? ResponsiveValues.spacingL(context)
          : ResponsiveValues.sectionPadding(context),
      vertical: isLimitedAccess
          ? ResponsiveValues.spacingM(context)
          : ResponsiveValues.sectionPadding(context),
    );
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: verticalMargin,
      ),
      child: AppCard.glass(
        child: Padding(
          padding: innerPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(
                  isLimitedAccess
                      ? ResponsiveValues.spacingS(context)
                      : ResponsiveValues.spacingM(context),
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context)),
                ),
                child: Icon(
                  icon,
                  size: isLimitedAccess
                      ? ResponsiveValues.iconSizeM(context)
                      : ResponsiveValues.iconSizeL(context),
                  color: color,
                ),
              ),
              SizedBox(width: ResponsiveValues.spacingM(context)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resolvedTitle,
                      style: (isLimitedAccess
                              ? AppTextStyles.bodyMedium(context)
                              : AppTextStyles.titleSmall(context))
                          .copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(
                      height: isLimitedAccess
                          ? ResponsiveValues.spacingXXS(context)
                          : ResponsiveValues.spacingXS(context),
                    ),
                    Text(
                      resolvedMessage,
                      style: AppTextStyles.bodySmall(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                      maxLines: isLimitedAccess ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (resolvedActionText != null && onAction != null) ...[
                SizedBox(width: ResponsiveValues.spacingM(context)),
                AppButton(
                  label: resolvedActionText,
                  onPressed: onAction,
                  variant: ButtonVariant.secondary,
                  size: ButtonSize.small,
                  expanded: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _resolveTitle(SettingsProvider settingsProvider) {
    if (title.isNotEmpty) return title;
    switch (preset) {
      case AccessBannerPreset.fullAccess:
        return settingsProvider.getAccessBannerFullTitle();
      case AccessBannerPreset.freeCategory:
        return settingsProvider.getAccessBannerFreeTitle();
      case AccessBannerPreset.limitedAccess:
        return settingsProvider.getAccessBannerLimitedTitle();
      case AccessBannerPreset.paymentPending:
        return settingsProvider.getAccessBannerPaymentPendingTitle();
      case AccessBannerPreset.paymentRejected:
        return settingsProvider.getAccessBannerPaymentRejectedTitle();
      case null:
        return title;
    }
  }

  String _resolveMessage(SettingsProvider settingsProvider) {
    if (message.isNotEmpty) return message;
    switch (preset) {
      case AccessBannerPreset.fullAccess:
        return settingsProvider.getAccessBannerFullMessage();
      case AccessBannerPreset.freeCategory:
        return settingsProvider.getAccessBannerFreeMessage();
      case AccessBannerPreset.limitedAccess:
        return settingsProvider.getAccessBannerLimitedMessage();
      case AccessBannerPreset.paymentPending:
        return settingsProvider.getAccessBannerPaymentPendingMessage();
      case AccessBannerPreset.paymentRejected:
        return settingsProvider
            .getAccessBannerPaymentRejectedMessage(presetReason ?? '');
      case null:
        return message;
    }
  }

  String? _resolveActionText(SettingsProvider settingsProvider) {
    if (actionText != null) return actionText;
    switch (preset) {
      case AccessBannerPreset.limitedAccess:
        return settingsProvider.getAccessBannerLimitedAction();
      case AccessBannerPreset.paymentRejected:
        return settingsProvider.getAccessBannerPaymentRejectedAction();
      default:
        return null;
    }
  }
}

enum AccessBannerPreset {
  fullAccess,
  freeCategory,
  limitedAccess,
  paymentPending,
  paymentRejected,
}
