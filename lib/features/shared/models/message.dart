class Message {
  final int id;
  final int senderId;
  final int receiverId;
  final String content;
  final DateTime? sentAt;
  final bool? isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.sentAt,
    this.isRead,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      senderId: json['sender_id'] as int,
      receiverId: json['receiver_id'] as int,
      content: json['content'] as String,
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at'] as String) : null,
      isRead: json['is_read'] != null ? (json['is_read'] == 1 || json['is_read'] == true) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'sent_at': sentAt?.toIso8601String(),
      'is_read': isRead == null ? null : (isRead! ? 1 : 0),
    };
  }

  Message copyWith({
    int? id,
    int? senderId,
    int? receiverId,
    String? content,
    DateTime? sentAt,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  String toString() =>
      'Message(id: $id, senderId: $senderId, receiverId: $receiverId, isRead: $isRead, sentAt: $sentAt)';
}
