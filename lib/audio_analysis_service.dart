import 'dart:math';
import 'dart:typed_data';
import 'package:fftea/fftea.dart';

class AudioAnalysisService {
  /// 16-bit PCM 오디오 데이터로부터 데시벨(dB) 값을 계산합니다.
  ///
  /// [pcmData]는 오디오의 원본 데이터 버퍼입니다.
  /// 데시벨은 소리의 상대적인 크기를 나타내는 로그 스케일 단위입니다.
  double calculateDecibels(Uint8List pcmData) {
    if (pcmData.isEmpty) {
      return -120.0;
    }

    // 16-bit PCM data, so 2 bytes per sample
    final pcm16 = pcmData.buffer.asInt16List();
    double sumOfSquares = 0.0;
    for (int sample in pcm16) {
      double normalizedSample = sample / 32768.0;
      sumOfSquares += normalizedSample * normalizedSample;
    }

    double rms = sqrt(sumOfSquares / pcm16.length);
    if (rms == 0.0) {
      return -120.0;
    }

    double db = 20 * log(rms) / ln10;
    return db.isFinite ? db : -120.0;
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

  /// FFT를 수행하고, 각 주파수 대역의 진폭(Amplitude) 리스트를 반환합니다.
  /// 시각화를 위해 사용됩니다.
  ///
  /// [pcmData]는 오디오 원본 데이터입니다.
  /// [bandCount]는 시각화에 사용할 막대(주파수 대역)의 개수입니다.
  List<double> getFrequencyAmplitudes(Uint8List pcmData, int bandCount) {
    if (pcmData.isEmpty) {
      return List.filled(bandCount, 0.0);
    }

    // 1. PCM 데이터를 Float64List로 변환
    final samples = _convertPcmToFloat(pcmData);

    // 2. FFT 수행
    final fft = FFT(samples.length);
    final freq = fft.realFft(samples);

    // 3. FFT 결과를 bandCount개의 대역으로 그룹화하고, 각 대역의 평균 진폭을 계산
    final List<double> amplitudes = List.filled(bandCount, 0.0);
    final int bandWidth = (freq.length / 2) ~/ bandCount;

    for (int i = 0; i < bandCount; i++) {
      double maxInBand = 0.0;
      final int start = i * bandWidth;
      final int end = start + bandWidth;

      for (int j = start; j < end; j++) {
        final double real = freq[j].x;
        final double imag = freq[j].y;
        final double amplitude = sqrt(real * real + imag * imag);
        if (amplitude > maxInBand) {
          maxInBand = amplitude;
        }
      }

      // 대역의 평균 진폭을 계산하고, 시각적으로 증폭합니다.
      amplitudes[i] = maxInBand;
    }

    return amplitudes;
  }

  Map<String, dynamic> analyzeFrequency(Uint8List pcmData, {int sampleRate = 44100}) {
    if (pcmData.isEmpty) {
      return {'note': 'N/A', 'fft': List<double>.filled(64, 0)};
    }
    final pcm16 = pcmData.buffer.asInt16List();
    if (pcm16.isEmpty) {
      return {'note': 'N/A', 'fft': List<double>.filled(64, 0)};
    }

    final fft = FFT(pcm16.length);
    final freq = fft.realFft(pcm16.map((e) => e.toDouble()).toList());

    final List<double> amplitudes = [];
    const int bandCount = 64;
    final int samplesPerBand = (freq.length / 2) ~/ bandCount;

    for (int i = 0; i < bandCount; i++) {
      double maxInBand = 0.0;
      for (int j = 0; j < samplesPerBand; j++) {
        final index = i * samplesPerBand + j;
        if (index < freq.length) {
          final complex = freq[index];
          final amplitude = sqrt(complex.x * complex.x + complex.y * complex.y);
          if (amplitude > maxInBand) {
            maxInBand = amplitude;
          }
        }
      }
      amplitudes.add(maxInBand);
    }

    double maxAmplitude = 0;
    int dominantFrequencyIndex = 0;
    for (int i = 0; i < freq.length / 2; i++) {
      final complex = freq[i];
      double amplitude = sqrt(complex.x * complex.x + complex.y * complex.y);
      if (amplitude > maxAmplitude) {
        maxAmplitude = amplitude;
        dominantFrequencyIndex = i;
      }
    }

    if (maxAmplitude < 3500000) {
      return {'note': 'N/A', 'fft': amplitudes};
    }

    double dominantFrequency = dominantFrequencyIndex * sampleRate / pcm16.length;
    String note = _frequencyToNote(dominantFrequency);

    return {'note': note, 'fft': amplitudes};
  }

  String _frequencyToNote(double frequency) {
    if (frequency == 0) return 'N/A';
    const A4 = 440.0;
    const notes = ['A', 'A#', 'B', 'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#'];
    final n = (12 * (log(frequency / A4) / log(2))).round();
    final noteIndex = (n % 12 + 12) % 12;
    final octave = (n / 12).floor() + 4;
    return '${notes[noteIndex]}$octave';
  }
}
