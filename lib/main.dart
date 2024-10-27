import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:permission_handler/permission_handler.dart';

// Constants
const SAMPLE_RATE = 48000; // 48 kHz
const DURATION = 60; // Duration in seconds to capture audio
const CHUNK = 2048; // Number of audio samples per frame
const CHANNELS = 1; // Single microphone input

FlutterAudioCapture plugin = FlutterAudioCapture();
List<double> audioData = [];

void listener(dynamic obj) {
  var buffer = Float64List.fromList(obj.cast<double>());
  audioData.addAll(buffer);
  print(buffer);
}

// Callback function if flutter_audio_capture failure to register
// audio capture stream subscription.
void onError(Object e) {
  print(e);
}

// Function to simulate audio capture (replace this with real microphone input handling if needed)
Future<List<double>> captureAudio(int duration, int sampleRate) async {
  await plugin.init();
  await plugin.start(listener, onError, sampleRate: 16000, bufferSize: 3000);

  await plugin.stop();

  return audioData;



  print("Starting audio capture simulation...");
  // Simulate an audio signal (this is a placeholder for actual audio capture)
  List<double> signal = List<double>.generate(duration * sampleRate, (i) {
    return sin(2 * pi * 440 * i / sampleRate); // Example of a 440Hz tone
  });
  print("Audio capture finished.");
  return signal;
}

// Function to down-convert the signal to complex baseband (ignoring the imaginary part for simplicity)
List<double> downConvert(List<double> signal, double fc, int samplingRate) {
  print("Down-converting signal to baseband...");
  List<double> downConverted = List<double>.generate(signal.length, (i) {
    double t = i / samplingRate;
    return signal[i] * cos(2 * pi * fc * t); // Simplified without complex numbers
  });
  return downConverted;
}

// Function to extract phase information from the signal
List<double> extractPhase(List<double> signal) {
  print("Extracting phase information...");
  List<double> phase = List<double>.generate(signal.length, (i) {
    return atan2(signal[i], 1); // Simplified phase extraction
  });
  return phase;
}

// Function to smooth the phase signal using a moving average
List<double> smoothSignal(List<double> signal, int windowSize) {
  List<double> smoothed = List<double>.generate(signal.length, (i) {
    int start = max(0, i - windowSize ~/ 2);
    int end = min(signal.length - 1, i + windowSize ~/ 2);
    double sum = 0.0;
    for (int j = start; j <= end; j++) {
      sum += signal[j];
    }
    return sum / (end - start + 1);
  });
  return smoothed;
}

// Function to extract heart rate from the phase signal over windows
List<double?> extractHeartRatesWindowed(List<double> phaseSignal, int samplingRate, int windowDuration) {
  print("Extracting breath and heart rates over time...");
  int windowSize = windowDuration * samplingRate;
  int numWindows = phaseSignal.length ~/ windowSize;
  List<double?> heartRates = [];

  for (int i = 0; i < numWindows; i++) {
    List<double> windowSignal = phaseSignal.sublist(i * windowSize, (i + 1) * windowSize);
    double heartRate = _calculateHeartRate(windowSignal, samplingRate);
    heartRates.add(heartRate);
  }

  return heartRates;
}

// Helper function to calculate heart rate from the signal
double _calculateHeartRate(List<double> signal, int samplingRate) {
  // Perform a simplified frequency analysis using zero crossings
  int zeroCrossings = 0;
  for (int i = 1; i < signal.length; i++) {
    if (signal[i - 1] * signal[i] < 0) {
      zeroCrossings++;
    }
  }
  double frequency = zeroCrossings / (2 * (signal.length / samplingRate));
  double heartRateBpm = frequency * 60;

  // Check if it's in the typical heart rate range
  if (heartRateBpm >= 48 && heartRateBpm <= 120) {
    return heartRateBpm;
  }
  return double.nan;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (await Permission.audio.request().isDenied) {
    throw Exception("Need audio recording permission");
  }

  // Capture audio data (replace this with actual audio capturing in real use case)
  List<double> audioSignal = await captureAudio(DURATION, SAMPLE_RATE);

  // Down-convert the audio signal
  const double fc = 19000; // Example center frequency (19 kHz)
  List<double> basebandSignal = downConvert(audioSignal, fc, SAMPLE_RATE);

  // Extract phase information from the baseband signal
  List<double> signalPhase = extractPhase(basebandSignal);

  // Smooth the phase signal
  List<double> signalPhaseSmoothed = smoothSignal(signalPhase, 100);

  // Perform windowed heart rate extraction
  List<double?> heartRates = extractHeartRatesWindowed(signalPhaseSmoothed, SAMPLE_RATE, 5);

  // Calculate average, max, and min heart rates
  List<double> validHeartRates = heartRates.where((hr) => hr != null && hr!.isFinite).cast<double>().toList();

  if (validHeartRates.isNotEmpty) {
    double avgHeartRate = validHeartRates.reduce((a, b) => a + b) / validHeartRates.length;
    double maxHeartRate = validHeartRates.reduce(max);
    double minHeartRate = validHeartRates.reduce(min);

    print("Estimated Average Heart Rate: ${avgHeartRate.toStringAsFixed(2)} BPM");
    print("Estimated Maximum Heart Rate: ${maxHeartRate.toStringAsFixed(2)} BPM");
    print("Estimated Minimum Heart Rate: ${minHeartRate.toStringAsFixed(2)} BPM");
  } else {
    print("No valid heart rate data found.");
  }
}
