// ─────────────────────────────────────────────────────────────────────────────
// pubspec.yaml — скопируй в секцию flutter › assets:
//
//   flutter:
//     fonts:
//       - family: Lora
//         fonts:
//           - asset: assets/fonts/Lora-Regular.ttf
//           - asset: assets/fonts/Lora-Medium.ttf   weight: 500
//           - asset: assets/fonts/Lora-SemiBold.ttf weight: 600
//           - asset: assets/fonts/Lora-Bold.ttf     weight: 700
//       - family: Nunito
//         fonts:
//           - asset: assets/fonts/Nunito-Regular.ttf
//           ... (остальные начертания)
//     assets:
//       - assets/images/bagla_logo.png
//       - assets/images/onboarding/merchant_welcome.png
//       - assets/images/onboarding/courier_welcome.png
//
// Структура папки assets/images/onboarding/:
//   merchant_welcome.png   — прилавок / маркет / коробки с товаром
//   courier_welcome.png    — курьер с рюкзаком или пакетом на улице
// ─────────────────────────────────────────────────────────────────────────────

import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/features/auth/widgets/auth_widgets.dart';
import 'package:bagla/features/profile/registration_details_screen.dart';
import 'package:bagla/l10n/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Roles
// ─────────────────────────────────────────────────────────────────────────────
enum _UserRole { shop, courier, observer }

// ─────────────────────────────────────────────────────────────────────────────
// Asset paths — только карточки выбора роли
// ─────────────────────────────────────────────────────────────────────────────
class _OnboardingAssets {
  static const String roleShop =
      'assets/images/onboarding/merchant_welcome.png';
  static const String roleCourier =
      'assets/images/onboarding/courier_welcome.png';
}

// ═════════════════════════════════════════════════════════════════════════════
// OnboardingScreen
// Шаги: 0 — Быстрая доставка  1 — Роли  2 — Жетоны  3 — Выбор роли (финал)
// После финала → PhoneScreen (auth вынесен из онбординга)
// ═════════════════════════════════════════════════════════════════════════════
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  static const int _stepCount = 4;

  final PageController _pageCtrl = PageController();
  int _currentStep = 0;
  _UserRole? _selectedRole;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _goToStep(int step) async {
    if (step < 0 || step >= _stepCount) return;
    setState(() => _currentStep = step);
    await _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _onBack() {
    if (_currentStep == 0) return;
    _goToStep(_currentStep - 1);
  }

  Future<void> _finishOnboarding() async {
    final role = switch (_selectedRole) {
      _UserRole.shop => 'shop',
      _UserRole.courier => 'courier',
      _UserRole.observer => 'observer',
      null => 'observer',
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    await prefs.setString('user_role', role);
    if (!mounted) return;
    if (_selectedRole == _UserRole.observer) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RegistrationDetailsScreen(role: role),
        ),
      );
    }
  }

  _CtaConfig _ctaFor(int step, dynamic words) {
    switch (step) {
      case 0:
      case 1:
      case 2:
        return _CtaConfig(
          label: words.obNext,
          onPressed: () => _goToStep(step + 1),
        );
      case 3:
        return _CtaConfig(
          label: words.obStart,
          onPressed: _selectedRole == null ? null : _finishOnboarding,
          accentEmerald: true,
        );
      default:
        return _CtaConfig(label: '', onPressed: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final words = lang.words;
    final cta = _ctaFor(_currentStep, words);
    final isLastStep = _currentStep == _stepCount - 1;

    return Scaffold(
      backgroundColor: AppColors.of(context).bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                _TopBar(
                  showBack: _currentStep > 0,
                  currentStep: _currentStep,
                  totalSteps: _stepCount,
                  isRu: lang.isRu,
                  onBack: _onBack,
                  onToggleLang: lang.toggleLanguage,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // ── Шаг 0: Быстрая доставка ─────────────────────────
                      _FeatureSlide(
                        heroIcon: Icons.local_shipping_outlined,
                        heroBg: AppColors.of(context).emeraldTint,
                        heroColor: AppColors.of(context).emerald,
                        tag: words.onboardingTag1,
                        tagColor: AppColors.of(context).emerald,
                        title: words.onboardingTitle1,
                        subtitle: words.get('onboardingSubtitle1'),
                        pills: [
                          words.onboardingPill1_1,
                          words.onboardingPill1_2,
                          words.onboardingPill1_3,
                        ],
                      ),
                      // ── Шаг 1: Роли ─────────────────────────────────────
                      _FeatureSlide(
                        heroIcon: Icons.groups_outlined,
                        heroBg: const Color(0xFFECE9F5),
                        heroColor: const Color(0xFF5B4B8A),
                        tag: words.onboardingTag2,
                        tagColor: AppColors.of(context).accent,
                        title: words.onboardingTitle2,
                        subtitle: words.get('onboardingSubtitle2'),
                        pills: [
                          words.onboardingPill2_1,
                          words.onboardingPill2_2,
                        ],
                      ),
                      // ── Шаг 2: Жетоны и уровни ──────────────────────────
                      _FeatureSlide(
                        heroIcon: Icons.toll_outlined,
                        heroBg: AppColors.of(context).amberTint,
                        heroColor: AppColors.of(context).amber,
                        tag: words.onboardingTag3,
                        tagColor: AppColors.of(context).amber,
                        title: words.onboardingTitle3,
                        subtitle: words.get('onboardingSubtitle3'),
                        pills: [
                          words.onboardingPill3_1,
                          words.onboardingPill3_2,
                        ],
                      ),
                      // ── Шаг 3: Выбор роли (финал) ───────────────────────
                      _RoleStep(
                        words: words,
                        selectedRole: _selectedRole,
                        onSelect: (r) => setState(() => _selectedRole = r),
                      ),
                    ],
                  ),
                ),

                // ── CTA ────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                  child: _PrimaryCta(
                    label: cta.label,
                    onPressed: cta.onPressed,
                    accentEmerald: cta.accentEmerald,
                  ),
                ),

                // ── Пропустить (только на слайдах 0–2) ────────────────────
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: isLastStep
                      ? const SizedBox(height: 24)
                      : Padding(
                          padding: const EdgeInsets.only(top: 14, bottom: 24),
                          child: GestureDetector(
                            onTap: () => _goToStep(_stepCount - 1),
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              words.skip,
                              style: AppText.medium(
                                fontSize: 13,
                                color: AppColors.of(context).inkSoft,
                              ).copyWith(letterSpacing: 0.1),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CtaConfig {
  final String label;
  final VoidCallback? onPressed;
  final bool accentEmerald;
  _CtaConfig({
    required this.label,
    required this.onPressed,
    this.accentEmerald = false,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// Top bar — back · progress dots · language switcher
// ═════════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  final bool showBack;
  final int currentStep;
  final int totalSteps;
  final bool isRu;
  final VoidCallback onBack;
  final VoidCallback onToggleLang;

  const _TopBar({
    required this.showBack,
    required this.currentStep,
    required this.totalSteps,
    required this.isRu,
    required this.onBack,
    required this.onToggleLang,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: showBack ? 1 : 0,
            child: IgnorePointer(
              ignoring: !showBack,
              child: GestureDetector(
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.of(context).border,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 14,
                    color: AppColors.of(context).ink,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          _ProgressDots(current: currentStep, total: totalSteps),
          const Spacer(),
          AuthLangSwitcher(isRu: isRu, onToggle: onToggleLang),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
          width: active ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? AppColors.of(context).ink
                : AppColors.of(context).border,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Primary CTA
// ═════════════════════════════════════════════════════════════════════════════
class _PrimaryCta extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool accentEmerald;

  const _PrimaryCta({
    required this.label,
    required this.onPressed,
    this.accentEmerald = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = onPressed != null;
    final Color fill = active
        ? (accentEmerald
              ? AppColors.of(context).emerald
              : AppColors.of(context).ink)
        : const Color(0xFFE2DCD0);
    final Color shadowColor = accentEmerald
        ? AppColors.of(context).emerald
        : AppColors.of(context).ink;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: active
            ? [
                BoxShadow(
                  color: shadowColor.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: shadowColor.withValues(alpha: 0.06),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : const [],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: fill,
          disabledBackgroundColor: const Color(0xFFE2DCD0),
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.of(context).inkMuted,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.1,
            fontFamily: 'Nunito',
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ШАГИ 0–2 — Feature slides
// ═════════════════════════════════════════════════════════════════════════════
class _FeatureSlide extends StatelessWidget {
  final IconData heroIcon;
  final Color heroBg;
  final Color heroColor;
  final String tag;
  final Color tagColor;
  final String title;
  final String subtitle;
  final List<String> pills;

  const _FeatureSlide({
    required this.heroIcon,
    required this.heroBg,
    required this.heroColor,
    required this.tag,
    required this.tagColor,
    required this.title,
    required this.subtitle,
    required this.pills,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
      children: [
        _FeatureHero(icon: heroIcon, bg: heroBg, color: heroColor),
        const SizedBox(height: 32),
        _SlideTag(text: tag, color: tagColor),
        const SizedBox(height: 14),
        Text(title, style: AppText.serif(fontSize: 34, letterSpacing: -0.6)),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: AppText.regular(
            fontSize: 15,
            color: AppColors.of(context).inkMuted,
          ).copyWith(height: 1.6, letterSpacing: 0.1),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: pills.map((p) => _SlidePill(label: p)).toList(),
        ),
      ],
    );
  }
}

class _FeatureHero extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color color;

  const _FeatureHero({
    required this.icon,
    required this.bg,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Icon(icon, size: 42, color: color),
        ),
      ),
    );
  }
}

class _SlideTag extends StatelessWidget {
  final String text;
  final Color color;
  const _SlideTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: AppText.semiBold(
            fontSize: 11,
            color: color,
          ).copyWith(letterSpacing: 1.2),
        ),
      ],
    );
  }
}

class _SlidePill extends StatelessWidget {
  final String label;
  const _SlidePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.of(context).border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.of(context).ink.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: AppText.medium(
          fontSize: 12.5,
          color: AppColors.of(context).ink,
        ).copyWith(letterSpacing: 0.1),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ШАГ 3 — Выбор роли
// ═════════════════════════════════════════════════════════════════════════════
class _RoleStep extends StatelessWidget {
  final dynamic words;
  final _UserRole? selectedRole;
  final ValueChanged<_UserRole> onSelect;

  const _RoleStep({
    required this.words,
    required this.selectedRole,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      children: [
        Text(
          words.obWelcomeTitle,
          style: AppText.serif(fontSize: 34, letterSpacing: -0.6),
        ),
        const SizedBox(height: 12),
        Text(
          words.obWelcomeSubtitle,
          style: AppText.regular(
            fontSize: 14.5,
            color: AppColors.of(context).inkMuted,
          ).copyWith(height: 1.5, letterSpacing: 0.1),
        ),
        const SizedBox(height: 32),
        _RoleCard(
          asset: _OnboardingAssets.roleShop,
          title: words.obRoleShopTitle,
          subtitle: words.obRoleShopSubtitle,
          selected: selectedRole == _UserRole.shop,
          onTap: () => onSelect(_UserRole.shop),
          placeholderColor: const Color(0xFFEFE6D6),
          placeholderIcon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 14),
        _RoleCard(
          asset: _OnboardingAssets.roleCourier,
          title: words.obRoleCourierTitle,
          subtitle: words.obRoleCourierSubtitle,
          selected: selectedRole == _UserRole.courier,
          onTap: () => onSelect(_UserRole.courier),
          placeholderColor: const Color(0xFFE6E0D3),
          placeholderIcon: Icons.pedal_bike_outlined,
        ),
        const SizedBox(height: 14),
        _RoleCard(
          asset: '',
          title: words.obRoleObserverTitle,
          subtitle: words.obRoleObserverSubtitle,
          selected: selectedRole == _UserRole.observer,
          onTap: () => onSelect(_UserRole.observer),
          placeholderColor: const Color(0xFFE8E4F0),
          placeholderIcon: Icons.visibility_outlined,
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String asset;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color placeholderColor;
  final IconData placeholderIcon;

  const _RoleCard({
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.placeholderColor,
    required this.placeholderIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.of(context).ink.withValues(alpha: 0.04),
        highlightColor: AppColors.of(context).ink.withValues(alpha: 0.02),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.of(context).surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.of(context).emerald
                  : AppColors.of(context).border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.of(
                        context,
                      ).emerald.withValues(alpha: 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppColors.of(context).ink.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child: _AssetImage(
                    path: asset,
                    placeholderColor: placeholderColor,
                    placeholderIcon: placeholderIcon,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: AppText.serif(
                          fontSize: 19,
                          letterSpacing: -0.2,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: AppText.regular(
                          fontSize: 13,
                          color: AppColors.of(context).inkMuted,
                        ).copyWith(height: 1.45),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.of(context).emerald
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? AppColors.of(context).emerald
                        : AppColors.of(context).border,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// AssetImage с цветом-заглушкой и errorBuilder
// ═════════════════════════════════════════════════════════════════════════════
class _AssetImage extends StatelessWidget {
  final String path;
  final Color placeholderColor;
  final IconData placeholderIcon;

  const _AssetImage({
    required this.path,
    required this.placeholderColor,
    required this.placeholderIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: placeholderColor),
        Image(
          image: AssetImage(path),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => Center(
            child: Icon(
              placeholderIcon,
              size: 28,
              color: AppColors.of(context).ink.withValues(alpha: 0.35),
            ),
          ),
        ),
      ],
    );
  }
}
