package com.tomakatcheishvili.yummy

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.min

/**
 * Proximity sensor for cooking mode's hand wave (lib/services/proximity_sensor.dart).
 *
 * - MethodChannel "yummy/proximity": `isAvailable` → Boolean.
 * - EventChannel "yummy/proximity/events": true when something covers the
 *   sensor, false when it clears. It sends only changes, starting with the
 *   current state. The sensor is registered only while Dart listens.
 */
class ProximityChannel(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val sensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_PROXIMITY)

    // The rule Android itself uses to blank the screen during calls: covered
    // when the reading is under the sensor's range, capped at 5 cm. Checking
    // for exactly 0 misses sensors that report a small distance when covered.
    private val nearThreshold = sensor?.let { min(it.maximumRange, TYPICAL_PROXIMITY_THRESHOLD) } ?: 0f

    private var sink: EventChannel.EventSink? = null
    private var lastNear: Boolean? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "yummy/proximity").setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(sensor != null)
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, "yummy/proximity/events").setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val proximity = sensor
        if (proximity == null) {
            events.error("UNAVAILABLE", "This device has no proximity sensor", null)
            return
        }
        sink = events
        lastNear = null
        sensorManager.registerListener(this, proximity, SensorManager.SENSOR_DELAY_UI)
    }

    override fun onCancel(arguments: Any?) {
        sensorManager.unregisterListener(this)
        sink = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        val distance = event.values[0]
        val near = distance >= 0f && distance < nearThreshold
        if (near == lastNear) return
        lastNear = near
        sink?.success(near)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private companion object {
        const val TYPICAL_PROXIMITY_THRESHOLD = 5f
    }
}
