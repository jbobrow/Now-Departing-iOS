package com.move38.nowdeparting.data.model

import kotlinx.serialization.Serializable

@Serializable
data class Station(
    val name: String,
    val display: String = "",
    val hasAvailableTimes: Boolean = true
) {
    val id: String get() = name
    val displayName: String get() = display.ifEmpty { name }
}

// The stations.json file is a direct map of line IDs to station lists
typealias StationsData = Map<String, List<Station>>
