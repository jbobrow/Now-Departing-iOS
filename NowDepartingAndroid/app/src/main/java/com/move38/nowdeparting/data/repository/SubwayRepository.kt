package com.move38.nowdeparting.data.repository

import android.content.Context
import android.util.Log
import com.move38.nowdeparting.data.api.GTFSAlert
import com.move38.nowdeparting.data.api.MTAFeedService
import com.move38.nowdeparting.data.model.*
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SubwayRepository @Inject constructor(
    private val mtaFeedService: MTAFeedService,
    @ApplicationContext private val context: Context
) {
    private val json = Json { ignoreUnknownKeys = true }

    companion object {
        private const val TAG = "SubwayRepository"
        private const val STATIONS_FILE = "stations.json"
    }

    private var cachedStations: Map<String, List<Station>>? = null

    private suspend fun getAllStations(): Map<String, List<Station>> {
        if (cachedStations == null) {
            cachedStations = loadStationsData()
        }
        return cachedStations ?: emptyMap()
    }

    suspend fun getStationsForLine(lineId: String): List<Station> {
        val stations = getAllStations()[lineId] ?: emptyList()
        return mtaFeedService.checkAvailability(lineId, stations)
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
        val station = getAllStations()[lineId]?.find { it.name == stationName }
            ?: return@withContext Result.failure(Exception("Station not found: $stationName"))

        mtaFeedService.fetchArrivals(lineId, station, direction)
    }

    /** Fetches service alerts grouped by route ID. */
    suspend fun getServiceAlerts(): Result<Map<String, List<GTFSAlert>>> = withContext(Dispatchers.IO) {
        mtaFeedService.fetchServiceAlerts().map { alerts ->
            val byRoute = mutableMapOf<String, MutableList<GTFSAlert>>()
            for (alert in alerts) {
                if (alert.headerText.isBlank()) continue
                for (routeId in alert.routeIds) {
                    byRoute.getOrPut(routeId) { mutableListOf() }.add(alert)
                }
            }
            byRoute
        }
    }

    suspend fun getNearbyTrains(
        latitude: Double,
        longitude: Double
    ): Result<List<NearbyTrain>> = withContext(Dispatchers.IO) {
        val allStations = getAllStations()

        mtaFeedService.fetchNearbyArrivals(
            latitude = latitude,
            longitude = longitude,
            stationsByLine = allStations
        ).map { arrivals ->
            arrivals
                .filter { DirectionHelper.isValidRoute(it.routeId) }
                .map { arrival ->
                    NearbyTrain(
                        lineId = arrival.routeId,
                        stationId = arrival.gtfsStopId ?: arrival.stationName,
                        stationName = arrival.stationName,
                        stationDisplay = arrival.stationDisplay,
                        direction = arrival.direction,
                        destination = DirectionHelper.getDestination(arrival.routeId, arrival.direction),
                        generalDirection = DirectionHelper.getGeneralDirection(arrival.routeId, arrival.direction),
                        arrivalTime = arrival.arrivalTime,
                        distanceInMeters = arrival.distanceInMeters
                    )
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

    fun isValidRoute(routeId: String): Boolean {
        return northDestinations.containsKey(routeId)
    }
}
