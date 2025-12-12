// bottle_status.dart

class BottleResumoDia {
  final String bottleId;
  final String? time; // formatado dd/mm/yyyy hh:mm

  // final double temperatura;
  // final String unidade;
  // final double volumeML;
  // final double capacidade;
  // final double preenchimento;

  // Novos campos
  final double periodHours;
  final String startTime;
  final String endTime;

  final double initialVolumeML;
  final double finalVolumeML;
  final double totalDrankML;
  final int numRefills;
  final double avgTemperatureC;

  final double? goalML;
  final double? goalProgress;

  BottleResumoDia({
    required this.bottleId,
    this.time,

    // required this.temperatura,
    // required this.unidade,
    // required this.volumeML,
    // required this.capacidade,
    // required this.preenchimento,
    required this.periodHours,
    required this.startTime,
    required this.endTime,

    required this.initialVolumeML,
    required this.finalVolumeML,
    required this.totalDrankML,
    required this.numRefills,
    required this.avgTemperatureC,

    this.goalML,
    this.goalProgress,
  });

  factory BottleResumoDia.fromJson(Map<String, dynamic> json) {
    // Formatar o campo "time" como antes
    // final parsedTime = DateTime.parse(
    //   json["time"],
    // ).subtract(const Duration(hours: 3));

    final parsedStart = DateTime.parse(
      json["start_time"],
    ).subtract(const Duration(hours: 3));

    final parsedEnd = DateTime.parse(
      json["end_time"],
    ).subtract(const Duration(hours: 3));

    return BottleResumoDia(
      bottleId: json["bottleId"],
      periodHours: (json["period_hours"] as num).toDouble(),
      startTime: _formatDate(parsedStart),
      endTime: _formatDate(parsedEnd),

      initialVolumeML: (json["initial_volume_ml"] as num).toDouble(),
      finalVolumeML: (json["final_volume_ml"] as num).toDouble(),
      totalDrankML: (json["total_drank_ml"] as num).toDouble(),
      numRefills: json["num_refills"],
      avgTemperatureC: (json["avg_temperature_c"] as num).toDouble(),

      goalML: json["goal_ml"] != null
          ? (json["goal_ml"] as num).toDouble()
          : null,
      goalProgress: json["goal_progress"] != null
          ? (json["goal_progress"] as num).toDouble()
          : null,
    );
  }
}

// Função auxiliar para formatar datas
String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();

  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');

  return "$day/$month/$year $hour:$minute";
}
