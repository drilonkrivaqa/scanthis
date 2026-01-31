class Folder {
  final String id;
  final String name;

  const Folder({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  static Folder fromJson(Map<String, dynamic> json) => Folder(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? 'Folder').toString(),
      );

  Folder copyWith({String? name}) => Folder(id: id, name: name ?? this.name);
}
