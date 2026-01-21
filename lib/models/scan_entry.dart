class ScanEntry {
  final String value;
  final String format;
  final DateTime createdAt;

  const ScanEntry({
    required this.value,
    required this.format,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'value': value,
    'format': format,
    'createdAt': createdAt.toIso8601String(),
  };

  static ScanEntry fromJson(Map<String, dynamic> json) {
    return ScanEntry(
      value: (json['value'] ?? '').toString(),
      format: (json['format'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
