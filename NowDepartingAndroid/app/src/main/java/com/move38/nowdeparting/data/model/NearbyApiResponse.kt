package com.move38.nowdeparting.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class NearbyApiResponse(
    val data: List<NearbyStationData> = emptyList()
)

@Serializable
data class NearbyStationData(
    val name: String,
    val id: String = "",
    val routes: List<String> = emptyList(),
    val distance: Double = 0.0,
    val N: List<NearbyTrainData> = emptyList(),
    val S: List<NearbyTrainData> = emptyList()
)

@Serializable
data class NearbyTrainData(
    val route: String,
    val time: String
)
