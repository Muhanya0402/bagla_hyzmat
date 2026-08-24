import 'package:bagla/features/notifications/notification_dto.dart';
import 'package:bagla/features/notifications/widgets/notification_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// У всех уведомлений о статусе заказа стоял грузовик — и когда заказ взяли,
/// и когда доставили, и когда отменили, на чём бы курьер ни ездил. Теперь
/// иконка совпадает с его транспортом. У старых уведомлений транспорта нет,
/// и они обязаны остаться с прежней иконкой, а не пропасть.
void main() {
  group('notifTypeIcon', () {
    test('статус заказа: иконка по транспорту курьера', () {
      expect(
        notifTypeIcon('order_status', transport: 'car'),
        Icons.directions_car_rounded,
      );
      expect(
        notifTypeIcon('order_status', transport: 'truck'),
        Icons.local_shipping_rounded,
      );
      expect(
        notifTypeIcon('order_status', transport: 'any'),
        Icons.directions_run_rounded,
      );
    });

    test('транспорт неизвестен — прежняя иконка, а не пустота', () {
      // Старые уведомления, созданные до появления поля.
      expect(notifTypeIcon('order_status'), Icons.local_shipping_rounded);
      expect(
        notifTypeIcon('order_status', transport: ''),
        Icons.local_shipping_rounded,
      );
      expect(
        notifTypeIcon('order_status', transport: 'мопед'),
        Icons.local_shipping_rounded,
      );
    });

    test('остальные типы транспорт не учитывают', () {
      expect(
        notifTypeIcon('new_order', transport: 'car'),
        Icons.shopping_bag_rounded,
      );
      expect(
        notifTypeIcon('account_status', transport: 'car'),
        Icons.verified_user_rounded,
      );
      expect(
        notifTypeIcon('daily_bonus', transport: 'car'),
        Icons.bolt_rounded,
      );
      expect(notifTypeIcon('что-то новое'), Icons.notifications_rounded);
    });
  });

  group('NotificationDto.transportType', () {
    test('читается из ответа сервера', () {
      final dto = NotificationDto.fromMap({
        'id': 1,
        'type': 'order_status',
        'transport_type': 'car',
      });
      expect(dto.transportType, 'car');
    });

    test('отсутствие поля не ломает разбор', () {
      final dto = NotificationDto.fromMap({'id': 1, 'type': 'order_status'});
      expect(dto.transportType, '');
    });

    test('copyWith сохраняет транспорт', () {
      final dto = NotificationDto.fromMap({
        'id': 1,
        'type': 'order_status',
        'transport_type': 'truck',
      });
      expect(dto.copyWith(isRead: true).transportType, 'truck');
    });
  });
}
