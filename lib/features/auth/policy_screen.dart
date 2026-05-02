import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bagla/providers/language_provider.dart';
import 'package:bagla/core/app_text_styles.dart';
import 'package:bagla/features/auth/phone_screen.dart';

class PolicyScreen extends StatefulWidget {
  final VoidCallback? onAccepted;
  const PolicyScreen({super.key, this.onAccepted});

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  final _scrollCtrl = ScrollController();
  bool _hasScrolledToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_hasScrolledToBottom &&
        _scrollCtrl.offset >= _scrollCtrl.position.maxScrollExtent - 48) {
      setState(() => _hasScrolledToBottom = true);
    }
  }

  @override
  void dispose() {
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _accept() {
    widget.onAccepted?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isRu = lang.isRu;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
              child: Row(
                children: [
                  _BackButton(),
                  const Spacer(),
                  const BaglaLogo(width: 56, height: 28),
                  const Spacer(),
                  _LangSwitcher(isRu: isRu, onToggle: lang.toggleLanguage),
                ],
              ),
            ),

            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Green badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5EE),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      isRu ? 'Документ' : 'Resminama',
                      style: AppText.semiBold(
                        fontSize: 11,
                        color: PhoneScreen.brandGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isRu ? 'Условия и политика' : 'Şertler we syýasat',
                    style: AppText.bold(fontSize: 22),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isRu
                        ? 'Пожалуйста, ознакомьтесь перед использованием'
                        : 'Ulanmazdan ozal okaň',
                    style: AppText.regular(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  // Gradient divider
                  Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: PhoneScreen.brandGradient,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable content ─────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 12),
                children: [
                  _PolicySection(
                    index: '1',
                    title: isRu ? 'Общие положения' : 'Umumy düzgünler',
                    body: isRu
                        ? 'Настоящие Условия использования регулируют отношения между пользователем и сервисом при использовании мобильного приложения на территории Туркменистана. Продолжая использование, вы соглашаетесь с настоящими Условиями.'
                        : 'Bu Ulanyş şertleri ulanyjy bilen hyzmat arasynda Türkmenistanda mobil programmany ulanmak bilen bagly gatnaşyklary düzenleýär.',
                  ),
                  _PolicySection(
                    index: '2',
                    title: isRu ? 'Персональные данные' : 'Şahsy maglumatlar',
                    body: isRu
                        ? 'Мы собираем минимально необходимые данные: номер телефона и идентификатор устройства. Данные не передаются третьим лицам без вашего явного согласия.'
                        : 'Biz diňe zerur maglumatlary ýygnaýarys: telefon belgisi we enjam identifikatory. Maglumatlary siziň açyk razylygyňyz bolmazdan üçünji taraplara geçirmeýäris.',
                  ),
                  _PolicySection(
                    index: '3',
                    title: isRu
                        ? 'SMS-коды и безопасность'
                        : 'SMS-kodlar we howpsuzlyk',
                    body: isRu
                        ? 'Коды подтверждения действительны 5 минут и одноразовые. Никогда не сообщайте код другим лицам — сотрудники приложения его не запрашивают.'
                        : 'Tassyklaýjy kodlar 5 minut geçerli we bir gezeklik. Kody hiç kimsä aýtmaň — programma işgärleri ony soramaýar.',
                  ),
                  _PolicySection(
                    index: '4',
                    title: isRu ? 'Правила использования' : 'Ulanyş düzgünleri',
                    body: isRu
                        ? 'Вы обязуетесь использовать приложение только в законных целях, не нарушать права других пользователей и не предпринимать попыток взлома системы.'
                        : 'Programmany diňe kanuny maksatlar üçin ulanmaga, beýleki ulanyjylaryň hukuklaryny bozmazlyga borçlanýarsyňyz.',
                  ),
                  _PolicySection(
                    index: '5',
                    title: isRu
                        ? 'Ограничение ответственности'
                        : 'Jogapkärçiligiň çäklenmesi',
                    body: isRu
                        ? 'Приложение предоставляется «как есть». Мы не несём ответственности за перебои в работе, вызванные внешними факторами, включая проблемы со связью.'
                        : 'Programma "bar bolşy ýaly" hödürlenýär. Aragatnaşyk meseleleri ýaly daşarky faktorlar bilen baglanyşykly bökdençlikler üçin jogapkärçilik çekmeýäris.',
                  ),
                  _PolicySection(
                    index: '6',
                    title: isRu ? 'Изменение условий' : 'Şertleri üýtgetmek',
                    body: isRu
                        ? 'Мы вправе изменять настоящие Условия. О существенных изменениях уведомим через push-уведомление или SMS не позднее чем за 5 дней.'
                        : 'Şertleri üýtgetmäge haklarymyz bar. Esasy üýtgeşmeler barada 5 günden az bolmadyk möhletde push-bildiriş ýa-da SMS arkaly habar bereris.',
                    isLast: true,
                  ),
                ],
              ),
            ),

            // ── Accept button ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              child: Column(
                children: [
                  if (!_hasScrolledToBottom)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        isRu
                            ? 'Прокрутите вниз, чтобы продолжить'
                            : 'Dowam etmek üçin aşak aýlaň',
                        style: AppText.regular(
                          fontSize: 12,
                          color: Colors.black38,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _hasScrolledToBottom
                            ? PhoneScreen.brandGradient
                            : null,
                        color: _hasScrolledToBottom
                            ? null
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ElevatedButton(
                        onPressed: _hasScrolledToBottom ? _accept : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isRu
                                  ? 'ПРИНЯТЬ И ПРОДОЛЖИТЬ'
                                  : 'KABUL ET WE DOWAM ET',
                              style: TextStyle(
                                color: _hasScrolledToBottom
                                    ? Colors.white
                                    : Colors.black38,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _hasScrolledToBottom
                                    ? Colors.white24
                                    : Colors.black12,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                color: _hasScrolledToBottom
                                    ? Colors.white
                                    : Colors.black38,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Private widgets
// ─────────────────────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          size: 16,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _LangSwitcher extends StatelessWidget {
  final bool isRu;
  final VoidCallback onToggle;
  const _LangSwitcher({required this.isRu, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LangTab(label: 'RU', active: isRu),
            _LangTab(label: 'TK', active: !isRu),
          ],
        ),
      ),
    );
  }
}

class _LangTab extends StatelessWidget {
  final String label;
  final bool active;
  const _LangTab({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: active ? PhoneScreen.brandGradient : null,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: active ? Colors.white : Colors.black38,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final String index;
  final String title;
  final String body;
  final bool isLast;

  const _PolicySection({
    required this.index,
    required this.title,
    required this.body,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5EE),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                index,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: PhoneScreen.brandGreen,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: AppText.semiBold(fontSize: 13, color: Colors.black87),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: AppText.regular(
            fontSize: 13,
            color: Colors.black54,
          ).copyWith(height: 1.6),
        ),
        if (!isLast) ...[
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 16),
        ] else
          const SizedBox(height: 16),
      ],
    );
  }
}
