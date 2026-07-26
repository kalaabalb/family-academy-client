import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;

import '../../providers/settings_provider.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_card.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';
import '../../utils/external_link_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with BaseScreenMixin<SupportScreen>, TickerProviderStateMixin {
  late TabController _tabController;
  bool _hasError = false;
  String? _errorMessage;
  final List<RefreshController> _refreshControllers = [];

  late AnimationController _pulseAnimationController;
  late SettingsProvider _settingsProvider;
  bool _didInitialize = false;

  @override
  String get screenTitle => _didInitialize
      ? _settingsProvider.getSupportScreenTitle()
      : AppStrings.support;

  @override
  String? get screenSubtitle => isRefreshing
      ? AppStrings.refreshing
      : (isOffline
          ? AppStrings.offlineMode
          : (_didInitialize
              ? _settingsProvider.getSupportScreenSubtitle()
              : AppStrings.getHelp));

  @override
  bool get isLoading => false;

  @override
  bool get hasCachedData => true;

  @override
  dynamic get errorMessage => _hasError ? _errorMessage : null;

  // ✅ Shimmer type for support screen
  @override
  ShimmerType get shimmerType => ShimmerType.contactCard;

  @override
  int get shimmerItemCount => 3;

  @override
  Widget? get appBarLeading => IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: AppColors.getTextPrimary(context),
        ),
        onPressed: () => context.pop(),
      );

  @override
  void initState() {
    super.initState();

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: 1.seconds,
    )..repeat(reverse: true);

    _tabController = TabController(length: 2, vsync: this);
    _refreshControllers.addAll([
      RefreshController(),
      RefreshController(),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) return;

    _settingsProvider = context.read<SettingsProvider>();
    _didInitialize = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        await _settingsProvider.loadContactSettings();
      } catch (e) {
        if (!mounted) return;
        final hasVisibleSupportData =
            _settingsProvider.getContactInfoList().isNotEmpty;
        setState(() {
          _hasError = !hasVisibleSupportData;
          _errorMessage =
              hasVisibleSupportData ? null : getUserFriendlyErrorMessage(e);
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseAnimationController.dispose();
    for (var controller in _refreshControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Future<void> onRefresh() async {
    await _refreshTab(_tabController.index);
  }

  Future<void> _refreshTab(int tabIndex) async {
    if (isOffline) {
      SnackbarService().showOffline(context);
      _refreshControllers[tabIndex].refreshFailed();
      return;
    }

    try {
      await _settingsProvider.getAllSettings();
      await _settingsProvider.loadContactSettings(forceRefresh: true);

      _refreshControllers[tabIndex].refreshCompleted();
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });
    } catch (e) {
      final hasVisibleSupportData =
          _settingsProvider.getContactInfoList().isNotEmpty;

      setState(() {
        _hasError = !hasVisibleSupportData;
        _errorMessage =
            hasVisibleSupportData ? null : getUserFriendlyErrorMessage(e);
      });
      _refreshControllers[tabIndex].refreshFailed();
      if (hasVisibleSupportData) {
        SnackbarService().showInfo(
          context,
          _settingsProvider.getSupportRefreshSavedMessage(),
        );
      } else {
        SnackbarService().showError(context, '${AppStrings.refreshFailed}: $e');
      }
    }
  }

  Future<void> _handleContactTap(ContactType type, String value) async {
    final Uri uri;

    switch (type) {
      case ContactType.phone:
        final cleanNumber = value.replaceAll(RegExp(r'[^0-9+]'), '');
        uri = Uri.parse('tel:$cleanNumber');
        break;
      case ContactType.email:
        uri = Uri.parse('mailto:$value');
        break;
      case ContactType.whatsapp:
        final cleanNumber = value.replaceAll(RegExp(r'[^0-9+]'), '');
        if (cleanNumber.isNotEmpty) {
          uri = Uri.parse('https://wa.me/$cleanNumber');
        } else if (value.contains('wa.me')) {
          uri = Uri.parse(value);
        } else {
          uri = Uri.parse('https://wa.me/${value.replaceAll('+', '')}');
        }
        break;
      case ContactType.telegram:
        if (value.contains('t.me')) {
          uri = Uri.parse(value);
        } else {
          final username = value
              .replaceAll('@', '')
              .replaceAll('https://', '')
              .replaceAll('http://', '');
          uri = Uri.parse('https://t.me/$username');
        }
        break;
      case ContactType.website:
        final url = value.startsWith('http') ? value : 'https://$value';
        uri = Uri.parse(url);
        break;
      case ContactType.social:
        final url = value.startsWith('http') ? value : 'https://$value';
        uri = Uri.parse(url);
        break;
      case ContactType.address:
        final encodedAddress = Uri.encodeComponent(value);
        uri = Uri.parse('https://maps.google.com/?q=$encodedAddress');
        break;
      case ContactType.hours:
        return;
      case ContactType.other:
        if (value.startsWith('http') || value.contains('.')) {
          final url = value.startsWith('http') ? value : 'https://$value';
          uri = Uri.parse(url);
        } else {
          await _copyContactValue(value);
          return;
        }
        break;
    }

    try {
      final launched = await ExternalLinkLauncher.launch(uri);
      if (!launched) {
        if (_canCopyContactValue(type, value)) {
          await _copyContactValue(value);
        } else {
          SnackbarService().showError(
            context,
            '${AppStrings.cannotOpen} $value',
          );
        }
      }
    } catch (e) {
      if (_canCopyContactValue(type, value)) {
        await _copyContactValue(value);
      } else {
        SnackbarService().showError(
          context,
          '${AppStrings.cannotOpen} $value',
        );
      }
    }
  }

  bool _canCopyContactValue(ContactType type, String value) {
    if (value.trim().isEmpty) return false;
    return type != ContactType.hours && type != ContactType.address;
  }

  Future<void> _copyContactValue(String value) async {
    await ExternalLinkLauncher.copyToClipboard(
      context,
      value,
    );
  }

  ContactInfo? _findContactBySettingKeys(List<String> keys) {
    for (final contact in _settingsProvider.getContactInfoList()) {
      if (keys.contains(contact.settingKey)) {
        return contact;
      }
    }
    return null;
  }

  Widget _buildContactCard(
    String title,
    String value,
    IconData icon,
    ContactType type, {
    Color? iconColor,
    int index = 0,
  }) {
    final canTap = type != ContactType.hours;
    final color = iconColor ?? _getIconColorForType(type);

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
      child: AppCard.contact(
        accentColor: color.withValues(alpha: 0.4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canTap && !isOffline
                ? () => _handleContactTap(type, value)
                : null,
            borderRadius: BorderRadius.circular(
              ResponsiveValues.radiusXLarge(context),
            ),
            splashColor: color.withValues(alpha: 0.08),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: ResponsiveValues.cardPadding(context),
              child: Row(
                children: [
                  Container(
                    width: ResponsiveValues.supportActionIconContainerSize(
                      context,
                    ),
                    height: ResponsiveValues.supportActionIconContainerSize(
                      context,
                    ),
                    decoration: BoxDecoration(
                      color:
                          AppColors.getSurface(context).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context),
                      ),
                      border: Border.all(
                        color: color.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: ResponsiveValues.iconSizeL(context),
                        color: isOffline ? AppColors.warning : color,
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveValues.spacingL(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.labelMedium(context).copyWith(
                            color: AppColors.getTextSecondary(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: ResponsiveValues.spacingXXS(context)),
                        Text(
                          value,
                          style: AppTextStyles.bodyMedium(
                            context,
                          ).copyWith(fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (canTap && !isOffline) ...[
                          SizedBox(height: ResponsiveValues.spacingS(context)),
                          Row(
                            children: [
                              Text(
                                type == ContactType.address
                                    ? AppStrings.viewOnMap
                                    : AppStrings.tapToContact,
                                style: AppTextStyles.caption(
                                  context,
                                ).copyWith(color: color),
                              ),
                              SizedBox(
                                width: ResponsiveValues.spacingXXS(context),
                              ),
                              Icon(
                                Icons.open_in_new_rounded,
                                size: ResponsiveValues.iconSizeXXS(context),
                                color: color,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_canCopyContactValue(type, value) && !isOffline) ...[
                    IconButton(
                      onPressed: () => _copyContactValue(value),
                      icon: Icon(
                        Icons.copy_rounded,
                        size: ResponsiveValues.iconSizeS(context),
                        color: color,
                      ),
                      tooltip: AppStrings.copy,
                      visualDensity: VisualDensity.compact,
                      splashRadius: ResponsiveValues.iconSizeS(context),
                    ),
                  ],
                  if (canTap && !isOffline) ...[
                    Icon(
                      Icons.chevron_right_rounded,
                      size: ResponsiveValues.iconSizeS(context),
                      color: AppColors.getTextSecondary(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer, {int index = 0}) {
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
      child: AppCard.glass(
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            expansionTileTheme: ExpansionTileThemeData(
              backgroundColor: Colors.transparent,
              collapsedBackgroundColor: Colors.transparent,
              iconColor: AppColors.telegramBlue,
              collapsedIconColor: AppColors.telegramBlue,
              textColor: AppColors.getTextPrimary(context),
              collapsedTextColor: AppColors.getTextPrimary(context),
            ),
          ),
          child: ExpansionTile(
            tilePadding: ResponsiveValues.listItemPadding(context),
            leading: Container(
              width: ResponsiveValues.iconSizeL(context),
              height: ResponsiveValues.iconSizeL(context),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context).withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.telegramBlue.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(
                Icons.help_rounded,
                size: ResponsiveValues.iconSizeXS(context),
                color: AppColors.telegramBlue,
              ),
            ),
            title: Text(
              question,
              style: AppTextStyles.titleSmall(
                context,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
            children: [
              Padding(
                padding: ResponsiveValues.cardPadding(context),
                child: Text(
                  answer,
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                    height: 1.6,
                  ),
                ),
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: ResponsiveValues.spacingM(context),
        top: ResponsiveValues.spacingXL(context),
      ),
      child: Text(
        title,
        style: AppTextStyles.titleLarge(
          context,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Color _getIconColorForType(ContactType type) {
    switch (type) {
      case ContactType.phone:
        return AppColors.telegramGreen;
      case ContactType.email:
        return AppColors.telegramBlue;
      case ContactType.whatsapp:
        return AppColors.telegramGreen;
      case ContactType.telegram:
        return AppColors.telegramBlue;
      case ContactType.address:
        return AppColors.telegramYellow;
      case ContactType.hours:
        return AppColors.telegramYellow;
      case ContactType.website:
        return AppColors.telegramBlue;
      case ContactType.social:
        return AppColors.telegramBlue;
      case ContactType.other:
        return AppColors.telegramBlue;
    }
  }

  Widget _buildContactTab() {
    final allContacts = _settingsProvider.getContactInfoList();
    final feedbackTelegramUrl = _settingsProvider.getFeedbackTelegramUrl();
    final feedbackContact = _findContactBySettingKeys(const [
          'support_feedback_telegram_url',
          'feedback_telegram_url',
          'feedback_url',
          'support_feedback_url',
        ]) ??
        (feedbackTelegramUrl == null
            ? null
            : ContactInfo(
                type: ContactType.telegram,
                title: AppStrings.feedback,
                value: feedbackTelegramUrl,
                icon: Icons.telegram,
                settingKey: 'support_feedback_telegram_url',
              ));
    final supportContact = _findContactBySettingKeys(const [
      'support_telegram_url',
      'support_direct_telegram_url',
      'support_direct_url',
      'support_telegram_bot_url',
    ]);
    final contactInfo = allContacts
        .where((contact) =>
            contact.settingKey != 'support_feedback_telegram_url' &&
            contact.settingKey != 'feedback_telegram_url' &&
            contact.settingKey != 'feedback_url' &&
            contact.settingKey != 'support_feedback_url' &&
            contact.settingKey != 'support_telegram_url' &&
            contact.settingKey != 'support_direct_telegram_url' &&
            contact.settingKey != 'support_direct_url' &&
            contact.settingKey != 'support_telegram_bot_url')
        .toList();
    final hasFeaturedCards = feedbackContact != null || supportContact != null;
    final hasAnyCards = hasFeaturedCards || contactInfo.isNotEmpty;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingL(context),
            vertical: ResponsiveValues.spacingL(context),
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionHeader(AppStrings.contactInformation),
              if (hasFeaturedCards) ...[
                _buildSectionHeader('Telegram channels'),
                if (feedbackContact != null)
                  _buildContactCard(
                    feedbackContact.title,
                    feedbackContact.value,
                    feedbackContact.icon,
                    feedbackContact.type,
                    iconColor: AppColors.telegramBlue,
                    index: 0,
                  ),
                if (supportContact != null)
                  _buildContactCard(
                    supportContact.title,
                    supportContact.value,
                    supportContact.icon,
                    supportContact.type,
                    iconColor: AppColors.telegramBlue,
                    index: 1,
                  ),
                SizedBox(height: ResponsiveValues.spacingM(context)),
              ],
              if (!hasAnyCards)
                AppCard.glass(
                  child: Padding(
                    padding: ResponsiveValues.dialogPadding(context),
                    child: Column(
                      children: [
                        Icon(
                          Icons.contact_support_rounded,
                          size: ResponsiveValues.iconSizeXXL(context),
                          color: AppColors.getTextSecondary(context),
                        ),
                        SizedBox(height: ResponsiveValues.spacingL(context)),
                        Text(
                          _settingsProvider.getSupportNoContactTitle(),
                          style: AppTextStyles.bodyLarge(context).copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                        SizedBox(height: ResponsiveValues.spacingM(context)),
                        Text(
                          _settingsProvider.getSupportNoContactMessage(),
                          style: AppTextStyles.bodySmall(context).copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...contactInfo.asMap().entries.map(
                      (entry) => _buildContactCard(
                        entry.value.title,
                        entry.value.value,
                        entry.value.icon,
                        entry.value.type,
                        index: entry.key,
                      ),
                    ),
              SizedBox(height: ResponsiveValues.spacingXXL(context)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildFAQTab() {
    final faqs = _settingsProvider.getSupportFaqItems();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingL(context),
            vertical: ResponsiveValues.spacingL(context),
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionHeader(AppStrings.frequentlyAskedQuestions),
              ...faqs.asMap().entries.map(
                    (entry) => _buildFAQItem(
                      entry.value['question']!,
                      entry.value['answer']!,
                      index: entry.key,
                    ),
                  ),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              _buildSectionHeader(AppStrings.stillNeedHelp),
              AppCard.glass(
                child: Padding(
                  padding: ResponsiveValues.cardPadding(context),
                  child: Column(
                    children: [
                      Icon(
                        Icons.support_agent_rounded,
                        size: ResponsiveValues.iconSizeXXXXL(context),
                        color: AppColors.telegramBlue,
                      ),
                      SizedBox(height: ResponsiveValues.spacingL(context)),
                      Text(
                        _settingsProvider.getSupportStillNeedHelpTitle(),
                        style: AppTextStyles.titleMedium(
                          context,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: ResponsiveValues.spacingS(context)),
                      Text(
                        _settingsProvider.getSupportStillNeedHelpMessage(),
                        style: AppTextStyles.bodyMedium(
                          context,
                        ).copyWith(color: AppColors.getTextSecondary(context)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: ResponsiveValues.spacingXXL(context)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return AppCard.glass(
      child: Container(
        padding: ResponsiveValues.dialogPadding(context),
        child: Row(
          children: [
            Container(
              width: ResponsiveValues.selectionSheetLeadingSize(context),
              height: ResponsiveValues.selectionSheetLeadingSize(context),
              decoration: BoxDecoration(
                color: AppColors.telegramBlue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.telegramBlue,
                  size: ResponsiveValues.iconSizeL(context),
                ),
              ),
            ),
            SizedBox(width: ResponsiveValues.spacingL(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.weAreHereToHelp,
                    style: AppTextStyles.titleLarge(context).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXXS(context)),
                  Text(
                    AppStrings.getHelpWith,
                    style: AppTextStyles.bodyMedium(
                      context,
                    ).copyWith(color: AppColors.getTextSecondary(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    final hasContacts = _settingsProvider.getContactInfoList().isNotEmpty;
    final isStillPreparing = !_hasError &&
        !hasContacts &&
        (_settingsProvider.isLoading || !_settingsProvider.isLoaded);

    if (isStillPreparing) {
      return buildBrandedLoadingState(
        title: _settingsProvider.getSupportScreenTitle(),
        message: _settingsProvider.getSupportScreenSubtitle(),
      );
    }

    if (_hasError) {
      return Center(
        child: buildErrorWidget(
          _errorMessage ?? AppStrings.unableToLoadSupportInfo,
          onRetry: () => _refreshTab(_tabController.index),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingL(context),
            vertical: ResponsiveValues.spacingM(context),
          ),
          child: _buildHeroSection(),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingL(context),
          ),
          child: AppCard.solid(
            hasShadow: false,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.telegramBlue,
              indicatorWeight: 3,
              labelColor: AppColors.telegramBlue,
              unselectedLabelColor: AppColors.getTextSecondary(context),
              labelStyle: AppTextStyles.labelMedium(context),
              unselectedLabelStyle: AppTextStyles.labelMedium(context),
              tabs: const [
                Tab(text: AppStrings.contact),
                Tab(text: AppStrings.faq),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _refreshTab(_tabController.index),
            color: AppColors.telegramBlue,
            backgroundColor: AppColors.getSurface(context),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildContactTab(),
                _buildFAQTab(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildScreen(
      content: buildContent(context),
      showRefreshIndicator: false,
    );
  }
}
