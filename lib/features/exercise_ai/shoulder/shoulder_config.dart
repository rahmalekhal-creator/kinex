/// The bundle's settings: app_spec.json (MediaPipe, pipeline, feedback) and the model config
/// (mt_final.json or separate.json: per-exercise head = input_selection, features, classes).
library;

class HeadConfig {
  final String exercise;
  final List<String> classes;
  final List<String> storedChannels;
  final List<int> inputSelection;
  final List<String> features;
  final bool needsSilhouette;
  final String onnxFile;

  HeadConfig.fromJson(this.exercise, Map<String, dynamic> j)
    : classes = (j['classes'] as List).cast<String>(),
      storedChannels = (j['stored_channels'] as List).cast<String>(),
      inputSelection = (j['input_selection'] as List).cast<int>(),
      features = (j['features'] as List).cast<String>(),
      needsSilhouette = j['needs_silhouette'] == true,
      onnxFile = j['onnx_file'] as String;

  List<String> get inputChannels => [
    for (final i in inputSelection) storedChannels[i],
  ];
}

class SegConfig {
  final double minRepS, maxRepS, prominence;
  const SegConfig(this.minRepS, this.maxRepS, this.prominence);
}

/// analyze_video settings of the model config.
class AnalyzeConfig {
  final double fs, maxGapS, marginS, minValid;
  final int tLen;
  final Map<String, SegConfig> seg;
  final double baseS, gapS, minS;

  AnalyzeConfig.fromJson(Map<String, dynamic> j)
    : fs = (j['FS'] as num).toDouble(),
      maxGapS = (j['MAX_GAP_S'] as num).toDouble(),
      marginS = (j['MARGIN_S'] as num).toDouble(),
      minValid = (j['MIN_VALID'] as num).toDouble(),
      tLen = j['T_LEN'] as int,
      seg = {
        for (final e in (j['SEG'] as Map<String, dynamic>).entries)
          e.key: SegConfig(
            (e.value['min_rep_s'] as num).toDouble(),
            (e.value['max_rep_s'] as num).toDouble(),
            (e.value['prominence'] as num).toDouble(),
          ),
      },
      baseS = (j['BASE_CFG']['base_s'] as num).toDouble(),
      gapS = (j['BASE_CFG']['gap_s'] as num).toDouble(),
      minS = (j['BASE_CFG']['min_s'] as num).toDouble();
}

class ModelConfig {
  final String name;
  final AnalyzeConfig analyze;
  final Map<String, HeadConfig> heads;

  ModelConfig.fromJson(Map<String, dynamic> j, {AnalyzeConfig? fallbackAnalyze})
    : name = j['name'] as String? ?? '',
      analyze = j['analyze_video'] != null
          ? AnalyzeConfig.fromJson(j['analyze_video'] as Map<String, dynamic>)
          : fallbackAnalyze!,
      heads = {
        for (final e in (j['heads'] as Map<String, dynamic>).entries)
          e.key: HeadConfig.fromJson(e.key, e.value as Map<String, dynamic>),
      };
}

/// app_spec.json → feedback.
class FeedbackSpec {
  final Map<String, Map<String, String>> messages;
  final String unsure, partial;
  final double minConfidence;

  FeedbackSpec.fromJson(Map<String, dynamic> spec)
    : messages = {
        for (final ex in const ['e1', 'e2', 'e3'])
          ex: (spec['feedback']['messages'][ex] as Map<String, dynamic>)
              .cast<String, String>(),
      },
      unsure = spec['feedback']['messages']['unsure'] as String,
      partial = spec['feedback']['messages']['partial'] as String,
      minConfidence = (spec['feedback']['min_confidence'] as num).toDouble();
}

const singleArm = {'e1': false, 'e2': true, 'e3': true};
const angleSignal = {'e1': 'elev_mean', 'e2': 'elev_a', 'e3': 'rot_deg'};
