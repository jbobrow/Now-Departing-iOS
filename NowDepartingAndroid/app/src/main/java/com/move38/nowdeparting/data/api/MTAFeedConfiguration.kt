package com.move38.nowdeparting.data.api

object MTAFeedConfiguration {

    private const val BASE_URL = "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2F"

    // Multiple routes share a single feed file; fetching any route from the
    // group retrieves real-time data for every route in that group.
    //
    // Feed groups:
    //   gtfs      → 1 2 3 4 5 6 7 GS (numbered lines + 42nd St Shuttle)
    //   gtfs-ace  → A C E FS (Franklin Ave Shuttle) H (Rockaway Park)
    //   gtfs-bdfm → B D F M
    //   gtfs-g    → G
    //   gtfs-jz   → J Z
    //   gtfs-nqrw → N Q R W
    //   gtfs-l    → L
    //   gtfs-si   → SI (Staten Island Railway)

    private val feedPathByRoute = mapOf(
        "1"  to "gtfs",
        "2"  to "gtfs",
        "3"  to "gtfs",
        "4"  to "gtfs",
        "5"  to "gtfs",
        "6"  to "gtfs",
        "7"  to "gtfs",
        "GS" to "gtfs",
        "A"  to "gtfs-ace",
        "C"  to "gtfs-ace",
        "E"  to "gtfs-ace",
        "FS" to "gtfs-ace",
        "H"  to "gtfs-ace",
        "B"  to "gtfs-bdfm",
        "D"  to "gtfs-bdfm",
        "F"  to "gtfs-bdfm",
        "M"  to "gtfs-bdfm",
        "G"  to "gtfs-g",
        "J"  to "gtfs-jz",
        "Z"  to "gtfs-jz",
        "N"  to "gtfs-nqrw",
        "Q"  to "gtfs-nqrw",
        "R"  to "gtfs-nqrw",
        "W"  to "gtfs-nqrw",
        "L"  to "gtfs-l",
        "SI" to "gtfs-si"
    )

    /** GTFS-RT service alerts feed URL (all subway lines). */
    val alertsFeedUrl: String = "${BASE_URL}gtfs-alerts"

    /** Returns the GTFS-RT feed URL for a given route ID, or null if unknown. */
    fun feedUrl(routeId: String): String? {
        val path = feedPathByRoute[routeId] ?: return null
        return "$BASE_URL$path"
    }

    /** Returns deduplicated feed URLs for a set of route IDs. Routes that share
     *  a feed file are collapsed to a single URL. */
    fun feedUrls(routeIds: List<String>): List<String> {
        val seenPaths = mutableSetOf<String>()
        val urls = mutableListOf<String>()
        for (routeId in routeIds) {
            val path = feedPathByRoute[routeId] ?: continue
            if (seenPaths.add(path)) {
                urls.add("$BASE_URL$path")
            }
        }
        return urls
    }
}
