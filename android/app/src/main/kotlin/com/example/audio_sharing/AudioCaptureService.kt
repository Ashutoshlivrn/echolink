package com.example.audio_sharing

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.sqrt

class AudioCaptureService : Service() {

    companion object {
        private const val TAG = "AudioCaptureService"
        const val CHANNEL_ID = "audio_capture_channel"
        const val NOTIFICATION_ID = 1001

        const val ACTION_START_CAPTURE = "com.example.audio_sharing.START_CAPTURE"
        const val ACTION_STOP_CAPTURE = "com.example.audio_sharing.STOP_CAPTURE"

        const val EXTRA_RESULT_CODE = "extra_result_code"
        const val EXTRA_DATA = "extra_data"
        const val EXTRA_SAMPLE_RATE = "extra_sample_rate"
        const val EXTRA_CHANNELS = "extra_channels"

        val isRunning = AtomicBoolean(false)
        var audioChunkListener: ((ByteArray) -> Unit)? = null
        var diagnosticsListener: ((AudioDiagnostics) -> Unit)? = null
    }

    data class AudioDiagnostics(
        val rmsDb: Double,
        val peakAmplitude: Int,
        val isSilence: Boolean,
        val bytesPerSecond: Int,
        val totalBytes: Long
    )

    private var mediaProjection: MediaProjection? = null
    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null
    private val isCapturing = AtomicBoolean(false)

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_CAPTURE -> {
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
                val data = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra<Intent>(EXTRA_DATA)
                }
                val sampleRate = intent.getIntExtra(EXTRA_SAMPLE_RATE, 48000)
                val channels = intent.getIntExtra(EXTRA_CHANNELS, 2)

                if (resultCode != 0 && data != null) {
                    startForegroundServiceWithNotification()
                    startCapture(resultCode, data, sampleRate, channels)
                } else {
                    Log.e(TAG, "Cannot start capture: invalid resultCode or data")
                    stopSelf()
                }
            }
            ACTION_STOP_CAPTURE -> {
                stopCapture()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Audio Sharing Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Captures and streams system audio to connected friend"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundServiceWithNotification() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Audio Sharing is Active")
            .setContentText("Capturing and streaming playback audio in real time")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                )
            } else {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                )
            }
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        isRunning.set(true)
    }

    private fun startCapture(resultCode: Int, data: Intent, sampleRate: Int, channels: Int) {
        if (isCapturing.get()) {
            Log.w(TAG, "Capture already running")
            return
        }

        try {
            val projectionManager =
                getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = projectionManager.getMediaProjection(resultCode, data)

            if (mediaProjection == null) {
                Log.e(TAG, "Failed to obtain MediaProjection token")
                stopSelf()
                return
            }

            // Register callback as required by Android 14+
            mediaProjection?.registerCallback(object : MediaProjection.Callback() {
                override fun onStop() {
                    super.onStop()
                    Log.i(TAG, "MediaProjection stopped by system")
                    stopCapture()
                    stopSelf()
                }
            }, null)

            // Configure AudioPlaybackCaptureConfiguration (API 29+)
            val configBuilder = AudioPlaybackCaptureConfiguration.Builder(mediaProjection!!)
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)

            val captureConfig = configBuilder.build()

            val channelConfig = if (channels == 1) {
                AudioFormat.CHANNEL_IN_MONO
            } else {
                AudioFormat.CHANNEL_IN_STEREO
            }
            val audioFormat = AudioFormat.ENCODING_PCM_16BIT

            val minBufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
            // 20ms chunk at 48kHz 16-bit stereo = 48000 * 2 * 2 * 0.02 = 3840 bytes (960 frames)
            val chunkBytes = (sampleRate * channels * 2 * 0.02).toInt()
            val bufferSize = max(minBufferSize, chunkBytes * 4)

            audioRecord = AudioRecord.Builder()
                .setAudioPlaybackCaptureConfig(captureConfig)
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(audioFormat)
                        .setSampleRate(sampleRate)
                        .setChannelMask(channelConfig)
                        .build()
                )
                .setBufferSizeInBytes(bufferSize)
                .build()

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord failed to initialize")
                stopCapture()
                stopSelf()
                return
            }

            audioRecord?.startRecording()
            isCapturing.set(true)

            captureThread = Thread({
                readCaptureLoop(chunkBytes)
            }, "AudioCaptureWorker")
            captureThread?.start()

            Log.i(TAG, "Audio playback capture successfully started ($sampleRate Hz, $channels ch)")

        } catch (e: Exception) {
            Log.e(TAG, "Exception starting audio capture: ${e.message}", e)
            stopCapture()
            stopSelf()
        }
    }

    private fun readCaptureLoop(chunkBytes: Int) {
        val buffer = ByteArray(chunkBytes)
        var totalBytesCaptured = 0L
        var secondBytesCaptured = 0
        var lastDiagnosticsTime = System.currentTimeMillis()

        while (isCapturing.get() && audioRecord != null) {
            val bytesRead = audioRecord!!.read(buffer, 0, buffer.size)

            if (bytesRead > 0) {
                totalBytesCaptured += bytesRead
                secondBytesCaptured += bytesRead

                // Copy exact slice
                val chunk = if (bytesRead == buffer.size) {
                    buffer.clone()
                } else {
                    buffer.copyOf(bytesRead)
                }

                // Dispatch to listener (WebRTC / Flutter EventSink)
                audioChunkListener?.invoke(chunk)

                // Calculate amplitude and silence detection
                val (rmsDb, peak, isSilence) = analyzeAudioChunk(chunk)

                val now = System.currentTimeMillis()
                if (now - lastDiagnosticsTime >= 250) { // update 4 times/sec
                    val elapsedSec = (now - lastDiagnosticsTime) / 1000.0
                    val bytesRate = (secondBytesCaptured / elapsedSec).toInt()

                    diagnosticsListener?.invoke(
                        AudioDiagnostics(
                            rmsDb = rmsDb,
                            peakAmplitude = peak,
                            isSilence = isSilence,
                            bytesPerSecond = bytesRate,
                            totalBytes = totalBytesCaptured
                        )
                    )
                    secondBytesCaptured = 0
                    lastDiagnosticsTime = now
                }
            } else if (bytesRead < 0) {
                Log.w(TAG, "AudioRecord.read returned error: $bytesRead")
                Thread.sleep(10)
            }
        }
        Log.i(TAG, "Capture loop finished. Total bytes captured: $totalBytesCaptured")
    }

    private fun analyzeAudioChunk(pcmData: ByteArray): Triple<Double, Int, Boolean> {
        val numSamples = pcmData.size / 2
        if (numSamples == 0) return Triple(-100.0, 0, true)

        var sumSquare = 0.0
        var peak = 0
        var zeroCount = 0

        for (i in 0 until numSamples) {
            val low = pcmData[i * 2].toInt() and 0xFF
            val high = pcmData[i * 2 + 1].toInt()
            val sample = (high shl 8) or low

            val absSample = kotlin.math.abs(sample)
            if (absSample > peak) {
                peak = absSample
            }
            if (absSample == 0) {
                zeroCount++
            }
            sumSquare += (sample * sample).toDouble()
        }

        val rms = sqrt(sumSquare / numSamples)
        // Convert to dBFS (0 dBFS is peak 32767)
        val rmsDb = if (rms > 0.0) {
            max(-90.0, 20.0 * log10(rms / 32767.0))
        } else {
            -90.0
        }

        // Check if silence (e.g. if >98% zeros or RMS < -60 dBFS)
        val isSilence = peak < 50 || (zeroCount.toDouble() / numSamples) > 0.95

        return Triple(rmsDb, peak, isSilence)
    }

    private fun stopCapture() {
        isCapturing.set(false)
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping AudioRecord: ${e.message}")
        }
        audioRecord = null

        try {
            mediaProjection?.stop()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping MediaProjection: ${e.message}")
        }
        mediaProjection = null

        captureThread?.interrupt()
        captureThread = null

        isRunning.set(false)
        Log.i(TAG, "Audio capture stopped and cleaned up")
    }

    override fun onDestroy() {
        stopCapture()
        super.onDestroy()
    }
}
