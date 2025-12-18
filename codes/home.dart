// lib/home.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'classifier.dart';
import 'analytics.dart';
import 'logs.dart';





class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  File? _image;

  String? predictedLabel;
  double? confidenceRaw;
  Map<String, double>? scores;

  bool isLoading = false;

  final ImagePicker picker = ImagePicker();
  late CitrusClassifier classifier;

  @override
  void initState() {
    super.initState();
    classifier = CitrusClassifier();
  }

  // Remove index numbers like "0 Lemon"
  String prettyLabel(String raw) {
    return raw.replaceFirst(RegExp(r'^\d+\s*'), '').trim();
  }

  Future<void> pickImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source);

    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      isLoading = true;
      predictedLabel = null;
      confidenceRaw = null;
      scores = null;
    });

    await _classifyAndSave(_image!);
  }

  Future<void> _classifyAndSave(File image) async {
    try {
      final result = await classifier.classify(image);

      final rawLabel = result["label"] ?? "Unknown";
      final double conf =
      (result["confidence"] is num) ? result["confidence"].toDouble() : 0.0;

      final Map<String, double> rawScores =
      Map<String, double>.from(result["scores"] ?? {});

      final cleanLabel = prettyLabel(rawLabel);

      final cleanedScores = {
        for (var e in rawScores.entries) prettyLabel(e.key): e.value
      };

      setState(() {
        predictedLabel = cleanLabel;
        confidenceRaw = conf;
        scores = cleanedScores;
        isLoading = false;
      });

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection("Labarete_CitrusFruit")
          .add({
        "Predicted_Label": cleanLabel,
        "confidence": conf,
        "scores": cleanedScores,
        "Time": Timestamp.now(),
      });
    } catch (e) {
      debugPrint("Classification error: $e");
      setState(() => isLoading = false);
    }
  }

  Widget _buildScores() {
    if (scores == null || scores!.isEmpty) return const SizedBox.shrink();

    final sorted = scores!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          "Confidence per Class",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...sorted.map((e) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(e.key)),
                Text("${(e.value * 100).toStringAsFixed(2)}%"),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepOrange),
              child: Text(
                "Citrus Classification",
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Home"),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text("Analytics"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalyticsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.list),
              title: const Text("Logs"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LogsPage()),
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text("Citrus Fruit Scanner"),
        backgroundColor: Colors.deepOrange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_image == null)
              const Text(
                "Take a photo or choose from gallery to start scanning",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange),
                textAlign: TextAlign.center,
              ),

            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_image!, height: 220),
              ),

            const SizedBox(height: 20),

            if (isLoading)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text("Scanning image...")
                ],
              ),

            if (!isLoading && predictedLabel != null)
              Column(
                children: [
                  Text(
                    predictedLabel!,
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Confidence: ${(confidenceRaw! * 100).toStringAsFixed(2)}%",
                    style: const TextStyle(fontSize: 18),
                  ),
                  _buildScores(),
                ],
              ),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange),
                  onPressed: () => pickImage(ImageSource.camera),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo),
                  label: const Text("Gallery"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange),
                  onPressed: () => pickImage(ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
