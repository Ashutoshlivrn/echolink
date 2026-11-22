package com.example.audio_sharing

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.util.Log

class BluetoothAudioHelper(
    private val context: Context,
    private val onDevicesChanged: (List<Map<String, Any>>) -> Unit
) {

    companion object {
        private const val TAG = "BluetoothAudioHelper"
    }

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var audioDeviceCallback: AudioDeviceCallback? = null
    private var broadcastReceiver: BroadcastReceiver? = null

    fun startListening() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            audioDeviceCallback = object : AudioDeviceCallback() {
                override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) {
                    super.onAudioDevicesAdded(addedDevices)
                    Log.i(TAG, "Audio devices added")
                    notifyDevicesChanged()
                }

                override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
                    super.onAudioDevicesRemoved(removedDevices)
                    Log.i(TAG, "Audio devices removed")
                    notifyDevicesChanged()
                }
            }
            audioManager.registerAudioDeviceCallback(audioDeviceCallback, null)
        }

        val filter = IntentFilter().apply {
            addAction(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
        }

        broadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                Log.i(TAG, "Audio route change action: ${intent?.action}")
                notifyDevicesChanged()
            }
        }
        context.registerReceiver(broadcastReceiver, filter)
    }

    fun stopListening() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && audioDeviceCallback != null) {
            audioManager.unregisterAudioDeviceCallback(audioDeviceCallback)
            audioDeviceCallback = null
        }
        if (broadcastReceiver != null) {
            try {
                context.unregisterReceiver(broadcastReceiver)
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering receiver: ${e.message}")
            }
            broadcastReceiver = null
        }
    }

    fun getCurrentOutputDevices(): List<Map<String, Any>> {
        val deviceList = mutableListOf<Map<String, Any>>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            for (device in devices) {
                val typeName = getDeviceTypeName(device.type)
                val isBt = isBluetoothDevice(device.type)
                val name = device.productName?.toString()?.ifEmpty { typeName } ?: typeName

                deviceList.add(
                    mapOf(
                        "id" to device.id,
                        "name" to name,
                        "type" to typeName,
                        "isBluetooth" to isBt,
                        "sampleRates" to device.sampleRates.toList(),
                        "channelCounts" to device.channelCounts.toList()
                    )
                )
            }
        } else {
            val isBtOn = audioManager.isBluetoothA2dpOn || audioManager.isBluetoothScoOn
            deviceList.add(
                mapOf(
                    "id" to 0,
                    "name" to if (isBtOn) "Bluetooth Headset" else "Device Speaker",
                    "type" to if (isBtOn) "Bluetooth" else "Speaker",
                    "isBluetooth" to isBtOn,
                    "sampleRates" to listOf(44100, 48000),
                    "channelCounts" to listOf(2)
                )
            )
        }

        return deviceList
    }

    private fun notifyDevicesChanged() {
        val list = getCurrentOutputDevices()
        onDevicesChanged(list)
    }

    private fun isBluetoothDevice(type: Int): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                    type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                    (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && type == AudioDeviceInfo.TYPE_BLE_HEADSET) ||
                    (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && type == AudioDeviceInfo.TYPE_BLE_SPEAKER)
        } else {
            false
        }
    }

    private fun getDeviceTypeName(type: Int): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return "Speaker"

        return when (type) {
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "Bluetooth Earphones (A2DP)"
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth Headset (SCO)"
            AudioDeviceInfo.TYPE_WIRED_HEADSET -> "Wired Headset"
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "Wired Headphones"
            AudioDeviceInfo.TYPE_USB_HEADSET -> "USB Headset"
            AudioDeviceInfo.TYPE_USB_DEVICE -> "USB Audio"
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "Phone Speaker"
            AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "Earpiece"
            else -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && type == AudioDeviceInfo.TYPE_BLE_HEADSET) {
                    "BLE Headset"
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && type == AudioDeviceInfo.TYPE_BLE_SPEAKER) {
                    "BLE Speaker"
                } else {
                    "Audio Output ($type)"
                }
            }
        }
    }
}
