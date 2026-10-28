package com.kinex.kinex_pose

import android.app.Activity
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Size
import android.view.View
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.framework.image.ByteBufferExtractor
import com.google.mediapipe.framework.image.MPImage
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.nio.ByteOrder
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Live pose capture: CameraX frames, rotated upright and NOT mirrored (the selfie preview is mirrored, the frames
 * given to MediaPipe are not, so the person's left stays left), MediaPipe Tasks PoseLandmarker (full model,
 * LIVE_STREAM, 1 pose, confidences 0.5) -> per frame: timestamp (ms, camera sensor clock), frame size, the 33
 * normalized landmarks (x, y, z, visibility, presence), the 33 world landmarks and, when asked, the person mask
 * thresholded at 0.5 and packed 1 bit per pixel.
 */
class KinexPosePlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var context: Context
    private lateinit var methods: MethodChannel
    private lateinit var frames: EventChannel
    private var activity: Activity? = null
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())

    private var previewView: PreviewView? = null
    private var preview: Preview? = null
    private var provider: ProcessCameraProvider? = null
    @Volatile private var analysisExecutor: ExecutorService? = null
    private val lock = Any()
    private var landmarker: PoseLandmarker? = null
    @Volatile private var withMask = false
    @Volatile private var running = false
    private var lastTs = -1L
    private val submitted = ConcurrentHashMap<Long, Long>()  // timestamp -> elapsedRealtimeNanos at submit
    private val prepMs = ConcurrentHashMap<Long, Double>()   // timestamp -> image conversion time

    // Latest-frame policy: while MediaPipe is still working on a frame, new camera frames are closed at once,
    // before any conversion, so no CPU is spent on frames MediaPipe would drop and no frame waits in a queue.
    private val inFlight = java.util.concurrent.atomic.AtomicBoolean(false)
    @Volatile private var skipWhileBusy = true
    private val droppedBusy = java.util.concurrent.atomic.AtomicInteger(0)
    @Volatile private var delegateUsed = "cpu"

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, "kinex_pose")
        methods.setMethodCallHandler(this)
        frames = EventChannel(binding.binaryMessenger, "kinex_pose/frames")
        frames.setStreamHandler(this)
        binding.platformViewRegistry.registerViewFactory("kinex_pose/preview", PreviewFactory())
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stop()
        methods.setMethodCallHandler(null)
        frames.setStreamHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { stop(); activity = null }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val front = call.argument<Boolean>("front") ?: true
                val mask = call.argument<Boolean>("mask") ?: false
                val gpu = call.argument<Boolean>("gpu") ?: false
                val maxSide = call.argument<Int>("maxSide") ?: 1280
                skipWhileBusy = call.argument<Boolean>("skipWhileBusy") ?: true
                try {
                    start(front, mask, gpu, maxSide, result)
                } catch (e: Exception) {
                    result.error("start_failed", e.message, null)
                }
            }
            "stop" -> { stop(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    // ------------------------------------------------------------------------------------------------ camera
    private fun options(mask: Boolean, delegate: Delegate) =
        PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(BaseOptions.builder().setModelAssetPath("pose_landmarker_full.task").setDelegate(delegate).build())
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setNumPoses(1)
            .setMinPoseDetectionConfidence(0.5f)
            .setMinPosePresenceConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .setOutputSegmentationMasks(mask)
            .setResultListener(this::onResult)
            .setErrorListener { e ->
                inFlight.set(false)
                main.post { sink?.error("mediapipe", e.message, null) }
            }
            .build()

    private fun start(front: Boolean, mask: Boolean, gpu: Boolean, maxSide: Int, result: MethodChannel.Result) {
        val owner = activity as? LifecycleOwner ?: throw IllegalStateException("no activity")
        stop()
        withMask = mask
        val executor = Executors.newSingleThreadExecutor()
        analysisExecutor = executor
        // Loading the model takes a while (hundreds of ms on a slow phone): on the analysis thread, not the UI thread
        executor.execute {
            // CPU by default (the training landmarks came from the CPU model); GPU only when asked, CPU if it fails
            var lm: PoseLandmarker? = null
            var used = "cpu"
            try {
                if (gpu) {
                    try {
                        lm = PoseLandmarker.createFromOptions(context, options(mask, Delegate.GPU))
                        used = "gpu"
                    } catch (e: Exception) {
                        lm = null
                    }
                }
                if (lm == null) lm = PoseLandmarker.createFromOptions(context, options(mask, Delegate.CPU))
            } catch (e: Exception) {
                main.post { result.error("start_failed", e.message, null) }
                return@execute
            }
            synchronized(lock) {
                if (analysisExecutor !== executor) {     // stopped while the model was loading
                    lm?.close()
                    main.post { result.error("start_failed", "stopped", null) }
                    return@execute
                }
                delegateUsed = used
                landmarker = lm
                lastTs = -1L
                inFlight.set(false)
                droppedBusy.set(0)
                running = true
            }
            main.post { bindCamera(owner, front, maxSide, executor, result) }
        }
    }

    private fun bindCamera(owner: LifecycleOwner, front: Boolean, maxSide: Int, executor: ExecutorService,
                           result: MethodChannel.Result) {
        if (analysisExecutor !== executor) {             // stopped (or restarted) while the model was loading
            result.error("start_failed", "stopped", null)
            return
        }
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            try {
                val p = future.get()
                provider = p
                // the preview at 1280x720 (what the patient sees)
                val previewSelector = ResolutionSelector.Builder()
                    .setAspectRatioStrategy(AspectRatioStrategy.RATIO_16_9_FALLBACK_AUTO_STRATEGY)
                    .setResolutionStrategy(ResolutionStrategy(Size(1280, 720),
                        ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER))
                    .build()
                // the frames MediaPipe analyses: 16:9 with the longest side maxSide. MediaPipe shrinks the whole frame
                // to 224 px for the person detector and the person's crop to 256 px for the landmarks, so 640 px gives
                // the landmark model practically the same pixels as 1280 px, with 4x less to convert, rotate and copy
                // per frame. The person mask (e2) is at the frame size: the app asks 1280 when it needs the mask.
                val side = maxSide.coerceIn(320, 1920)
                val analysisSelector = ResolutionSelector.Builder()
                    .setAspectRatioStrategy(AspectRatioStrategy.RATIO_16_9_FALLBACK_AUTO_STRATEGY)
                    .setResolutionStrategy(ResolutionStrategy(Size(side, side * 9 / 16),
                        ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER))
                    .build()
                val pv = Preview.Builder().setResolutionSelector(previewSelector).build()
                previewView?.let { pv.setSurfaceProvider(it.surfaceProvider) }
                preview = pv
                val analysis = ImageAnalysis.Builder()
                    .setResolutionSelector(analysisSelector)
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .build()
                analysis.setAnalyzer(executor) { proxy -> analyze(proxy) }
                val cam = if (front) CameraSelector.DEFAULT_FRONT_CAMERA else CameraSelector.DEFAULT_BACK_CAMERA
                p.unbindAll()
                p.bindToLifecycle(owner, cam, pv, analysis)
                result.success(mapOf("previewMirrored" to front, "delegate" to delegateUsed,
                    "analysisWidth" to (analysis.resolutionInfo?.resolution?.width ?: 0),
                    "analysisHeight" to (analysis.resolutionInfo?.resolution?.height ?: 0)))
            } catch (e: Exception) {
                result.error("camera_failed", e.message, null)
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private val rotation = Matrix()

    private fun stop() {
        provider?.unbindAll()
        provider = null
        preview = null
        synchronized(lock) {
            running = false
            landmarker?.close()
            landmarker = null
        }
        analysisExecutor?.shutdown()
        analysisExecutor = null
        submitted.clear()
        prepMs.clear()
    }

    private fun analyze(proxy: ImageProxy) {
        if (skipWhileBusy && inFlight.get()) {      // MediaPipe busy: drop this frame before converting it
            droppedBusy.incrementAndGet()
            proxy.close()
            return
        }
        val t0 = SystemClock.elapsedRealtimeNanos()
        val rot = proxy.imageInfo.rotationDegrees
        var ts = proxy.imageInfo.timestamp / 1_000_000L
        val bmp: Bitmap
        try {
            bmp = proxy.toBitmap()
        } finally {
            proxy.close()
        }
        // upright, not mirrored (the sensor image of the front camera is not mirrored; only the preview is)
        val upright = if (rot != 0) {
            rotation.setRotate(rot.toFloat())
            // filter = false: a quarter-turn moves pixels without resampling them
            Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, rotation, rot % 90 != 0)
        } else bmp
        if (upright !== bmp) bmp.recycle()
        synchronized(lock) {
            val lm = landmarker ?: return
            if (!running) return
            if (ts <= lastTs) ts = lastTs + 1      // LIVE_STREAM needs strictly increasing timestamps
            lastTs = ts
            val now = SystemClock.elapsedRealtimeNanos()
            prepMs[ts] = (now - t0) / 1e6
            submitted[ts] = now
            inFlight.set(true)
            lm.detectAsync(BitmapImageBuilder(upright).build(), ts)
        }
    }

    private fun onResult(result: PoseLandmarkerResult, input: MPImage) {
        val ts = result.timestampMs()
        inFlight.set(false)   // the next camera frame can go in while this result is being packed / sent
        val start = submitted.remove(ts)
        val inferMs = if (start != null) (SystemClock.elapsedRealtimeNanos() - start) / 1e6 else Double.NaN
        val prep = prepMs.remove(ts) ?: Double.NaN
        var lm: FloatArray? = null
        var world: FloatArray? = null
        var maskBits: ByteArray? = null
        var mw = 0
        var mh = 0
        var maskMs = 0.0
        val poses = result.landmarks()
        if (poses.isNotEmpty()) {
            val p = poses[0]
            lm = FloatArray(33 * 5) { Float.NaN }
            for (i in 0 until minOf(33, p.size)) {
                val l = p[i]
                lm[i * 5] = l.x()
                lm[i * 5 + 1] = l.y()
                lm[i * 5 + 2] = l.z()
                lm[i * 5 + 3] = l.visibility().orElse(Float.NaN)
                lm[i * 5 + 4] = l.presence().orElse(Float.NaN)
            }
            val wls = result.worldLandmarks()
            if (wls.isNotEmpty()) {
                val w = wls[0]
                world = FloatArray(33 * 3) { Float.NaN }
                for (i in 0 until minOf(33, w.size)) {
                    world[i * 3] = w[i].x()
                    world[i * 3 + 1] = w[i].y()
                    world[i * 3 + 2] = w[i].z()
                }
            }
            if (withMask) {
                val masks = result.segmentationMasks()
                if (masks.isPresent && masks.get().isNotEmpty()) {
                    val m = masks.get()[0]
                    mw = m.width
                    mh = m.height
                    val p0 = SystemClock.elapsedRealtimeNanos()
                    maskBits = packMask(m)
                    maskMs = (SystemClock.elapsedRealtimeNanos() - p0) / 1e6
                }
            }
        }
        val frame = hashMapOf<String, Any?>(
            "t" to ts.toDouble(), "w" to input.width, "h" to input.height, "lm" to lm, "world" to world,
            "mask" to maskBits, "mw" to mw, "mh" to mh, "inferMs" to inferMs, "prepMs" to prep,
            "ageMs" to (SystemClock.elapsedRealtime() - ts).toDouble(),
            "maskMs" to maskMs, "dropped" to droppedBusy.getAndSet(0), "delegate" to delegateUsed,
        )
        main.post { sink?.success(frame) }
    }

    /** MediaPipe float mask -> bits (value > 0.5 = person), row-major, bit 7 of byte 0 = pixel (0, 0). */
    private fun packMask(m: MPImage): ByteArray {
        val fb = ByteBufferExtractor.extract(m).order(ByteOrder.nativeOrder()).asFloatBuffer()
        val n = m.width * m.height
        val values = FloatArray(n)
        fb.get(values)                    // one bulk copy instead of n buffer reads
        val out = ByteArray((n + 7) shr 3)
        for (i in 0 until n) {
            if (values[i] > 0.5f) {
                val k = i shr 3
                out[k] = (out[k].toInt() or (0x80 ushr (i and 7))).toByte()
            }
        }
        return out
    }

    // ------------------------------------------------------------------------------------------------ preview
    private inner class PreviewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
        override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
            val view = PreviewView(context).apply {
                implementationMode = PreviewView.ImplementationMode.COMPATIBLE
                scaleType = PreviewView.ScaleType.FIT_CENTER
            }
            previewView = view
            preview?.setSurfaceProvider(view.surfaceProvider)
            return object : PlatformView {
                override fun getView(): View = view
                override fun dispose() {
                    if (previewView === view) previewView = null
                }
            }
        }
    }
}
