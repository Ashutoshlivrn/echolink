package com.example.audio_sharing

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max

class AudioPlayerService {

    companion object {
        private const val TAG = "AudioPlayerService"
        val instance = AudioPlayerService()
    }

    private var audioTrack: AudioTrack? = null
    private val isPlaying = AtomicBoolean(false)
    private var totalBytesWritten = 0L

    data class PlayerStats(
        val isPlaying: Boolean,
        val totalBytes: Long,
        val underrunCount: Int,
        val sampleRate: Int
    )

    fun start(sampleRate: Int = 48000, channels: Int = 2): Boolean {
        if (isPlaying.get()) {
            Log.w(TAG, "AudioPlayer is already running")
            return true
        }

        try {
            val channelConfig = if (channels == 1) {
                AudioFormat.CHANNEL_OUT_MONO
            } else {
                AudioFormat.CHANNEL_OUT_STEREO
            }
            val audioFormat = AudioFormat.ENCODING_PCM_16BIT

            val minBufferSize = AudioTrack.getMinBufferSize(sampleRate, channelConfig, audioFormat)
            // Use comfortable buffer size for network jitter resilience
            val bufferSize = max(minBufferSize * 2, 8192)

            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()

            val format = AudioFormat.Builder()
                .setEncoding(audioFormat)
                .setSampleRate(sampleRate)
                .setChannelMask(channelConfig)
                .build()

            audioTrack = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                AudioTrack.Builder()
                    .setAudioAttributes(attributes)
                    .setAudioFormat(format)
                    .setBufferSizeInBytes(bufferSize)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                    .build()
            } else {
                AudioTrack.Builder()
                    .setAudioAttributes(attributes)
                    .setAudioFormat(format)
                    .setBufferSizeInBytes(bufferSize)
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .build()
            }

            if (audioTrack?.state != AudioTrack.STATE_INITIALIZED) {
                Log.e(TAG, "AudioTrack failed to initialize")
                audioTrack = null
                return false
            }

            audioTrack?.play()
            isPlaying.set(true)
            totalBytesWritten = 0L
            Log.i(TAG, "AudioTrack started successfully ($sampleRate Hz, $channels channels)")
            return true

        } catch (e: Exception) {
            Log.e(TAG, "Exception starting AudioTrack: ${e.message}", e)
            stop()
            return false
        }
    }

    fun write(data: ByteArray): Int {
        if (!isPlaying.get() || audioTrack == null) {
            return -1
        }
        return try {
            val written = audioTrack!!.write(data, 0, data.size, AudioTrack.WRITE_BLOCKING)
            if (written > 0) {
                totalBytesWritten += written
            }
            written
        } catch (e: Exception) {
            Log.e(TAG, "Error writing to AudioTrack: ${e.message}")
            -1
        }
    }

    fun setVolume(volume: Float): Boolean {
        return try {
            val clamped = volume.coerceIn(0.0f, 1.0f)
            audioTrack?.setVolume(clamped)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error setting volume: ${e.message}")
            false
        }
    }

    fun getStats(): PlayerStats {
        val underruns = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && audioTrack != null) {
            audioTrack?.underrunCount ?: 0
        } else {
            0
        }
        return PlayerStats(
            isPlaying = isPlaying.get(),
            totalBytes = totalBytesWritten,
            underrunCount = underruns,
            sampleRate = audioTrack?.sampleRate ?: 48000
        )
    }

    fun stop() {
        isPlaying.set(false)
        try {
            audioTrack?.pause()
            audioTrack?.flush()
            audioTrack?.stop()
            audioTrack?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping AudioTrack: ${e.message}")
        }
        audioTrack = null
        Log.i(TAG, "AudioTrack stopped and released")
    }
}
