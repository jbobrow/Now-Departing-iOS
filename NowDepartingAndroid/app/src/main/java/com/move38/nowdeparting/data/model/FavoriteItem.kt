package com.move38.nowdeparting.data.model

import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class FavoriteItem(
    val id: String = UUID.randomUUID().toString(),
    val lineId: String,
    val stationName: String,
    val stationDisplay: String,
    val direction: String
) {
    val displayDirection: String get() {
        return when (direction) {
            "N" -> "Uptown"
            "S" -> "Downtown"
            else -> direction
        }
    }
}
