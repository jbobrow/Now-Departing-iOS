package com.move38.nowdeparting.data.api

import android.location.Location
import android.util.Log
import com.move38.nowdeparting.data.model.Station
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.time.Instant
import java.util.concurrent.ConcurrentHashMap
import javax.inject.Inject
import javax.inject.Singleton

data class MTANearbyArrival(
    val routeId: String,
    val gtfsStopId: String?,
    val stationName: String,
    val stationDisplay: String,
    val direction: String,
    val arrivalTime: Instant,
    val distanceInMeters: Double
)

sealed class MTAFeedError : Exception() {
    data class MissingStopId(val stationName: String) : MTAFeedError()
    data class NetworkError(override val cause: Throwable) : MTAFeedError()
    data class HttpError(val code: Int) : MTAFeedError()
    data class ParseError(override val cause: Throwable) : MTAFeedError()
    object NoData : MTAFeedError()
}

@Singleton
class MTAFeedService @Inject constructor(
    private val okHttpClient: OkHttpClient
) {
    companion object {
        private const val TAG = "MTAFeedService"
        private const val CACHE_TTL_MS = 30_000L  // GTFS-RT feeds refresh ~every 30s
    }

    private val parser = GTFSRTParser()
    // Cache: feed URL → (fetchTimeMs, parsedUpdates)
    private val cache = ConcurrentHashMap<String, Pair<Long, List<GTFSTripUpdate>>>()

    // MARK: - By-Station Query

    /** Fetches arrival times at a specific station for a given route and direction. */
    suspend fun fetchArrivals(
        routeId: String,
        station: Station,
        direction: String
    ): Result<List<Instant>> = withContext(Dispatchers.IO) {
        val parentStopId = station.gtfsStopId
        if (parentStopId.isNullOrEmpty()) {
            return@withContext Result.failure(MTAFeedError.MissingStopId(station.name))
        }

        val targetStopId = parentStopId + direction  // e.g. "127" + "N" → "127N"

        fetchFeed(routeId).map { updates ->
            val now = Instant.now()
            updates
                .filter { it.routeId == routeId }
                .flatMap { update ->
                    update.stopTimeUpdates
                        .filter { it.stopId == targetStopId }
                        .mapNotNull { it.arrivalTime ?: it.departureTime }
                }
                .filter { it.isAfter(now) }
                .sorted()
        }
    }

    // MARK: - By-Location Query

    /** Fetches all arrivals within radiusMeters of the given location across every
     *  feed group. Returns raw MTANearbyArrival values. */
    suspend fun fetchNearbyArrivals(
        latitude: Double,
        longitude: Double,
        radiusMeters: Float = 1600f,
        stationsByLine: Map<String, List<Station>>
    ): Result<List<MTANearbyArrival>> = withContext(Dispatchers.IO) {
        data class NearbyStop(val station: Station, val distance: Float)

        val nearbyStops = mutableListOf<NearbyStop>()
        val seenNames = mutableSetOf<String>()

        for (stations in stationsByLine.values) {
            for (station in stations) {
                if (!seenNames.add(station.name)) continue
                station.gtfsStopId ?: continue
                val lat = station.latitude ?: continue
                val lon = station.longitude ?: continue

                val distResults = FloatArray(1)
                Location.distanceBetween(latitude, longitude, lat, lon, distResults)
                if (distResults[0] <= radiusMeters) {
                    nearbyStops.add(NearbyStop(station, distResults[0]))
                }
            }
        }

        if (nearbyStops.isEmpty()) return@withContext Result.success(emptyList())

        val feedUrls = MTAFeedConfiguration.feedUrls(stationsByLine.keys.toList())

        coroutineScope {
            val feedResults = feedUrls.map { url ->
                async { fetchFeedData(url) }
            }.map { it.await() }

            val allUpdates = mutableListOf<GTFSTripUpdate>()
            var firstError: MTAFeedError? = null

            for (result in feedResults) {
                result.fold(
                    onSuccess = { allUpdates.addAll(it) },
                    onFailure = { if (firstError == null) firstError = it as? MTAFeedError }
                )
            }

            if (allUpdates.isEmpty() && firstError != null) {
                return@coroutineScope Result.failure(firstError!!)
            }

            val now = Instant.now()
            val results = mutableListOf<MTANearbyArrival>()

            for (stop in nearbyStops) {
                for (dir in listOf("N", "S")) {
                    val parentId = stop.station.gtfsStopId ?: continue
                    val stopId = parentId + dir

                    for (update in allUpdates) {
                        for (stu in update.stopTimeUpdates) {
                            if (stu.stopId != stopId) continue
                            val arrivalTime = stu.arrivalTime ?: stu.departureTime ?: continue
                            if (!arrivalTime.isAfter(now)) continue
                            val minutesAway = (arrivalTime.epochSecond - now.epochSecond) / 60
                            if (minutesAway < 0 || minutesAway > 30) continue

                            results.add(
                                MTANearbyArrival(
                                    routeId = update.routeId,
                                    gtfsStopId = stop.station.gtfsStopId,
                                    stationName = stop.station.name,
                                    stationDisplay = stop.station.display,
                                    direction = dir,
                                    arrivalTime = arrivalTime,
                                    distanceInMeters = stop.distance.toDouble()
                                )
                            )
                        }
                    }
                }
            }

            // Sort: primarily by arrival time; secondarily by distance when times
            // are within 1 minute of each other.
            val sorted = results.sortedWith { a, b ->
                val tA = a.arrivalTime.epochSecond - now.epochSecond
                val tB = b.arrivalTime.epochSecond - now.epochSecond
                if (Math.abs(tA - tB) < 60) a.distanceInMeters.compareTo(b.distanceInMeters)
                else tA.compareTo(tB)
            }

            Result.success(sorted)
        }
    }

    // MARK: - Availability Check

    /** Checks which stations on a line have live arrivals and updates hasAvailableTimes. */
    suspend fun checkAvailability(
        lineId: String,
        stations: List<Station>
    ): List<Station> = withContext(Dispatchers.IO) {
        val result = fetchFeed(lineId)
        if (result.isFailure) return@withContext stations

        val updates = result.getOrDefault(emptyList())
        val activeStopIds = updates
            .filter { it.routeId == lineId }
            .flatMapTo(mutableSetOf()) { update ->
                update.stopTimeUpdates.map { it.stopId }
            }

        stations.map { station ->
            val parentId = station.gtfsStopId
            val hasData = if (parentId != null) {
                activeStopIds.contains(parentId + "N") || activeStopIds.contains(parentId + "S")
            } else {
                false
            }
            station.copy(hasAvailableTimes = hasData)
        }
    }

    // MARK: - Feed Fetch + Cache

    private suspend fun fetchFeed(routeId: String): Result<List<GTFSTripUpdate>> {
        val url = MTAFeedConfiguration.feedUrl(routeId)
            ?: return Result.failure(
                MTAFeedError.NetworkError(IllegalArgumentException("Unknown route: $routeId"))
            )
        return fetchFeedData(url)
    }

    /** Fetches and parses a GTFS-RT feed, using the in-memory cache when fresh.
     *  Must be called from a background thread (uses blocking OkHttp execute()). */
    private fun fetchFeedData(url: String): Result<List<GTFSTripUpdate>> {
        val cached = cache[url]
        if (cached != null && System.currentTimeMillis() - cached.first < CACHE_TTL_MS) {
            return Result.success(cached.second)
        }

        return try {
            val request = Request.Builder().url(url).build()
            val response = okHttpClient.newCall(request).execute()

            if (!response.isSuccessful) {
                return Result.failure(MTAFeedError.HttpError(response.code))
            }

            val bytes = response.body?.bytes()
            if (bytes == null || bytes.isEmpty()) {
                return Result.failure(MTAFeedError.NoData)
            }

            val updates = parser.parse(bytes)
            cache[url] = Pair(System.currentTimeMillis(), updates)
            Result.success(updates)
        } catch (e: GTFSRTParser.ParseError) {
            Result.failure(MTAFeedError.ParseError(e))
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching feed: $url", e)
            Result.failure(MTAFeedError.NetworkError(e))
        }
    }
}
