package com.example.audio_sharing

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AudioCaptureManager(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "AudioCaptureManager"
        const val MEDIA_PROJECTION_REQUEST_CODE = 1002

        const val METHOD_CHANNEL_NAME = "com.example.audio_sharing/audio_control"
        const val AUDIO_STREAM_CHANNEL = "com.example.audio_sharing/audio_stream"
        const val DIAGNOSTICS_STREAM_CHANNEL = "com.example.audio_sharing/diagnostics_stream"
        const val DEVICE_STREAM_CHANNEL = "com.example.audio_sharing/device_stream"
        const val MIC_STREAM_CHANNEL = "com.example.audio_sharing/mic_stream"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingResult: MethodChannel.Result? = null
    private var sampleRate = 48000
    private var channels = 2

    private var audioEventSink: EventChannel.EventSink? = null
    private var diagnosticsEventSink: EventChannel.EventSink? = null
    private var deviceEventSink: EventChannel.EventSink? = null
    private var micEventSink: EventChannel.EventSink? = null
    private var micRecorder: AudioMicRecorder? = null

    private var bluetoothAudioHelper: BluetoothAudioHelper? = null

    fun setupChannels(flutterPluginBindingBinaryMessenger: io.flutter.plugin.common.BinaryMessenger) {
        val methodChannel = MethodChannel(flutterPluginBindingBinaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)

        // Event Channel for raw audio PCM streaming
        EventChannel(flutterPluginBindingBinaryMessenger, AUDIO_STREAM_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    audioEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    audioEventSink = null
                }
            }
        )

        // Event Channel for audio capture diagnostics (dB, peak, silence)
        EventChannel(flutterPluginBindingBinaryMessenger, DIAGNOSTICS_STREAM_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    diagnosticsEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    diagnosticsEventSink = null
                }
            }
        )

        // Event Channel for Bluetooth and Audio Device updates
        EventChannel(flutterPluginBindingBinaryMessenger, DEVICE_STREAM_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    deviceEventSink = events
                    // Send initial state immediately
                    val initialDevices = bluetoothAudioHelper?.getCurrentOutputDevices() ?: emptyList()
                    deviceEventSink?.success(initialDevices)
                }

                override fun onCancel(arguments: Any?) {
                    deviceEventSink = null
                }
            }
        )

        // Event Channel for microphone streaming
        EventChannel(flutterPluginBindingBinaryMessenger, MIC_STREAM_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    micEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    micEventSink = null
                }
            }
        )

        // Connect listeners from AudioCaptureService
        AudioCaptureService.audioChunkListener = { pcmChunk ->
            mainHandler.post {
                audioEventSink?.success(pcmChunk)
            }
        }

        AudioCaptureService.diagnosticsListener = { diag ->
            mainHandler.post {
                diagnosticsEventSink?.success(
                    mapOf(
                        "rmsDb" to diag.rmsDb,
                        "peakAmplitude" to diag.peakAmplitude,
                        "isSilence" to diag.isSilence,
                        "bytesPerSecond" to diag.bytesPerSecond,
                        "totalBytes" to diag.totalBytes
                    )
                )
            }
        }

        // Initialize Bluetooth Audio Helper
        bluetoothAudioHelper = BluetoothAudioHelper(activity) { deviceList ->
            mainHandler.post {
                deviceEventSink?.success(deviceList)
            }
        }
        bluetoothAudioHelper?.startListening()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startAudioCapture" -> {
                sampleRate = call.argument<Int>("sampleRate") ?: 48000
                channels = call.argument<Int>("channels") ?: 2
                requestMediaProjectionPermission(result)
            }

            "stopAudioCapture" -> {
                stopAudioCapture()
                result.success(true)
            }

            "isCapturing" -> {
                result.success(AudioCaptureService.isRunning.get())
            }

            "startAudioPlayer" -> {
                val sr = call.argument<Int>("sampleRate") ?: 48000
                val ch = call.argument<Int>("channels") ?: 2
                startAudioPlaybackService()
                val success = AudioPlayerService.instance.start(sr, ch)
                result.success(success)
            }

            "writeAudioChunk" -> {
                val bytes = call.argument<ByteArray>("data")
                if (bytes != null) {
                    val written = AudioPlayerService.instance.write(bytes)
                    result.success(written)
                } else {
                    result.error("INVALID_DATA", "Audio chunk data is null", null)
                }
            }

            "stopAudioPlayer" -> {
                stopAudioPlaybackService()
                AudioPlayerService.instance.stop()
                result.success(true)
            }

            "setPlayerVolume" -> {
                val vol = (call.argument<Double>("volume") ?: 1.0).toFloat()
                val success = AudioPlayerService.instance.setVolume(vol)
                result.success(success)
            }

            "getPlayerStats" -> {
                val stats = AudioPlayerService.instance.getStats()
                result.success(
                    mapOf(
                        "isPlaying" to stats.isPlaying,
                        "totalBytes" to stats.totalBytes,
                        "underrunCount" to stats.underrunCount,
                        "sampleRate" to stats.sampleRate
                    )
                )
            }

            "getAudioDevices" -> {
                val devices = bluetoothAudioHelper?.getCurrentOutputDevices() ?: emptyList()
                result.success(devices)
            }

            "startMicCapture" -> {
                micRecorder?.stop()
                micRecorder = AudioMicRecorder { pcmChunk ->
                    mainHandler.post {
                        micEventSink?.success(pcmChunk)
                    }
                }
                val success = micRecorder?.start() ?: false
                result.success(success)
            }

            "stopMicCapture" -> {
                micRecorder?.stop()
                micRecorder = null
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    private fun requestMediaProjectionPermission(result: MethodChannel.Result) {
        if (AudioCaptureService.isRunning.get()) {
            result.success(true)
            return
        }

        val projectionManager =
            activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val intent = projectionManager.createScreenCaptureIntent()

        pendingResult = result
        activity.startActivityForResult(intent, MEDIA_PROJECTION_REQUEST_CODE)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == MEDIA_PROJECTION_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val serviceIntent = Intent(activity, AudioCaptureService::class.java).apply {
                    action = AudioCaptureService.ACTION_START_CAPTURE
                    putExtra(AudioCaptureService.EXTRA_RESULT_CODE, resultCode)
                    putExtra(AudioCaptureService.EXTRA_DATA, data)
                    putExtra(AudioCaptureService.EXTRA_SAMPLE_RATE, sampleRate)
                    putExtra(AudioCaptureService.EXTRA_CHANNELS, channels)
                }

                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    activity.startForegroundService(serviceIntent)
                } else {
                    activity.startService(serviceIntent)
                }

                pendingResult?.success(true)
            } else {
                Log.w(TAG, "MediaProjection permission denied by user")
                pendingResult?.error("PERMISSION_DENIED", "MediaProjection permission was denied", null)
            }
            pendingResult = null
            return true
        }
        return false
    }

    private fun stopAudioCapture() {
        val serviceIntent = Intent(activity, AudioCaptureService::class.java).apply {
            action = AudioCaptureService.ACTION_STOP_CAPTURE
        }
        activity.startService(serviceIntent)
    }

    private fun startAudioPlaybackService() {
        val serviceIntent = Intent(activity, AudioPlaybackService::class.java).apply {
            action = AudioPlaybackService.ACTION_START_PLAYBACK
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            activity.startForegroundService(serviceIntent)
        } else {
            activity.startService(serviceIntent)
        }
    }

    private fun stopAudioPlaybackService() {
        val serviceIntent = Intent(activity, AudioPlaybackService::class.java).apply {
            action = AudioPlaybackService.ACTION_STOP_PLAYBACK
        }
        activity.startService(serviceIntent)
    }

    fun dispose() {
        stopAudioCapture()
        stopAudioPlaybackService()
        micRecorder?.stop()
        micRecorder = null
        AudioPlayerService.instance.stop()
        bluetoothAudioHelper?.stopListening()
        AudioCaptureService.audioChunkListener = null
        AudioCaptureService.diagnosticsListener = null
    }
}
