import 'package:bagla/core/app_text_styles.dart';
import 'package:flutter/material.dart';

class WalletInfoModal extends StatelessWidget {
  final double balance;
  const WalletInfoModal({super.key, required this.balance});

  static const _green = Color(0xFF1A7A3C);
  static const _red = Color(0xFFD32F1E);
  static const _gradient = LinearGradient(
    colors: [_green, _red],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).padding.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF0F3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Wallet icon с градиентным кольцом
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_green.withOpacity(0.15), _red.withOpacity(0.08)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: _green,
              size: 38,
            ),
          ),
          const SizedBox(height: 20),

          // Заголовок
          ShaderMask(
            shaderCallback: (b) => _gradient.createShader(b),
            child: Text(
              'Мой кошелёк',
              style: AppText.extraBold(fontSize: 22, color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Средства от выполненных заказов',
            style: AppText.regular(
              fontSize: 13,
              color: const Color(0xFF9AA3AF),
            ),
          ),
          const SizedBox(height: 24),

          // Баланс
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_green.withOpacity(0.07), _red.withOpacity(0.04)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _green.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                Text(
                  'Доступный баланс',
                  style: AppText.regular(
                    fontSize: 12,
                    color: const Color(0xFF9AA3AF),
                  ),
                ),
                const SizedBox(height: 8),
                ShaderMask(
                  shaderCallback: (b) => _gradient.createShader(b),
                  child: Text(
                    '${balance.toStringAsFixed(2)} TMT',
                    style: AppText.extraBold(fontSize: 36, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Инфо-шаги как получить деньги
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEEF0F3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'КАК ВЫВЕСТИ СРЕДСТВА',
                  style: AppText.semiBold(
                    fontSize: 10,
                    color: const Color(0xFF9AA3AF),
                  ).copyWith(letterSpacing: 1.0),
                ),
                const SizedBox(height: 16),
                _buildStep(
                  number: '1',
                  icon: Icons.support_agent_rounded,
                  title: 'Свяжитесь с поддержкой',
                  subtitle: 'Напишите нам в поддержку для оформления вывода',
                  color: _green,
                ),
                const SizedBox(height: 14),
                _buildStep(
                  number: '2',
                  icon: Icons.badge_outlined,
                  title: 'Подтвердите личность',
                  subtitle: 'Предоставьте данные организации и реквизиты',
                  color: const Color(0xFFE67E22),
                ),
                const SizedBox(height: 14),
                _buildStep(
                  number: '3',
                  icon: Icons.account_balance_rounded,
                  title: 'Получите перевод',
                  subtitle: 'Средства поступят на ваш счёт в течение 1–3 дней',
                  color: _green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Кнопка закрыть
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: _gradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _green.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                'ПОНЯТНО',
                style: AppText.bold(
                  fontSize: 14,
                  color: Colors.white,
                ).copyWith(letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.semiBold(
                  fontSize: 13,
                  color: const Color(0xFF0F1117),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppText.regular(
                  fontSize: 12,
                  color: const Color(0xFF9AA3AF),
                ).copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
