import 'package:flutter/material.dart';
import 'package:garrafa_inteligente/model/bottle_status.dart';

class BottleHistoryTable extends StatelessWidget {
  final List<BottleStatusModel> items;

  const BottleHistoryTable({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: DataTable(
        columns: const [
          DataColumn(label: Text("Horário")),
          DataColumn(label: Text("Peso")),
          DataColumn(label: Text("Temp.")),
          DataColumn(label: Text("Status")),
        ],
        rows: items.map((status) {
          return DataRow(
            cells: [
              DataCell(Text(status.toString())),
              DataCell(Text(status.toString())),
              DataCell(Text(status.toString())),
              DataCell(Text(status.toString())),
            ],
          );
        }).toList(),
      ),
    );
  }
}
