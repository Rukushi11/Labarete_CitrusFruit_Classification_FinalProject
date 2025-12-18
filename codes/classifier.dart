import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class CitrusClassifier {
  late Interpreter _interpreter;
  late List<String> _labels;
  final int inputSize = 224;

  CitrusClassifier() {
    _loadModel();
    _loadLabels();
  }

  Future<void> _loadModel() async {
    _interpreter = await Interpreter.fromAsset('assets/model/model_unquant.tflite');

  }

  Future<void> _loadLabels() async {
    final raw = await rootBundle.loadString('assets/model/labels.txt');
    _labels = raw.split('\n').where((e) => e.trim().isNotEmpty).toList();
  }

  Future<Map<String, dynamic>> classify(File imageFile) async {
    // Load and decode image
    final bytes = await imageFile.readAsBytes();
    final raw = img.decodeImage(bytes)!;
    final resized = img.copyResize(raw, width: inputSize, height: inputSize);

    // Allocate input tensor: [1, inputSize, inputSize, 3]
    var input = List.generate(
      1,
          (_) => List.generate(
        inputSize,
            (_) => List.generate(inputSize, (_) => List.filled(3, 0.0)),
      ),
    );

    // Fill tensor with normalized pixel values
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        input[0][y][x][0] = img.getRed(pixel) / 255.0;
        input[0][y][x][1] = img.getGreen(pixel) / 255.0;
        input[0][y][x][2] = img.getBlue(pixel) / 255.0;
      }
    }

    // Output tensor
    var output = List.filled(_labels.length, 0.0).reshape([1, _labels.length]);

    // Run inference
    _interpreter.run(input, output);

    // Find best result
    // After running the interpreter and getting 'output' (shape [1, numLabels]):

// Build scores map
    Map<String, double> scores = {};
    for (int i = 0; i < _labels.length; i++) {
      // output[0][i] is assumed to be a double
      scores[_labels[i]] = (output[0][i] as double);
    }

// determine top
    double maxVal = -1;
    int maxIndex = -1;
    for (int i = 0; i < _labels.length; i++) {
      if (output[0][i] > maxVal) {
        maxVal = output[0][i];
        maxIndex = i;
      }
    }

    return {
      "label": _labels[maxIndex],
      "confidence": maxVal, // 0..1
      "scores": scores,     // map of label -> score (0..1)
    };

  }

}
