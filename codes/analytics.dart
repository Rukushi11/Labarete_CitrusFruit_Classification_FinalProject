// lib/analytics_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final List<String> fruitClasses = [
    "Lemon",
    "Orange",
    "Calamansi",
    "Pomelo",
    "Kumquat",
    "Buddha's Han...",
    "Mandarin",
    "Grapefruit",
    "Finger Lime",
    "Kaffir Lime",
  ];

  final Map<String, Color> fruitColors = {
    "Lemon": Colors.yellow,
    "Orange": Colors.orange,
    "Calamansi": Colors.green,
    "Pomelo": Colors.lightGreen,
    "Kumquat": Colors.amber,
    "Buddha's Han...": Colors.deepOrange,
    "Mandarin": Colors.orangeAccent,
    "Grapefruit": Colors.redAccent,
    "Finger Lime": Colors.teal,
    "Kaffir Lime": Colors.greenAccent,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analytics"),
        backgroundColor: Colors.deepOrange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("Labarete_CitrusFruit")
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final Map<String, int> counts = {
            for (var f in fruitClasses) f: 0
          };
          final Map<String, List<double>> confs = {
            for (var f in fruitClasses) f: []
          };

          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final label = data["Predicted_Label"];
            final conf = (data["confidence"] ?? 0).toDouble();

            if (label != null && counts.containsKey(label)) {
              counts[label] = counts[label]! + 1;
              confs[label]!.add(conf * 100);
            }
          }

          final Map<String, double> avgConf = {
            for (var f in fruitClasses)
              f: confs[f]!.isEmpty
                  ? 0
                  : confs[f]!.reduce((a, b) => a + b) / confs[f]!.length
          };

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Detection Count per Class",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 320,
                  child: BarChart(
                    BarChartData(
                      barGroups: List.generate(fruitClasses.length, (i) {
                        final fruit = fruitClasses[i];
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: counts[fruit]!.toDouble(),
                              width: 18,
                              color: fruitColors[fruit],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        );
                      }),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1, // count steps: 0,1,2,3...
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              );
                            },
                          ),
                        ),

                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 80,
                            getTitlesWidget: (value, meta) {
                              return Transform.rotate(
                                angle: -pi / 3,
                                child: Text(
                                  fruitClasses[value.toInt()],
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                const Text(
                  "Average Confidence (%)",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 300,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          barWidth: 3,
                          color: Colors.deepOrange,
                          dotData: FlDotData(show: true),
                          spots: List.generate(
                            fruitClasses.length,
                                (i) => FlSpot(
                              i.toDouble(),
                              avgConf[fruitClasses[i]]!,
                            ),
                          ),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 10, // 0,10,20,...100
                            reservedSize: 44,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              );
                            },
                          ),
                        ),

                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 80,
                            getTitlesWidget: (value, meta) {
                              return Transform.rotate(
                                angle: -pi / 3,
                                child: Text(
                                  fruitClasses[value.toInt()],
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                const Text(
                  "Detailed Data",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                /// ✅ FIX: Horizontal scroll to prevent overflow
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 28,
                    columns: const [
                      DataColumn(label: Text("Fruit Class")),
                      DataColumn(label: Text("Scan Count")),
                      DataColumn(label: Text("Avg Confidence (%)")),
                    ],
                    rows: fruitClasses.map((fruit) {
                      return DataRow(cells: [
                        DataCell(Text(fruit)),
                        DataCell(Text(counts[fruit].toString())),
                        DataCell(
                          Text(avgConf[fruit]!.toStringAsFixed(2)),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
