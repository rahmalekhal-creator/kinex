/// Minimal ONNX Runtime binding over `dart:ffi` (the official C API): load a model from bytes and run it
/// on float32 tensors. The same code runs in `flutter test` on the PC (onnxruntime.dll / .so / .dylib) and
/// in the app (libonnxruntime.so from com.microsoft.onnxruntime:onnxruntime-android).
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

const _apiVersion = 17; // oldest API level that has everything used here

typedef _P = Pointer<Void>;
typedef _PP = Pointer<Pointer<Void>>;

typedef _GetApiBaseC = _PP Function();
typedef _GetApiC = _PP Function(Uint32);
typedef _GetApiD = _PP Function(int);
typedef _ErrMsgC = Pointer<Utf8> Function(_P);
typedef _ReleaseC = Void Function(_P);
typedef _ReleaseD = void Function(_P);
typedef _CreateEnvC = _P Function(Int32, Pointer<Utf8>, _PP);
typedef _CreateEnvD = _P Function(int, Pointer<Utf8>, _PP);
typedef _OutC = _P Function(_PP);
typedef _SetIntC = _P Function(_P, Int32);
typedef _SetIntD = _P Function(_P, int);
typedef _SessionFromArrayC = _P Function(_P, _P, Size, _P, _PP);
typedef _SessionFromArrayD = _P Function(_P, _P, int, _P, _PP);
typedef _CountC = _P Function(_P, Pointer<Size>);
typedef _NameC = _P Function(_P, Size, _P, Pointer<Pointer<Utf8>>);
typedef _NameD = _P Function(_P, int, _P, Pointer<Pointer<Utf8>>);
typedef _FreeC = _P Function(_P, _P);
typedef _CpuMemC = _P Function(Int32, Int32, _PP);
typedef _CpuMemD = _P Function(int, int, _PP);
typedef _TensorC = _P Function(_P, _P, Size, Pointer<Int64>, Size, Int32, _PP);
typedef _TensorD = _P Function(_P, _P, int, Pointer<Int64>, int, int, _PP);
typedef _RunC =
    _P Function(
      _P,
      _P,
      Pointer<Pointer<Utf8>>,
      _PP,
      Size,
      Pointer<Pointer<Utf8>>,
      Size,
      _PP,
    );
typedef _RunD =
    _P Function(
      _P,
      _P,
      Pointer<Pointer<Utf8>>,
      _PP,
      int,
      Pointer<Pointer<Utf8>>,
      int,
      _PP,
    );
typedef _InfoC = _P Function(_P, _PP);
typedef _DimsC = _P Function(_P, Pointer<Int64>, Size);
typedef _DimsD = _P Function(_P, Pointer<Int64>, int);

class OrtException implements Exception {
  final String message;
  OrtException(this.message);
  @override
  String toString() => 'OrtException: $message';
}

/// The loaded runtime (one per process). Function positions in `struct OrtApi` are from onnxruntime_c_api.h
/// (the table is append-only, so they hold for every later version).
class OrtRuntime {
  final _PP _api;
  late final _P _env;
  late final _P _cpuMem;

  late final getErrorMessage = _f<_ErrMsgC>(
    2,
  ).asFunction<Pointer<Utf8> Function(_P)>();
  late final createEnv = _f<_CreateEnvC>(3).asFunction<_CreateEnvD>();
  late final createSessionFromArray = _f<_SessionFromArrayC>(
    8,
  ).asFunction<_SessionFromArrayD>();
  late final run = _f<_RunC>(9).asFunction<_RunD>();
  late final createSessionOptions = _f<_OutC>(
    10,
  ).asFunction<_P Function(_PP)>();
  late final setGraphOptimizationLevel = _f<_SetIntC>(
    23,
  ).asFunction<_SetIntD>();
  late final setIntraOpNumThreads = _f<_SetIntC>(24).asFunction<_SetIntD>();
  late final sessionGetInputCount = _f<_CountC>(
    30,
  ).asFunction<_P Function(_P, Pointer<Size>)>();
  late final sessionGetOutputCount = _f<_CountC>(
    31,
  ).asFunction<_P Function(_P, Pointer<Size>)>();
  late final sessionGetInputName = _f<_NameC>(36).asFunction<_NameD>();
  late final sessionGetOutputName = _f<_NameC>(37).asFunction<_NameD>();
  late final createTensorWithData = _f<_TensorC>(49).asFunction<_TensorD>();
  late final getTensorMutableData = _f<_InfoC>(
    51,
  ).asFunction<_P Function(_P, _PP)>();
  late final getDimensionsCount = _f<_CountC>(
    61,
  ).asFunction<_P Function(_P, Pointer<Size>)>();
  late final getDimensions = _f<_DimsC>(62).asFunction<_DimsD>();
  late final getTensorTypeAndShape = _f<_InfoC>(
    65,
  ).asFunction<_P Function(_P, _PP)>();
  late final createCpuMemoryInfo = _f<_CpuMemC>(69).asFunction<_CpuMemD>();
  late final allocatorFree = _f<_FreeC>(76).asFunction<_P Function(_P, _P)>();
  late final getAllocatorWithDefaultOptions = _f<_OutC>(
    78,
  ).asFunction<_P Function(_PP)>();
  late final releaseStatus = _f<_ReleaseC>(93).asFunction<_ReleaseD>();
  late final releaseSession = _f<_ReleaseC>(95).asFunction<_ReleaseD>();
  late final releaseValue = _f<_ReleaseC>(96).asFunction<_ReleaseD>();
  late final releaseTypeAndShape = _f<_ReleaseC>(99).asFunction<_ReleaseD>();
  late final releaseSessionOptions = _f<_ReleaseC>(100).asFunction<_ReleaseD>();

  Pointer<NativeFunction<T>> _f<T extends Function>(int index) =>
      _api[index].cast<NativeFunction<T>>();

  static OrtRuntime? _instance;

  /// [libraryPath]: explicit path of the shared library (tests); default = the platform's library name.
  static OrtRuntime instance({String? libraryPath}) =>
      _instance ??= OrtRuntime._(_open(libraryPath));

  static DynamicLibrary _open(String? path) {
    if (path != null) return DynamicLibrary.open(path);
    final env = Platform.environment['ORT_LIB'];
    if (env != null && env.isNotEmpty) {
      return DynamicLibrary.open(env); // tests on the PC
    }
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('libonnxruntime.so');
    }
    if (Platform.isWindows) return DynamicLibrary.open('onnxruntime.dll');
    if (Platform.isMacOS) return DynamicLibrary.open('libonnxruntime.dylib');
    return DynamicLibrary.process(); // iOS: statically linked pod
  }

  OrtRuntime._(DynamicLibrary lib) : _api = _getApi(lib) {
    using((arena) {
      final out = arena<_P>();
      _check(
        createEnv(3, 'kinex'.toNativeUtf8(allocator: arena), out),
      ); // 3 = warning level
      _env = out.value;
      _check(createCpuMemoryInfo(1, 0, out)); // arena allocator, default memory
      _cpuMem = out.value;
    });
  }

  static _PP _getApi(DynamicLibrary lib) {
    final base = lib.lookupFunction<_GetApiBaseC, _GetApiBaseC>(
      'OrtGetApiBase',
    )();
    final getApi = base[0]
        .cast<NativeFunction<_GetApiC>>()
        .asFunction<_GetApiD>();
    final api = getApi(_apiVersion);
    if (api == nullptr) {
      throw OrtException(
        'ONNX Runtime does not support API version $_apiVersion',
      );
    }
    return api;
  }

  void _check(_P status) {
    if (status == nullptr) return;
    final msg = getErrorMessage(status).toDartString();
    releaseStatus(status);
    throw OrtException(msg);
  }
}

/// A float32 tensor: data + shape.
class OrtTensor {
  final Float32List data;
  final List<int> shape;
  const OrtTensor(this.data, this.shape);
}

/// One model loaded from bytes.
class OrtSession {
  final OrtRuntime _rt;
  final _P _session;
  final List<String> inputNames;
  final List<String> outputNames;

  OrtSession._(this._rt, this._session, this.inputNames, this.outputNames);

  factory OrtSession.fromBytes(
    Uint8List model, {
    int intraOpThreads = 1,
    String? libraryPath,
  }) {
    final rt = OrtRuntime.instance(libraryPath: libraryPath);
    return using((arena) {
      final opts = arena<_P>(), out = arena<_P>();
      final buf = arena<Uint8>(model.length);
      buf.asTypedList(model.length).setAll(0, model);
      rt._check(rt.createSessionOptions(opts));
      try {
        rt._check(rt.setIntraOpNumThreads(opts.value, intraOpThreads));
        rt._check(
          rt.setGraphOptimizationLevel(opts.value, 99),
        ); // ORT_ENABLE_ALL
        rt._check(
          rt.createSessionFromArray(
            rt._env,
            buf.cast(),
            model.length,
            opts.value,
            out,
          ),
        );
      } finally {
        rt.releaseSessionOptions(opts.value);
      }
      final s = out.value;
      return OrtSession._(
        rt,
        s,
        _names(rt, s, rt.sessionGetInputCount, rt.sessionGetInputName),
        _names(rt, s, rt.sessionGetOutputCount, rt.sessionGetOutputName),
      );
    });
  }

  static List<String> _names(
    OrtRuntime rt,
    _P session,
    _P Function(_P, Pointer<Size>) count,
    _P Function(_P, int, _P, Pointer<Pointer<Utf8>>) name,
  ) {
    return using((arena) {
      final cnt = arena<Size>(),
          alloc = arena<_P>(),
          nm = arena<Pointer<Utf8>>();
      rt._check(count(session, cnt));
      rt._check(rt.getAllocatorWithDefaultOptions(alloc));
      final out = <String>[];
      for (var i = 0; i < cnt.value; i++) {
        rt._check(name(session, i, alloc.value, nm));
        out.add(nm.value.toDartString());
        rt._check(rt.allocatorFree(alloc.value, nm.value.cast()));
      }
      return out;
    });
  }

  /// Runs the model; inputs by name. Returns every output by name (float32).
  Map<String, OrtTensor> run(Map<String, OrtTensor> inputs) {
    final rt = _rt;
    final names = inputs.keys.toList();
    return using((arena) {
      final inNames = arena<Pointer<Utf8>>(names.length);
      final inVals = arena<_P>(names.length);
      final outNames = arena<Pointer<Utf8>>(outputNames.length);
      final outVals = arena<_P>(outputNames.length);
      try {
        for (var i = 0; i < names.length; i++) {
          final t = inputs[names[i]]!;
          inNames[i] = names[i].toNativeUtf8(allocator: arena);
          final data = arena<Float>(t.data.length);
          data.asTypedList(t.data.length).setAll(0, t.data);
          final shape = arena<Int64>(t.shape.length);
          for (var k = 0; k < t.shape.length; k++) {
            shape[k] = t.shape[k];
          }
          final val = arena<_P>();
          rt._check(
            rt.createTensorWithData(
              rt._cpuMem,
              data.cast(),
              t.data.length * 4,
              shape,
              t.shape.length,
              1,
              val,
            ),
          );
          inVals[i] = val.value; // 1 = ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT
        }
        for (var i = 0; i < outputNames.length; i++) {
          outNames[i] = outputNames[i].toNativeUtf8(allocator: arena);
          outVals[i] = nullptr;
        }
        rt._check(
          rt.run(
            _session,
            nullptr,
            inNames,
            inVals,
            names.length,
            outNames,
            outputNames.length,
            outVals,
          ),
        );
        final result = <String, OrtTensor>{};
        for (var i = 0; i < outputNames.length; i++) {
          result[outputNames[i]] = _readTensor(rt, outVals[i], arena);
          rt.releaseValue(outVals[i]);
        }
        return result;
      } finally {
        for (var i = 0; i < names.length; i++) {
          if (inVals[i] != nullptr) rt.releaseValue(inVals[i]);
        }
      }
    });
  }

  static OrtTensor _readTensor(OrtRuntime rt, _P value, Arena arena) {
    final info = arena<_P>(), cnt = arena<Size>(), data = arena<_P>();
    rt._check(rt.getTensorTypeAndShape(value, info));
    try {
      rt._check(rt.getDimensionsCount(info.value, cnt));
      final dims = arena<Int64>(cnt.value);
      rt._check(rt.getDimensions(info.value, dims, cnt.value));
      final shape = [for (var k = 0; k < cnt.value; k++) dims[k]];
      rt._check(rt.getTensorMutableData(value, data));
      final total = shape.fold<int>(1, (a, b) => a * b);
      return OrtTensor(
        Float32List.fromList(data.value.cast<Float>().asTypedList(total)),
        shape,
      );
    } finally {
      rt.releaseTypeAndShape(info.value);
    }
  }

  void close() => _rt.releaseSession(_session);
}
