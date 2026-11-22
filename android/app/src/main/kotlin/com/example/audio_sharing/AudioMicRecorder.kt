package com.example.audio_sharing

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.max

class AudioMicRecorder(private val onMicChunk: (ByteArray) -> Unit) {

    companion object {
        private const val TAG = "AudioMicRecorder"
        private const val SAMPLE_RATE = 16000 // 16kHz mono is ideal for voice chat
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    }

    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null
    private val isRecording = AtomicBoolean(false)

    fun start(): Boolean {
        if (isRecording.get()) return true

        try {
            val minBufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
            // 20ms chunk at 16kHz 16-bit mono = 16000 * 1 * 2 * 0.02 = 640 bytes
            val chunkBytes = (SAMPLE_RATE * 1 * 2 * 0.02).toInt()
            val bufferSize = max(minBufferSize, chunkBytes * 4)

            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord for mic failed to initialize")
                audioRecord = null
                return false
            }

            audioRecord?.startRecording()
            isRecording.set(true)

            recordingThread = Thread({
                val buffer = ByteArray(chunkBytes)
                while (isRecording.get() && audioRecord != null) {
                    val read = audioRecord!!.read(buffer, 0, buffer.size)
                    if (read > 0) {
                        val chunk = if (read == buffer.size) buffer.clone() else buffer.copyOf(read)
                        onMicChunk(chunk)
                    } else {
                        Thread.sleep(5)
                    }
                }
            }, "MicRecorderWorker")
            recordingThread?.start()

            Log.i(TAG, "Microphone recording started successfully (16kHz mono)")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error starting microphone recording: ${e.message}", e)
            stop()
            return false
        }
    }

    fun stop() {
        isRecording.set(false)
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping mic AudioRecord: ${e.message}")
        }
        audioRecord = null
        recordingThread?.interrupt()
        recordingThread = null
        Log.i(TAG, "Microphone recording stopped")
    }
}
