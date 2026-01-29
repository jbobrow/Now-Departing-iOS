package com.move38.nowdeparting.data.repository

import android.content.Context
import android.util.Log
import com.move38.nowdeparting.data.api.MtaApiService
import com.move38.nowdeparting.data.model.*
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.time.Instant
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SubwayRepository @Inject constructor(
    private val apiService: MtaApiService,
    @ApplicationContext private val context: Context
) {
    private val json = Json { ignoreUnknownKeys = true }

    companion object {
        private const val TAG = "SubwayRepository"
        private const val STATIONS_FILE = "stations.json"
    }

    private var cachedStations: Map<String, List<Station>>? = null

    suspend fun getStationsForLine(lineId: String): List<Station> {
        if (cachedStations == null) {
            cachedStations = loadStationsData()
        }
        return cachedStations?.get(lineId) ?: emptyList()
    }

    private suspend fun loadStationsData(): Map<String, List<Station>> = withContext(Dispatchers.IO) {
        try {
            val jsonString = context.assets.open(STATIONS_FILE).bufferedReader().use { it.readText() }
            json.decodeFromString<StationsData>(jsonString)
        } catch (e: Exception) {
            Log.e(TAG, "Error loading stations data", e)
            emptyMap()
        }
    }

    suspend fun getTrainTimes(
        lineId: String,
        stationName: String,
        direction: String
    ): Result<List<Instant>> = withContext(Dispatchers.IO) {
        try {
            val response = apiService.getTrainsByRoute(lineId)
            val stationData = response[stationName]

            if (stationData == null) {
                return@withContext Result.success(emptyList())
            }

            val trains = when (direction) {
                "N" -> stationData.N
                "S" -> stationData.S
                else -> emptyList()
            }

            val times = trains
                .filter { it.route == lineId }
                .mapNotNull { it.arrivalTime }
                .filter { it.isAfter(Instant.now().minusSeconds(120)) }
                .sorted()

            Result.success(times)
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching train times", e)
            Result.failure(e)
        }
    }

    suspend fun getNearbyTrains(
        latitude: Double,
        longitude: Double
    ): Result<List<NearbyTrain>> = withContext(Dispatchers.IO) {
        try {
            val response = apiService.getTrainsByLocation(latitude, longitude)
            val trains = mutableListOf<NearbyTrain>()

            for (stationData in response.data) {
                // Process North-bound trains
                for (trainData in stationData.N) {
                    val arrivalTime = parseTime(trainData.time) ?: continue
                    if (arrivalTime.isBefore(Instant.now().minusSeconds(120))) continue

                    trains.add(
                        NearbyTrain(
                            lineId = trainData.route,
                            stationId = stationData.id.ifEmpty { stationData.name },
                            stationName = stationData.name,
                            stationDisplay = stationData.name,
                            direction = "N",
                            destination = DirectionHelper.getDestination(trainData.route, "N"),
                            arrivalTime = arrivalTime,
                            distanceInMeters = stationData.distance
                        )
                    )
                }

                // Process South-bound trains
                for (trainData in stationData.S) {
                    val arrivalTime = parseTime(trainData.time) ?: continue
                    if (arrivalTime.isBefore(Instant.now().minusSeconds(120))) continue

                    trains.add(
                        NearbyTrain(
                            lineId = trainData.route,
                            stationId = stationData.id.ifEmpty { stationData.name },
                            stationName = stationData.name,
                            stationDisplay = stationData.name,
                            direction = "S",
                            destination = DirectionHelper.getDestination(trainData.route, "S"),
                            arrivalTime = arrivalTime,
                            distanceInMeters = stationData.distance
                        )
                    )
                }
            }

            // Sort by arrival time
            Result.success(trains.sortedBy { it.arrivalTime })
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching nearby trains", e)
            Result.failure(e)
        }
    }

    private fun parseTime(timeString: String): Instant? {
        return try {
            ZonedDateTime.parse(timeString, DateTimeFormatter.ISO_OFFSET_DATE_TIME).toInstant()
        } catch (e: Exception) {
            try {
                Instant.parse(timeString)
            } catch (e2: Exception) {
                null
            }
        }
    }
}

object DirectionHelper {
    private val northDestinations = mapOf(
        "1" to "Van Cortlandt Park",
        "2" to "Wakefield",
        "3" to "Harlem",
        "4" to "Woodlawn",
        "5" to "Eastchester",
        "6" to "Pelham Bay Park",
        "7" to "Flushing",
        "A" to "Inwood",
        "B" to "Bedford Park",
        "C" to "168 St",
        "D" to "Norwood",
        "E" to "Jamaica Center",
        "F" to "Jamaica",
        "G" to "Court Sq",
        "J" to "Jamaica Center",
        "L" to "8 Av",
        "M" to "Forest Hills",
        "N" to "Astoria",
        "Q" to "96 St",
        "R" to "Forest Hills",
        "W" to "Astoria",
        "Z" to "Jamaica Center",
        "S" to "Times Sq"
    )

    private val southDestinations = mapOf(
        "1" to "South Ferry",
        "2" to "Flatbush",
        "3" to "New Lots",
        "4" to "Crown Heights",
        "5" to "Flatbush",
        "6" to "Brooklyn Bridge",
        "7" to "34 St Hudson Yards",
        "A" to "Far Rockaway",
        "B" to "Brighton Beach",
        "C" to "Euclid Av",
        "D" to "Coney Island",
        "E" to "World Trade Center",
        "F" to "Coney Island",
        "G" to "Church Av",
        "J" to "Broad St",
        "L" to "Canarsie",
        "M" to "Middle Village",
        "N" to "Coney Island",
        "Q" to "Coney Island",
        "R" to "Bay Ridge",
        "W" to "Whitehall",
        "Z" to "Broad St",
        "S" to "Grand Central"
    )

    fun getDestination(lineId: String, direction: String): String {
        return when (direction) {
            "N" -> northDestinations[lineId] ?: "Uptown"
            "S" -> southDestinations[lineId] ?: "Downtown"
            else -> "Unknown"
        }
    }

    fun getDirectionName(direction: String): String {
        return when (direction) {
            "N" -> "Uptown"
            "S" -> "Downtown"
            else -> direction
        }
    }
}
