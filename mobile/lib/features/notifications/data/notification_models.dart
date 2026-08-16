class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.notificationType = 'general',
    this.data = const {},
    this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final String notificationType;
  final Map<String, dynamic> data;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return NotificationItem(
      id: json['id'].toString(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      notificationType: json['notification_type']?.toString() ?? 'general',
      data: rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : const <String, dynamic>{},
      readAt: json['read_at'] == null ? null : DateTime.tryParse(json['read_at'].toString()),
    );
  }
}
