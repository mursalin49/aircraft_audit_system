class AuditItem {
  String id;
  String status; // Pass/Fail
  String? imagePath;

  AuditItem({required this.id, required this.status, this.imagePath});

  Map<String, dynamic> toJson() => {'id': id, 'status': status, 'imagePath': imagePath};
  factory AuditItem.fromJson(Map<String, dynamic> json) => AuditItem(
      id: json['id'], status: json['status'], imagePath: json['imagePath']
  );
}