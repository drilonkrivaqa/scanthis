import 'package:intl/intl.dart';

final _dt = DateFormat('yyyy-MM-dd • HH:mm');

String formatDate(DateTime d) => _dt.format(d);
