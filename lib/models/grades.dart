// Notas da escola: cada escola tem o seu jeito, então tudo é configurável.
// Ex.: 3 unidades; em cada uma, Qualitativo (2) + Simulados (8) + Prova (8) + Projeto (2).
// Uma matéria pode ter partes diferentes (mais projeto, menos prova...).

import 'models.dart';

class GradePart {
  String name;
  double max;
  GradePart(this.name, this.max);

  Map<String, dynamic> toJson() => {'name': name, 'max': max};

  static GradePart? fromJson(Map<String, dynamic> m) {
    final name = readStr(m, 'name');
    final max = m['max'];
    if (name.isEmpty || max is! num || !max.isFinite || max <= 0) return null;
    return GradePart(name, max.toDouble().clamp(0.1, 1000).toDouble());
  }
}

List<GradePart> defaultGradeParts() => [
      GradePart('Qualitativo', 2),
      GradePart('Simulados', 8),
      GradePart('Prova', 8),
      GradePart('Projeto', 2),
    ];

class GradeConfig {
  int units; // quantas unidades/bimestres/trimestres no ano
  String unitName; // "Unidade", "Bimestre", "Trimestre"
  List<GradePart> parts; // partes padrão de cada unidade
  Map<String, List<GradePart>> bySubject; // partes diferentes para uma matéria
  double passPct; // % do total do ano para passar (ex.: 60)

  GradeConfig({this.units = 3, this.unitName = 'Unidade', List<GradePart>? parts, Map<String, List<GradePart>>? bySubject, this.passPct = 60})
      : parts = parts ?? defaultGradeParts(),
        bySubject = bySubject ?? {};

  List<GradePart> partsFor(String subjectId) => bySubject[subjectId] ?? parts;
  double unitMax(String subjectId) => partsFor(subjectId).fold(0, (a, p) => a + p.max);
  double yearMax(String subjectId) => unitMax(subjectId) * units;
  double passPoints(String subjectId) => yearMax(subjectId) * passPct / 100;

  Map<String, dynamic> toJson() => {
        'units': units,
        'unitName': unitName,
        'parts': parts.map((p) => p.toJson()).toList(),
        'bySubject': bySubject.map((k, v) => MapEntry(k, v.map((p) => p.toJson()).toList())),
        'passPct': passPct,
      };

  static GradeConfig fromJson(Map<String, dynamic> m) {
    List<GradePart> partsOf(dynamic raw) => raw is List
        ? raw.whereType<Map>().map((e) => GradePart.fromJson(Map<String, dynamic>.from(e))).whereType<GradePart>().toList()
        : <GradePart>[];
    final parts = partsOf(m['parts']);
    final by = <String, List<GradePart>>{};
    final rawBy = m['bySubject'];
    if (rawBy is Map) {
      rawBy.forEach((k, v) {
        final l = partsOf(v);
        if (k is String && l.isNotEmpty) by[k] = l;
      });
    }
    final pct = m['passPct'];
    final name = readStr(m, 'unitName');
    return GradeConfig(
      units: readInt(m, 'units', 3, min: 1, max: 6),
      unitName: name.isEmpty ? 'Unidade' : name,
      parts: parts.isEmpty ? null : parts,
      bySubject: by,
      passPct: pct is num && pct.isFinite ? pct.toDouble().clamp(1, 100).toDouble() : 60,
    );
  }
}

/// Uma nota lançada: matéria, unidade (1..N), parte (pelo nome) e valor.
class Grade {
  String subjectId;
  int unit;
  String part;
  double value;
  Grade({required this.subjectId, required this.unit, required this.part, required this.value});

  Map<String, dynamic> toJson() => {'subjectId': subjectId, 'unit': unit, 'part': part, 'value': value};

  static Grade? fromJson(Map<String, dynamic> m) {
    final sid = readStr(m, 'subjectId');
    final part = readStr(m, 'part');
    final v = m['value'];
    if (sid.isEmpty || part.isEmpty || v is! num || !v.isFinite || v < 0) return null;
    return Grade(subjectId: sid, unit: readInt(m, 'unit', 1, min: 1, max: 6), part: part, value: v.toDouble());
  }
}

/// Situação de uma matéria no ano.
class GradeStatus {
  final double earned; // pontos já tirados
  final double launchedMax; // quanto valiam as partes já lançadas
  final double remainingMax; // quanto ainda dá para tirar (partes sem nota)
  final double pass; // pontos para passar
  const GradeStatus(this.earned, this.launchedMax, this.remainingMax, this.pass);

  double get missing => (pass - earned) > 0 ? pass - earned : 0;
  bool get passed => earned >= pass - 1e-9;
  bool get impossible => !passed && missing > remainingMax + 1e-9;

  /// Média que precisa tirar no que falta (0 a 100%).
  double? get neededPct => remainingMax <= 0 || passed ? null : (missing / remainingMax * 100);
  double? get currentPct => launchedMax <= 0 ? null : earned / launchedMax * 100;
}

GradeStatus gradeStatus(GradeConfig c, List<Grade> grades, String subjectId) {
  var earned = 0.0, launched = 0.0, remaining = 0.0;
  final parts = c.partsFor(subjectId);
  for (var u = 1; u <= c.units; u++) {
    for (final p in parts) {
      final g = grades.where((g) => g.subjectId == subjectId && g.unit == u && g.part == p.name);
      if (g.isEmpty) {
        remaining += p.max;
      } else {
        earned += g.first.value.clamp(0, p.max);
        launched += p.max;
      }
    }
  }
  return GradeStatus(earned, launched, remaining, c.passPoints(subjectId));
}

String fmtPts(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1).replaceAll('.', ',');
}
