import 'dart:math';
import 'dart:typed_data';
import 'package:fftea/fftea.dart';

class AudioAnalysisService {
  /// 16-bit PCM 오디오 데이터로부터 데시벨(dB) 값을 계산합니다.
  ///
  /// [pcmData]는 오디오의 원본 데이터 버퍼입니다.
  /// 데시벨은 소리의 상대적인 크기를 나타내는 로그 스케일 단위입니다.
  double calculateDecibels(Uint8List pcmData) {
    // PCM 데이터가 없으면 최소 데시벨 값을 반환합니다.
    if (pcmData.isEmpty) {
      return -120.0;
    }

    double sumOfSquares = 0;

    // 16비트(2바이트) 단위로 데이터를 읽어 진폭을 계산합니다.
    for (int i = 0; i < pcmData.length; i += 2) {
      // Little-Endian 형식의 2바이트를 하나의 16비트 정수로 변환합니다.
      int sample = (pcmData[i + 1] << 8) | pcmData[i];
      // 16비트 부호 있는 정수로 변환 (범위: -32768 ~ 32767)
      if (sample > 32767) {
        sample -= 65536;
      }

      // 진폭을 -1.0 ~ 1.0 범위로 정규화(normalize)합니다.
      double normalizedSample = sample / 32768.0;

      // 진폭의 제곱을 누적합니다.
      sumOfSquares += normalizedSample * normalizedSample;
    }

    // 제곱합의 평균(Mean Square)을 계산합니다.
    double meanSquare = sumOfSquares / (pcmData.length / 2);

    // 평균의 제곱근(Root Mean Square, RMS)을 계산합니다.
    // RMS는 오디오 신호의 실효 전력을 나타냅니다.
    double rms = sqrt(meanSquare);

    // RMS 값이 0인 경우 (완전한 무음) 로그 계산 오류를 방지합니다.
    if (rms == 0.0) {
      return -120.0;
    }

    // RMS 값을 사용하여 데시벨로 변환합니다. (20 * log10(rms))
    // 기준 진폭(1.0)에 대한 상대적인 크기를 나타냅니다.
    double db = 20 * (log(rms) / ln10);

    // 데시벨 값은 일반적으로 음수로 표현됩니다. 0dB가 최대 크기입니다.
    return db;
  }

  // 음계와 그에 해당하는 기준 주파수를 정의한 맵
  static const Map<String, double> _noteFrequencies = {
    'C4': 261.63,
    'C#4': 277.18,
    'D4': 293.66,
    'D#4': 311.13,
    'E4': 329.63,
    'F4': 349.23,
    'F#4': 369.99,
    'G4': 392.00,
    'G#4': 415.30,
    'A4': 440.00,
    'A#4': 466.16,
    'B4': 493.88,
    'C5': 523.25,
    'C#5': 554.37,
    'D5': 587.33,
    'D#5': 622.25,
    'E5': 659.25,
    'F5': 698.46,
    'F#5': 739.99,
    'G5': 783.99,
    'G#5': 830.61,
    'A5': 880.00,
    'A#5': 932.33,
    'B5': 987.77,
  };

  /// PCM 데이터로부터 주파수를 분석하여 현재 음계를 식별합니다.
  ///
  /// [pcmData]는 오디오 원본 데이터입니다.
  /// [sampleRate]는 오디오의 샘플링 레이트 (예: 44100Hz)입니다.
  String? analyzePitch(Uint8List pcmData, int sampleRate) {
    if (pcmData.isEmpty) {
      return null;
    }

    // 1. PCM 데이터를 Float64List로 변환
    final samples = _convertPcmToFloat(pcmData);

    // 2. FFT 수행
    final fft = FFT(samples.length);
    final freq = fft.realFft(samples);

    // 3. 가장 큰 진폭(에너지)을 가진 주파수 인덱스 찾기
    double maxAmplitude = -1.0;
    int maxIndex = 0;

    // Float64x2List를 순회하며 각 복소수의 진폭을 계산합니다.
    for (int i = 1; i < (samples.length / 2); i++) {
      // FFT 결과(복소수)의 실수부(real)와 허수부(imaginary)
      final double real = freq[i].x;
      final double imag = freq[i].y;

      // 진폭(Amplitude) 계산: sqrt(real^2 + imag^2)
      final double amplitude = sqrt(real * real + imag * imag);

      if (amplitude > maxAmplitude) {
        maxAmplitude = amplitude;
        maxIndex = i;
      }
    }

    // 4. 인덱스를 실제 주파수(Hz)로 변환
    final dominantFrequency = (maxIndex * sampleRate) / samples.length;

    // 5. 가장 가까운 음계 찾기
    return _findClosestNote(dominantFrequency);
  }

  /// 16비트 PCM 데이터를 -1.0 ~ 1.0 범위의 Float64List로 변환합니다.
  Float64List _convertPcmToFloat(Uint8List pcmData) {
    final samples = Float64List(pcmData.length ~/ 2);
    for (int i = 0; i < samples.length; i++) {
      int sample = (pcmData[i * 2 + 1] << 8) | pcmData[i * 2];
      if (sample > 32767) {
        sample -= 65536;
      }
      samples[i] = sample / 32768.0;
    }
    return samples;
  }

  /// 주어진 주파수와 가장 가까운 음계를 맵에서 찾아 반환합니다.
  String? _findClosestNote(double frequency) {
    if (frequency == 0) return null;

    String? closestNote;
    double minDifference = double.infinity;

    _noteFrequencies.forEach((note, noteFrequency) {
      final difference = (frequency - noteFrequency).abs();
      if (difference < minDifference) {
        minDifference = difference;
        closestNote = note;
      }
    });

    return closestNote;
  }
}
