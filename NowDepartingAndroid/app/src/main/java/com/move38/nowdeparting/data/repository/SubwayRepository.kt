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
            // Find the station by name in the list
            val stationData = response.data.find { it.name == stationName }

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
                // Calculate distance from user location to station
                val distanceResults = FloatArray(1)
                android.location.Location.distanceBetween(
                    latitude, longitude,
                    stationData.latitude, stationData.longitude,
                    distanceResults
                )
                val distanceInMeters = distanceResults[0].toDouble()

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
                            generalDirection = DirectionHelper.getGeneralDirection(trainData.route, "N"),
                            arrivalTime = arrivalTime,
                            distanceInMeters = distanceInMeters
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
                            generalDirection = DirectionHelper.getGeneralDirection(trainData.route, "S"),
                            arrivalTime = arrivalTime,
                            distanceInMeters = distanceInMeters
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
        "1" to "Van Cortlandt Park–242 St",
        "2" to "Wakefield–241 St",
        "3" to "Harlem–148 St",
        "4" to "Woodlawn",
        "5" to "Eastchester–Dyre Av",
        "6" to "Pelham Bay Park",
        "7" to "Flushing–Main St",
        "A" to "Inwood–207 St",
        "B" to "Bedford Park Blvd",
        "C" to "168 St",
        "D" to "Norwood–205 St",
        "E" to "Jamaica Center",
        "F" to "Jamaica–179 St",
        "G" to "Court Sq",
        "J" to "Jamaica Center",
        "L" to "8 Av",
        "M" to "Forest Hills–71 Av",
        "N" to "Astoria–Ditmars Blvd",
        "Q" to "96 St",
        "R" to "Forest Hills–71 Av",
        "W" to "Astoria–Ditmars Blvd",
        "Z" to "Jamaica Center",
        "S" to "Times Sq–42 St"
    )

    private val southDestinations = mapOf(
        "1" to "South Ferry",
        "2" to "Flatbush Av–Brooklyn College",
        "3" to "New Lots Av",
        "4" to "Crown Heights–Utica Av",
        "5" to "Flatbush Av–Brooklyn College",
        "6" to "Brooklyn Bridge–City Hall",
        "7" to "34 St–Hudson Yards",
        "A" to "Far Rockaway–Mott Av",
        "B" to "Brighton Beach",
        "C" to "Euclid Av",
        "D" to "Coney Island–Stillwell Av",
        "E" to "World Trade Center",
        "F" to "Coney Island–Stillwell Av",
        "G" to "Church Av",
        "J" to "Broad St",
        "L" to "Canarsie–Rockaway Pkwy",
        "M" to "Middle Village–Metropolitan Av",
        "N" to "Coney Island–Stillwell Av",
        "Q" to "Coney Island–Stillwell Av",
        "R" to "Bay Ridge–95 St",
        "W" to "Whitehall St",
        "Z" to "Broad St",
        "S" to "Grand Central–42 St"
    )

    // General direction by borough
    private val northBoroughs = mapOf(
        "1" to "Bronx",
        "2" to "Bronx",
        "3" to "Manhattan",
        "4" to "Bronx",
        "5" to "Bronx",
        "6" to "Bronx",
        "7" to "Queens",
        "A" to "Manhattan",
        "B" to "Bronx",
        "C" to "Manhattan",
        "D" to "Bronx",
        "E" to "Queens",
        "F" to "Queens",
        "G" to "Queens",
        "J" to "Queens",
        "L" to "Manhattan",
        "M" to "Queens",
        "N" to "Queens",
        "Q" to "Manhattan",
        "R" to "Queens",
        "W" to "Queens",
        "Z" to "Queens",
        "S" to "Manhattan"
    )

    private val southBoroughs = mapOf(
        "1" to "Manhattan",
        "2" to "Brooklyn",
        "3" to "Brooklyn",
        "4" to "Brooklyn",
        "5" to "Brooklyn",
        "6" to "Manhattan",
        "7" to "Manhattan",
        "A" to "Queens",
        "B" to "Brooklyn",
        "C" to "Brooklyn",
        "D" to "Brooklyn",
        "E" to "Manhattan",
        "F" to "Brooklyn",
        "G" to "Brooklyn",
        "J" to "Manhattan",
        "L" to "Brooklyn",
        "M" to "Queens",
        "N" to "Brooklyn",
        "Q" to "Brooklyn",
        "R" to "Brooklyn",
        "W" to "Manhattan",
        "Z" to "Manhattan",
        "S" to "Manhattan"
    )

    fun getDestination(lineId: String, direction: String): String {
        return when (direction) {
            "N" -> northDestinations[lineId] ?: "Uptown"
            "S" -> southDestinations[lineId] ?: "Downtown"
            else -> "Unknown"
        }
    }

    fun getGeneralDirection(lineId: String, direction: String): String {
        return when (direction) {
            "N" -> northBoroughs[lineId] ?: "Uptown"
            "S" -> southBoroughs[lineId] ?: "Downtown"
            else -> direction
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
