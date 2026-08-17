// Генератор звуков «Uzun narda».
//
// Звуки синтезируются здесь же, а не берутся из чужих библиотек: так у файлов
// нет постороннего копирайта и они весят десятки килобайт. Запуск:
//
//   cd app && dart run tool/generate_sounds.dart
//
// Пересобирать нужно только при правке этого файла — сами .wav лежат в
// assets/sounds/ и коммитятся.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 22050;

void main() {
  final Directory out = Directory('assets/sounds');
  out.createSync(recursive: true);

  _write('${out.path}/dice.wav', _dice());
  _write('${out.path}/checker.wav', _checker());
  _write('${out.path}/win.wav', _win());
  _write('${out.path}/lose.wav', _lose());
}

void _write(String path, List<double> samples) {
  final File file = File(path)..writeAsBytesSync(_wav(_normalize(samples)));
  stdout.writeln('${file.path}  ${(file.lengthSync() / 1024).toStringAsFixed(1)} КБ');
}

/// Кости: два деревянных удара с отскоком — стук по доске и откат.
List<double> _dice() {
  final List<double> buffer = _silence(0.62);
  _knock(buffer, at: 0.00, gain: 1.00, pitch: 420, decay: 42);
  _knock(buffer, at: 0.09, gain: 0.72, pitch: 500, decay: 52);
  _knock(buffer, at: 0.17, gain: 0.45, pitch: 610, decay: 64);
  _knock(buffer, at: 0.31, gain: 0.55, pitch: 380, decay: 46);
  _knock(buffer, at: 0.38, gain: 0.30, pitch: 470, decay: 60);
  return buffer;
}

/// Шашка: один короткий сухой щелчок по дереву.
List<double> _checker() {
  final List<double> buffer = _silence(0.18);
  _knock(buffer, at: 0.0, gain: 1.0, pitch: 720, decay: 70);
  return buffer;
}

/// Победа: восходящая пентатоника — короткая праздничная фраза.
List<double> _win() {
  final List<double> buffer = _silence(1.45);
  const List<double> notes = <double>[523.25, 587.33, 698.46, 783.99, 1046.50];
  for (int i = 0; i < notes.length; i++) {
    _pluck(
      buffer,
      at: 0.10 * i,
      frequency: notes[i],
      gain: i == notes.length - 1 ? 1.0 : 0.62,
      decay: i == notes.length - 1 ? 3.2 : 6.5,
    );
  }
  _pluck(buffer, at: 0.40, frequency: 261.63, gain: 0.45, decay: 3.0);
  return buffer;
}

/// Поражение: две нисходящие ноты, без драматизма.
List<double> _lose() {
  final List<double> buffer = _silence(1.0);
  _pluck(buffer, at: 0.00, frequency: 392.00, gain: 0.7, decay: 5.0);
  _pluck(buffer, at: 0.16, frequency: 293.66, gain: 0.8, decay: 3.0);
  return buffer;
}

List<double> _silence(double seconds) =>
    List<double>.filled((seconds * sampleRate).round(), 0);

/// Подмешивает в буфер отрезок длиной [seconds], начиная с секунды [at]:
/// [sample] считает один отсчёт по времени от начала отрезка. Хвост, не
/// поместившийся в буфер, отбрасывается.
void _mix(
  List<double> buffer, {
  required double at,
  required double seconds,
  required double Function(double t) sample,
}) {
  final int start = (at * sampleRate).round();
  final int length = math.min(
    buffer.length - start,
    (sampleRate * seconds).round(),
  );
  for (int i = 0; i < length; i++) {
    buffer[start + i] += sample(i / sampleRate);
  }
}

/// Удар дерева о дерево: всплеск шума плюс затухающий резонанс корпуса.
void _knock(
  List<double> buffer, {
  required double at,
  required double gain,
  required double pitch,
  required double decay,
}) {
  final math.Random random = math.Random(pitch.round());
  double lowpass = 0;
  _mix(
    buffer,
    at: at,
    seconds: 0.16,
    sample: (double t) {
      final double envelope = math.exp(-decay * t);
      final double noise = random.nextDouble() * 2 - 1;
      lowpass += (noise - lowpass) * 0.55;
      final double body =
          math.sin(2 * math.pi * pitch * t) * 0.6 +
          math.sin(2 * math.pi * pitch * 2.7 * t) * 0.25;
      return gain * envelope * (lowpass * 0.75 + body * 0.55);
    },
  );
}

/// Щипок: основной тон с обертонами и мягкой атакой.
void _pluck(
  List<double> buffer, {
  required double at,
  required double frequency,
  required double gain,
  required double decay,
}) => _mix(
  buffer,
  at: at,
  seconds: 0.9,
  sample: (double t) {
    final double attack = math.min(1, t / 0.008);
    final double envelope = attack * math.exp(-decay * t);
    final double wave =
        math.sin(2 * math.pi * frequency * t) +
        math.sin(2 * math.pi * frequency * 2 * t) * 0.30 +
        math.sin(2 * math.pi * frequency * 3 * t) * 0.12;
    return gain * envelope * wave * 0.45;
  },
);

/// Приводит пик к −1 дБ, чтобы ничего не клиппировало.
List<double> _normalize(List<double> samples) {
  double peak = 0;
  for (final double value in samples) {
    peak = math.max(peak, value.abs());
  }
  if (peak == 0) return samples;
  final double scale = 0.89 / peak;
  return <double>[for (final double value in samples) value * scale];
}

/// 16-битный моно PCM WAV.
Uint8List _wav(List<double> samples) {
  final int dataBytes = samples.length * 2;
  final ByteData data = ByteData(44 + dataBytes);
  void ascii(int offset, String value) {
    for (int i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little); // размер блока fmt
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // моно
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little); // байт в секунду
  data.setUint16(32, 2, Endian.little); // выравнивание блока
  data.setUint16(34, 16, Endian.little); // бит на отсчёт
  ascii(36, 'data');
  data.setUint32(40, dataBytes, Endian.little);

  for (int i = 0; i < samples.length; i++) {
    final int value = (samples[i] * 32767).round().clamp(-32768, 32767);
    data.setInt16(44 + i * 2, value, Endian.little);
  }
  return data.buffer.asUint8List();
}
