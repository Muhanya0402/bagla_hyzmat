import 'package:animations/animations.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/core/theme/app_colors.dart';
import 'package:bagla/core/tour/app_tour_mixin.dart';
import 'package:bagla/core/tour/tour_keys.dart';
import 'package:bagla/core/tour/tour_target.dart';
import 'package:bagla/features/profile/registration_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../l10n/language_provider.dart';

class UserTypeSelectionScreen extends StatefulWidget {
  const UserTypeSelectionScreen({super.key});

  @override
  State<UserTypeSelectionScreen> createState() =>
      _UserTypeSelectionScreenState();
}

class _UserTypeSelectionScreenState extends State<UserTypeSelectionScreen>
    with AppTourMixin<UserTypeSelectionScreen> {
  final _shopKey    = GlobalKey();
  final _courierKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    startTourIfNeeded(
      screenKey: TourKeys.userTypeSelection,
      targetsBuilder: _buildTourTargets,
    );
  }

  List<TargetFocus> _buildTourTargets() {
    final isRu = context.read<LanguageProvider>().isRu;
    return [
      TourTarget.build(
        key: _shopKey,
        titleRu: 'Магазин / бизнес',
        titleTk: 'Dükан / biznes',
        bodyRu:
            'Нажмите на карточку — заполните данные организации и начните принимать доставки.',
        bodyTk:
            'Kartça basyň — gurama maglumatlaryny dolduryň we eltip berilişleri kabul edip başlaň.',
        isRu: isRu,
        align: ContentAlign.bottom,
      ),
      TourTarget.build(
        key: _courierKey,
        titleRu: 'Курьер',
        titleTk: 'Kurýer',
        bodyRu:
            'Нажмите на карточку — заполните личные данные и начните выполнять заказы.',
        bodyTk:
            'Kartça basyň — şahsy maglumatlaryňyzy dolduryň we sargytlary ýerine ýetirip başlaň.',
        isRu: isRu,
        align: ContentAlign.bottom,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lang  = context.watch<LanguageProvider>();
    final words = lang.words;
    final c     = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.border),
            ),
            child: Icon(Icons.arrow_back_ios_new, color: c.ink, size: 16),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: c.border),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),

              Text(
                words.selectRole,
                style: AppText.serif(fontSize: 30, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                words.roleSubtitle,
                style: AppText.regular(fontSize: 14, color: c.inkMuted)
                    .copyWith(height: 1.5),
              ),

              const SizedBox(height: 28),

              // ── Карточка «Магазин» ────────────────────────────────────
              KeyedSubtree(
                key: _shopKey,
                child: _RoleOpenContainer(
                  role: 'shop',
                  title: words.roleClient,
                  desc: words.roleClientDesc,
                  asset: 'assets/images/onboarding/merchant_welcome.png',
                  placeholderIcon: Icons.storefront_outlined,
                  closedColor: c.surface,
                  openColor: c.bg,
                ),
              ),

              const SizedBox(height: 12),

              // ── Карточка «Курьер» ─────────────────────────────────────
              KeyedSubtree(
                key: _courierKey,
                child: _RoleOpenContainer(
                  role: 'courier',
                  title: words.roleCourier,
                  desc: words.roleCourierDesc,
                  asset: 'assets/images/onboarding/courier_welcome.png',
                  placeholderIcon: Icons.pedal_bike_outlined,
                  closedColor: c.surface,
                  openColor: c.bg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── OpenContainer-обёртка над карточкой роли ─────────────────────────────────
//
// closedBuilder  → отрисовывает саму карточку.
// openBuilder    → отрисовывает RegistrationDetailsScreen с нужной ролью.
// tappable: false — мы сами управляем тапом внутри _RoleCard,
//                   чтобы сохранить press-анимацию карточки.

class _RoleOpenContainer extends StatelessWidget {
  final String role;
  final String title;
  final String desc;
  final String asset;
  final IconData placeholderIcon;
  final Color closedColor;
  final Color openColor;

  const _RoleOpenContainer({
    required this.role,
    required this.title,
    required this.desc,
    required this.asset,
    required this.placeholderIcon,
    required this.closedColor,
    required this.openColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return OpenContainer<void>(
      // Длительность анимации открытия / закрытия
      transitionDuration: const Duration(milliseconds: 420),
      // fadeThrough — плавное растворение + рост контейнера
      transitionType: ContainerTransitionType.fadeThrough,

      // Цвет фона закрытой карточки → совпадает с surface, без белой вспышки
      closedColor: closedColor,
      // Цвет фона открытого экрана → совпадает с bg RegistrationDetailsScreen
      openColor: openColor,
      // Промежуточный цвет (в момент перехода) — тоже bg
      middleColor: openColor,

      // Форма карточки: скруглённые углы (совпадают с BorderRadius в _RoleCard)
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // Граница карточки через side, чтобы цвет был правильным
        side: BorderSide(color: c.borderSoft),
      ),
      // Открытый экран — прямоугольник (полноэкранный Scaffold)
      openShape: const RoundedRectangleBorder(),

      closedElevation: 0,
      openElevation: 0,

      // tappable: false — иначе OpenContainer добавит свой InkWell поверх
      // GestureDetector карточки и возникнет двойная обработка тапа.
      tappable: false,

      // Карточка роли; openContainer() вызывается из её onTap
      closedBuilder: (_, openContainer) => _RoleCard(
        title: title,
        desc: desc,
        asset: asset,
        placeholderIcon: placeholderIcon,
        placeholderColor: c.bannerBg,
        // Тап на карточку запускает Container Transform
        onTap: openContainer,
      ),

      // Целевой экран; роль передаётся напрямую через конструктор.
      // Navigator.pop() внутри RegistrationDetailsScreen автоматически
      // запускает обратную анимацию — никакого специального handling не нужно.
      openBuilder: (_, _) => RegistrationDetailsScreen(role: role),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Role card (визуальная карточка, без состояния выбора)
// ═════════════════════════════════════════════════════════════════════════════

class _RoleCard extends StatefulWidget {
  final String title;
  final String desc;
  final String asset;
  final Color placeholderColor;
  final IconData placeholderIcon;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.desc,
    required this.asset,
    required this.placeholderColor,
    required this.placeholderIcon,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Row(
          children: [
            // ── Изображение ──────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),
              child: SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: widget.placeholderColor),
                    Image(
                      image: AssetImage(widget.asset),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => Center(
                        child: Icon(
                          widget.placeholderIcon,
                          size: 30,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Текст ────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: AppText.semiBold(fontSize: 15, color: c.ink),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.desc,
                      style: AppText.regular(fontSize: 12, color: c.inkMuted)
                          .copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),

            // ── Стрелка вперёд ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: c.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
