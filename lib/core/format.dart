import 'package:flutter/material.dart';

const kMint = Color(0xFF28DFB1);
const kGreen = Color(0xFF25C994);
const kRed = Color(0xFFFF6B79);
const kBlue = Color(0xFF4A97FF);
const kViolet = Color(0xFFA785FF);
const kAmber = Color(0xFFFFB454);
const kBg = Color(0xFF0B101A);
const kSurface = Color(0xFF151D2B);
const kSurface2 = Color(0xFF1D2939);

String money(int cents) {
  final negative = cents < 0;
  final absolute = cents.abs();
  final whole = absolute ~/ 100;
  final fraction = (absolute % 100).toString().padLeft(2, '0');
  final digits = whole.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${negative ? '− ' : ''}R\$ ${buffer.toString()},$fraction';
}

int? parseMoney(String input) {
  final clean = input.replaceAll(RegExp(r'[^\d.,]'), '');
  if (clean.isEmpty) return null;
  final comma = clean.lastIndexOf(',');
  final dot = clean.lastIndexOf('.');
  String formatted;
  if (comma >= 0) {
    formatted = clean.replaceAll('.', '').replaceAll(',', '.');
  } else if (dot >= 0 && clean.length - dot - 1 <= 2) {
    formatted = clean;
  } else {
    formatted = clean.replaceAll('.', '');
  }
  final value = double.tryParse(formatted);
  if (value == null || !value.isFinite || value <= 0 || value > 100000000000) return null;
  return (value * 100).round();
}

const weekdays = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
const months = ['janeiro','fevereiro','março','abril','maio','junho','julho','agosto','setembro','outubro','novembro','dezembro'];
String prettyMonth(DateTime date) => '${months[date.month - 1][0].toUpperCase()}${months[date.month - 1].substring(1)} ${date.year}';
String dateLabel(DateTime date) => '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
String timeLabel(DateTime date) => '${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
DateTime mondayOf(DateTime d) => dayOnly(d).subtract(Duration(days: d.weekday - 1));
