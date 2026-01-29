package com.move38.nowdeparting.data.model

import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID

data class NearbyTrain(
    val id: String = UUID.randomUUID().toString(),
    val lineId: String,
    val stationId: String,
    val stationName: String,
    val stationDisplay: String,
    val direction: String,
    val destination: String,
    val arrivalTime: Instant,
    val distanceInMeters: Double
) {
    val minutes: Long get() {
        val now = Instant.now()
        val diffSeconds = ChronoUnit.SECONDS.between(now, arrivalTime)
        return diffSeconds / 60
    }

    val seconds: Long get() {
        val now = Instant.now()
        return ChronoUnit.SECONDS.between(now, arrivalTime)
    }

    val timeText: String get() {
        val mins = minutes
        return when {
            mins < 0 -> "--"
            mins == 0L -> "Now"
            mins == 1L -> "1 min"
            else -> "$mins min"
        }
    }

    val preciseTimeText: String get() {
        val secs = seconds
        return when {
            secs < 0 -> "--"
            secs < 30 -> "Now"
            secs < 60 -> "${secs}s"
            else -> {
                val mins = secs / 60
                if (mins == 1L) "1 min" else "$mins min"
            }
        }
    }

    val distanceText: String get() {
        val feet = distanceInMeters * 3.28084
        return if (feet < 1000) {
            "${feet.toInt()} ft"
        } else {
            val miles = feet / 5280
            String.format("%.1f mi", miles)
        }
    }

    val directionText: String get() {
        return when (direction) {
            "N" -> "Uptown"
            "S" -> "Downtown"
            else -> direction
        }
    }
}
