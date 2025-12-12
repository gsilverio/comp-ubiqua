import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'package:garrafa_inteligente/service/api_service.dart';
import 'package:garrafa_inteligente/model/bottle_status.dart';
import 'package:garrafa_inteligente/widget/nav_bar.dart';

class BottleHistoricoPage extends StatefulWidget {
  final String bottleId;

  const BottleHistoricoPage({super.key, required this.bottleId});

  @override
  State<BottleHistoricoPage> createState() => _BottleHistoricoPageState();
}

class _BottleHistoricoPageState extends State<BottleHistoricoPage> {
  late Future<List<BottleStatusModel>> _futureStatus;

  @override
  void initState() {
    super.initState();
    _futureStatus = ApiService.fetchBottleHistory(widget.bottleId);
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
        title: const Text('Histórico', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        leading: SizedBox(width: 0),
        leadingWidth: 0,
      ),
      body: FutureBuilder<List<BottleStatusModel>>(
        future: _futureStatus,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final status = snapshot.data!;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Garrafa: ${status.last.bottleId} (${status.last.volumeML.toStringAsFixed(0)}mL - ${status.first.capacidade.toStringAsFixed(0)}mL)",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    spacing: 16,
                    children: [
                      Text(
                        "${status.first.time} - ${status.last.time}",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  Text(
                    "QTD itens: ${status.length}",
                    style: const TextStyle(fontSize: 14),
                  ),

                  const SizedBox(height: 16),

                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          sortAscending: false,
                          columns: const [
                            DataColumn(label: Text("Data e horário")),
                            DataColumn(label: Text("Temp (°C)")),
                            DataColumn(label: Text("Volume (mL)")),
                          ],
                          rows: status.reversed.map((item) {
                            return DataRow(
                              cells: [
                                DataCell(Text(item.time.toString())),
                                DataCell(
                                  Text(item.temperatura.toStringAsFixed(2)),
                                ),
                                DataCell(
                                  Text(
                                    "${item.volumeML.toStringAsFixed(0)} mL (${(item.preenchimento * 100).toStringAsFixed(0)}%)",
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else {
            return const Center(child: Text('Nenhum dado'));
          }
        },
      ),

      bottomNavigationBar: BottleNavBar(selectedIndex: 1, onTap: _onItemTapped),
    );
  }
}
