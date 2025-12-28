import 'dart:convert';

class Measurement {
  final String id;
  final double score; // [CHANGE] int -> double
  final DateTime timestamp;

  Measurement({required this.id, required this.score, required this.timestamp});

  Map<String, dynamic> toJson() => {
    'id': id,
    'score': score,
    'timestamp': timestamp.toIso8601String(),
  };

  factory Measurement.fromJson(Map<String, dynamic> json) => Measurement(
    id: json['id'] as String,
    score: (json['score'] as num)
        .toDouble(), // [CHANGE] cast to num then double
    timestamp: DateTime.parse(json['timestamp'] as String),
  );

  static String encodeList(List<Measurement> measurements) =>
      jsonEncode(measurements.map((m) => m.toJson()).toList());

  static List<Measurement> decodeList(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList
        .map((json) => Measurement.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
