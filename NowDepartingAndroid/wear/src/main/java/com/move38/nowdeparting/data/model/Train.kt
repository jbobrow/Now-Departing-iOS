package com.move38.nowdeparting.data.model

import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter

@Serializable
data class Train(
    val route: String,
    val time: String
) {
    val arrivalTime: Instant? get() {
        return try {
            ZonedDateTime.parse(time, DateTimeFormatter.ISO_OFFSET_DATE_TIME).toInstant()
        } catch (e: Exception) {
            try {
                Instant.parse(time)
            } catch (e2: Exception) {
                null
            }
        }
    }
}

@Serializable
data class RouteStationData(
    val name: String = "",
    val N: List<Train> = emptyList(),
    val S: List<Train> = emptyList()
)

@Serializable
data class RouteApiResponse(
    val data: List<RouteStationData> = emptyList(),
    val updated: String? = null
)
