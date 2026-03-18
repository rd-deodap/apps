import 'package:intl/intl.dart';

class AppDate {
  // Format a DateTime to dd-MM-yyyy
  static String formatDate(DateTime dt) => DateFormat('dd-MM-yyyy').format(dt);

  // Format a DateTime to dd-MM-yyyy HH:mm (24-hour)
  static String formatDateTime(DateTime dt) =>
      DateFormat('dd-MM-yyyy HH:mm').format(dt);

  // Format time; withSeconds true -> HH:mm:ss, else HH:mm
  static String formatTime(DateTime dt, {bool withSeconds = false}) =>
      withSeconds
      ? DateFormat('HH:mm:ss').format(dt)
      : DateFormat('HH:mm').format(dt);

  // Parse ISO string to DateTime (returns null on failure)
  static DateTime? tryParseIso(String? iso) {
    if (iso == null) return null;
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return null;
    }
  }

  // Convenience: format ISO string to dd-MM-yyyy
  static String formatDateFromIso(String? iso) {
    final dt = tryParseIso(iso);
    if (dt == null) return iso ?? '-';
    return formatDate(dt.toLocal());
  }

  // Convenience: format ISO string to dd-MM-yyyy HH:mm
  static String formatDateTimeFromIso(String? iso) {
    final dt = tryParseIso(iso);
    if (dt == null) return iso ?? '-';
    return formatDateTime(dt.toLocal());
  }
}
