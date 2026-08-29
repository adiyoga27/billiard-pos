import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
final _rupiahShort = NumberFormat.compactCurrency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 1);

String formatRupiah(num value) => _rupiah.format(value.toInt());

String formatRupiahShort(num value) => _rupiahShort.format(value.toInt());

final _clock = DateFormat('HH:mm');
final _clockSec = DateFormat('HH:mm:ss');
final _dateShort = DateFormat('dd MMM yyyy');
final _dateTimeShort = DateFormat('dd MMM yyyy, HH:mm');

String formatClock(DateTime t) => _clock.format(t.toLocal());

String formatClockSec(DateTime t) => _clockSec.format(t.toLocal());

String formatDate(DateTime t) => _dateShort.format(t.toLocal());

String formatDateTime(DateTime t) => _dateTimeShort.format(t.toLocal());

/// Durasi dalam format jam:menit:detik, misal 02:05:33
String formatDuration(Duration d, {bool withHours = true}) {
  String two(int n) => n.toString().padLeft(2, '0');
  if (withHours) {
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }
  return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
}

/// Label durasi ramah manusia: "2 jam 5 mnt"
String formatDurationHuman(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0 && m > 0) return '$h jam $m mnt';
  if (h > 0) return '$h jam';
  return '$m mnt';
}

/// Sisa waktu sesi durasi tetap, misal "12:45" atau "LEWAT 05:10"
String formatCountdown(Duration remaining) {
  final neg = remaining.isNegative;
  final d = neg ? -remaining : remaining;
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  final base = h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}' : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return neg ? 'LEWAT $base' : base;
}