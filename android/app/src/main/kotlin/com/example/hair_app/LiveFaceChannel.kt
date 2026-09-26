package com.example.hair_app

import android.os.Handler
import android.os.Looper
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Bundled on-device model. No image is uploaded by this channel. */
class LiveFaceChannel(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "hair_app/live_face")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val detector = FaceDetection.getClient(FaceDetectorOptions.Builder()
        .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
        .setMinFaceSize(0.1f).build())

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "detect") {
                result.notImplemented()
            } else {
                worker.execute {
                    try {
                        val width = call.argument<Int>("width")!!
                        val height = call.argument<Int>("height")!!
                        val rotation = call.argument<Int>("rotation")!!
                        val mirror = call.argument<Boolean>("mirror") == true
                        val planes = call.argument<List<Map<String, Any>>>("planes")!!
                        require(width > 0 && height > 0 && width % 2 == 0 && height % 2 == 0)
                        require(planes.size == 3)
                        // Respect YUV_420_888 row padding and chroma pixel strides.
                        val nv21 = ByteArray(width * height * 3 / 2)
                        fun pixel(p: Int, x: Int, y: Int): Byte {
                            val plane = planes[p]
                            return (plane["bytes"] as ByteArray)[y * (plane["rowStride"] as Int) +
                                x * (plane["pixelStride"] as Int)]
                        }
                        for (y in 0 until height) for (x in 0 until width) {
                            nv21[y * width + x] = pixel(0, x, y)
                        }
                        var index = width * height
                        for (y in 0 until height / 2) for (x in 0 until width / 2) {
                            nv21[index++] = pixel(2, x, y)
                            nv21[index++] = pixel(1, x, y)
                        }
                        val uprightWidth = if (rotation % 180 == 0) width else height
                        val uprightHeight = if (rotation % 180 == 0) height else width
                        val image = InputImage.fromByteArray(nv21, width, height, rotation, InputImage.IMAGE_FORMAT_NV21)
                        detector.process(image).addOnSuccessListener { faces ->
                            val output = faces.map { face ->
                                val box = face.boundingBox
                                var luma = 0.0
                                for (sy in 0..15) for (sx in 0..15) {
                                    val x = (box.left + box.width() * (0.2 + sx / 15.0 * 0.6)).toInt()
                                    val y = (box.top + box.height() * (0.2 + sy / 15.0 * 0.6)).toInt()
                                    val rawX = when (rotation) { 90 -> y; 180 -> width - 1 - x; 270 -> width - 1 - y; else -> x }
                                    val rawY = when (rotation) { 90 -> height - 1 - x; 180 -> height - 1 - y; 270 -> x; else -> y }
                                    luma += (nv21[rawY.coerceIn(0, height - 1) * width + rawX.coerceIn(0, width - 1)].toInt() and 255)
                                }
                                mapOf("x" to (if (mirror) uprightWidth - box.right else box.left).toDouble() / uprightWidth,
                                    "y" to box.top.toDouble() / uprightHeight,
                                    "width" to box.width().toDouble() / uprightWidth,
                                    "height" to box.height().toDouble() / uprightHeight,
                                    "yaw" to face.headEulerAngleY.toDouble(), "pitch" to face.headEulerAngleX.toDouble(),
                                    "roll" to face.headEulerAngleZ.toDouble(), "brightness" to luma / 256 / 255)
                            }
                            result.success(mapOf("width" to uprightWidth, "height" to uprightHeight, "faces" to output))
                        }.addOnFailureListener { result.error("detection", "Face guidance unavailable", null) }
                    } catch (_: Exception) {
                        main.post { result.error("frame", "Invalid camera frame", null) }
                    }
                }
            }
        }
    }

    fun close() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
        detector.close()
    }
}
