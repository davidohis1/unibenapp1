class Summary {
  final String id;
  final String pdfUrl;
  final String title;
  final String content;
  final DateTime createdAt;
  final int chunksProcessed;
  final List<String> quizIds;
  final int timesViewed;

  Summary({
    required this.id,
    required this.pdfUrl,
    required this.title,
    required this.content,
    required this.createdAt,
    this.chunksProcessed = 0,
    this.quizIds = const [],
    this.timesViewed = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pdfUrl': pdfUrl,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'chunksProcessed': chunksProcessed,
      'quizIds': quizIds,
      'timesViewed': timesViewed,
    };
  }

  factory Summary.fromJson(Map<String, dynamic> json) {
    return Summary(
      id: json['id'] ?? '',
      pdfUrl: json['pdfUrl'] ?? '',
      title: json['title'] ?? 'Untitled Summary',
      content: json['content'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      chunksProcessed: json['chunksProcessed'] ?? 0,
      quizIds: List<String>.from(json['quizIds'] ?? []),
      timesViewed: json['timesViewed'] ?? 0,
    );
  }
}