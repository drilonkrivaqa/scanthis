String newId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  return 'scan_$now';
}
