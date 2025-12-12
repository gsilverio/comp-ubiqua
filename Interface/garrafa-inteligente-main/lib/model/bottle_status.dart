// bottle_status.dart
class BottleStatusModel {
  final String bottleId;
  final String time;
  final double temperatura;
  final String unidade;
  final double volumeML;
  final double capacidade;
  final double preenchimento;
  // adicione outros campos conforme sua API

  BottleStatusModel({
    required this.bottleId,
    required this.time,
    required this.temperatura,
    required this.unidade,
    required this.volumeML,
    required this.capacidade,
    required this.preenchimento,
  });

  factory BottleStatusModel.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(
      json['time'],
    ).subtract(const Duration(hours: 3));

    return BottleStatusModel(
      bottleId: json['bottleId'] as String,
      time: _formatDate(date),
      temperatura: json['temperature_c'],
      unidade: json['temp_unit'],
      volumeML: json['volume_ml'],
      capacidade: json['capacity_ml'],
      preenchimento: json['percent_full'],
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();

  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');

  return "$day/$month/$year $hour:$minute";
}
