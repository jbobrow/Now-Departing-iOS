package com.move38.nowdeparting.data.model

import kotlinx.serialization.Serializable

@Serializable
data class NearbyApiResponse(
    val data: List<NearbyStationData> = emptyList(),
    val updated: String? = null
)

@Serializable
data class NearbyStationData(
    val name: String,
    val id: String = "",
    val routes: List<String> = emptyList(),
    val location: List<Double> = emptyList(), // [latitude, longitude]
    val N: List<NearbyTrainData> = emptyList(),
    val S: List<NearbyTrainData> = emptyList()
) {
    val latitude: Double get() = location.getOrNull(0) ?: 0.0
    val longitude: Double get() = location.getOrNull(1) ?: 0.0
}

@Serializable
data class NearbyTrainData(
    val route: String,
    val time: String
)
