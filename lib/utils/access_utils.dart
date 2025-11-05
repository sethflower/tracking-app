import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Возвращает информацию о доступе:
/// уровень, подпись, цвет и права (очистка истории и ошибок)
Future<Map<String, dynamic>> getUserAccessInfo() async {
  final prefs = await SharedPreferences.getInstance();
  final level = prefs.getInt('access_level') ?? 2;
  final password = prefs.getString('last_password') ?? '';

  String label = '👁 Перегляд';
  Color color = Colors.grey;
  bool canClearHistory = false;
  bool canClearErrors = false;

  // 🔑 Адмін (301993)
  if (level == 1 || password == '301993') {
    label = '🔑 Адмін';
    color = Colors.redAccent;
    canClearHistory = true;
    canClearErrors = true;

  // 🧰 Спеціальний користувач (123123123) — тільки очищення помилок
  } else if (password == '123123123') {
    label = '🧰 Очищення помилок';
    color = Colors.orangeAccent;
    canClearErrors = true;

  // 🧰 Звичайний оператор
  } else if (level == 0) {
    label = '🧰 Оператор';
    color = Colors.blueAccent;

  // 👁 Перегляд (по замовчуванню)
  } else {
    label = '👁 Перегляд';
    color = Colors.grey;
  }

  return {
    'label': label,
    'color': color,
    'level': level,
    'canClearHistory': canClearHistory,
    'canClearErrors': canClearErrors,
  };
}
