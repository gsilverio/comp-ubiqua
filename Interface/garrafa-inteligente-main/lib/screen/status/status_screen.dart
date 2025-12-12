import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:garrafa_inteligente/model/bottle_resumo_dia.dart';
import 'package:garrafa_inteligente/service/api_service.dart';
import 'package:garrafa_inteligente/model/bottle_status.dart';
import 'package:garrafa_inteligente/widget/nav_bar.dart';

// Página de status da garrafa
class BottleStatusPage extends StatefulWidget {
  final String bottleId;

  const BottleStatusPage({super.key, required this.bottleId});

  @override
  State<BottleStatusPage> createState() => _BottleStatusPageState();
}

class _BottleStatusPageState extends State<BottleStatusPage> {
  late Future<BottleStatusModel> _futureStatus;
  late Future<BottleResumoDia> _futureResumoDia;

  @override
  void initState() {
    super.initState();
    _futureStatus = ApiService.fetchBottleStatus(widget.bottleId);
    _futureResumoDia = ApiService.fetchBottleResumoDia(widget.bottleId);
  }

  void _onItemTapped(int index) {
    final ref = FirebaseDatabase.instance.ref("app_state/active_screen");

    if (index == 0) {
      ref.set("status");
    } else if (index == 1) {
      ref.set("historico");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        leading: SizedBox(width: 0),
        leadingWidth: 0,
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<BottleStatusModel>(
            future: _futureStatus,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return Text('Erro: ${snapshot.error}');
              } else if (snapshot.hasData) {
                final status = snapshot.data!;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 16,
                      children: [
                        Text(
                          'STATUS',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bottle ID: ${status.bottleId}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Temperatura: ${status.temperatura}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Última atualização: ${status.time}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                return const Text('Nenhum dado');
              }
            },
          ),
          const SizedBox(height: 16),
          FutureBuilder<BottleResumoDia>(
            future: _futureResumoDia,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return Text('Erro: ${snapshot.error}');
              } else if (snapshot.hasData) {
                final status = snapshot.data!;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 16,
                      children: [
                        Text(
                          'RESUMO DO DIA',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Período (horas): ${status.periodHours}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              'Início: ${status.startTime}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              'Fim: ${status.endTime}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              'Volume inicial (mL): ${status.initialVolumeML.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              'Volume final (mL): ${status.finalVolumeML.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              'Total ingerido (mL): ${status.totalDrankML.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              'Reabastecimentos: ${status.numRefills}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),

                            Text(
                              'Temperatura média (°C): ${status.avgTemperatureC.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                return const Text('Nenhum dado');
              }
            },
          ),
        ],
      ),

      bottomNavigationBar: BottleNavBar(selectedIndex: 0, onTap: _onItemTapped),
    );
  }
}
