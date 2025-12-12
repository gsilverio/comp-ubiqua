import 'dart:convert';
import 'package:garrafa_inteligente/model/bottle_resumo_dia.dart';
import 'package:http/http.dart' as http;
import '../model/bottle_status.dart';

class ApiService {
  // Documentação: http://13.217.153.230:8000/docs
  static const String baseUrl = 'http://13.217.153.230:8000';

  static Future<BottleStatusModel> fetchBottleStatus(String bottleId) async {
    final url = Uri.parse('$baseUrl/api/garrafas/$bottleId/status');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonBody = json.decode(response.body);
      return BottleStatusModel.fromJson(jsonBody);
    } else {
      throw Exception(
        'Falha ao carregar status da garrafa: ${response.statusCode}',
      );
    }
  }

  static Future<List<BottleStatusModel>> fetchBottleHistory(
    String bottleId,
  ) async {
    final url = Uri.parse(
      '$baseUrl/api/garrafas/$bottleId/historico?horas=168',
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> jsonBody = json.decode(response.body);

      // Converte cada item para BottleStatusModel
      var listOfMaps = jsonBody
          .map((item) => BottleStatusModel.fromJson(item))
          .toList();
      return listOfMaps;
    } else {
      throw Exception(
        'Falha ao carregar histórico da garrafa: ${response.statusCode}',
      );
    }
  }

  static Future<BottleResumoDia> fetchBottleResumoDia(String bottleId) async {
    final url = Uri.parse('$baseUrl/api/garrafas/$bottleId/resumo-dia');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonBody = json.decode(response.body);
      return BottleResumoDia.fromJson(jsonBody);
    } else {
      throw Exception(
        'Falha ao carregar status da garrafa: ${response.statusCode}',
      );
    }
  }

  static Future<BottleResumoDia> fetchBottleHealth(String bottleId) async {
    final url = Uri.parse('$baseUrl/api/health');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonBody = json.decode(response.body);
      return BottleResumoDia.fromJson(jsonBody);
    } else {
      throw Exception(
        'Falha ao carregar status da garrafa: ${response.statusCode}',
      );
    }
  }
}
