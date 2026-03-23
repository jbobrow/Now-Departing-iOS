package com.move38.nowdeparting.data.api

import java.time.Instant

//
//  GTFSRTParser.kt
//  Now Departing
//
//  A minimal binary Protocol Buffers decoder for GTFS-RT feeds.
//
//  Decodes only the subset of the GTFS-RT schema the app uses:
//
//    FeedMessage
//      └─ entity[]          (FeedEntity, field 2)
//           └─ trip_update  (TripUpdate, field 3)
//                ├─ trip    (TripDescriptor, field 1)
//                │    ├─ trip_id      (string, field 1)
//                │    ├─ route_id     (string, field 5)
//                │    └─ direction_id (uint32, field 9)
//                └─ stop_time_update[] (StopTimeUpdate, field 2)
//                     ├─ stop_id  (string, field 4)
//                     ├─ arrival  (StopTimeEvent, field 2)
//                     │    └─ time (int64, field 2) — Unix timestamp
//                     └─ departure (StopTimeEvent, field 3)
//                          └─ time (int64, field 2) — Unix timestamp
//

data class GTFSTripUpdate(
    val routeId: String,
    val tripId: String,
    val directionId: Int?,
    val stopTimeUpdates: List<GTFSStopTimeUpdate>
)

data class GTFSStopTimeUpdate(
    val stopId: String,
    val arrivalTime: Instant?,
    val departureTime: Instant?
)

/** A parsed GTFS-RT Alert entity. */
data class GTFSAlert(
    /** Route IDs this alert applies to (from informed_entity[].route_id). */
    val routeIds: List<String>,
    /** Short summary of the alert (TranslatedString, field 10). */
    val headerText: String,
    /** Detailed description of the alert (TranslatedString, field 13). */
    val descriptionText: String,
    /** Raw GTFS-RT Effect enum value (field 7). */
    val effect: Int
)

class GTFSRTParser {

    sealed class ParseError : Exception() {
        object InvalidData : ParseError()
        object TruncatedMessage : ParseError()
    }

    private enum class WireType(val value: Int) {
        VARINT(0),
        FIXED64(1),
        LENGTH_DELIMITED(2),
        FIXED32(5);

        companion object {
            fun fromInt(value: Int): WireType? = values().find { it.value == value }
        }
    }

    fun parse(data: ByteArray): List<GTFSTripUpdate> {
        val updates = mutableListOf<GTFSTripUpdate>()
        var offset = 0

        while (offset < data.size) {
            val (fieldNumber, wireType, afterTag) = readTag(data, offset)
            offset = afterTag

            // FeedMessage.entity is field 2, wire-type length-delimited.
            if (fieldNumber == 2 && wireType == WireType.LENGTH_DELIMITED) {
                val (entityData, afterEntity) = readBytes(data, offset)
                offset = afterEntity
                parseFeedEntity(entityData)?.let { updates.add(it) }
            } else {
                offset = skip(data, offset, wireType)
            }
        }

        return updates
    }

    // MARK: - Alert Parsing

    /** Parses a GTFS-RT Alerts feed binary blob, returning all alert entities. */
    fun parseAlerts(data: ByteArray): List<GTFSAlert> {
        val alerts = mutableListOf<GTFSAlert>()
        var offset = 0

        while (offset < data.size) {
            val (fieldNumber, wireType, afterTag) = readTag(data, offset)
            offset = afterTag

            if (fieldNumber == 2 && wireType == WireType.LENGTH_DELIMITED) {
                val (entityData, afterEntity) = readBytes(data, offset)
                offset = afterEntity
                parseFeedEntityForAlert(entityData)?.let { alerts.add(it) }
            } else {
                offset = skip(data, offset, wireType)
            }
        }

        return alerts
    }

    private fun parseFeedEntityForAlert(data: ByteArray): GTFSAlert? {
        var offset = 0

        while (offset < data.size) {
            val (fieldNumber, wireType, afterTag) = readTag(data, offset)
            offset = afterTag

            // FeedEntity.alert is field 5.
            if (fieldNumber == 5 && wireType == WireType.LENGTH_DELIMITED) {
                val (alertData, afterAlert) = readBytes(data, offset)
                offset = afterAlert
                return parseAlert(alertData)
            } else {
                offset = skip(data, offset, wireType)
            }
        }

        return null
    }

    private fun parseAlert(data: ByteArray): GTFSAlert {
        var offset = 0
        val routeIds = mutableListOf<String>()
        var headerText = ""
        var descriptionText = ""
        var effect = 0

        while (offset < data.size) {
            val (fieldNumber, wireType, afterTag) = readTag(data, offset)
            offset = afterTag

            when (fieldNumber) {
                5 -> { // informed_entity (repeated EntitySelector)
                    if (wireType == WireType.LENGTH_DELIMITED) {
                        val (selectorData, after) = readBytes(data, offset)
                        offset = after
                        parseEntitySelectorRouteId(selectorData)?.let { routeIds.add(it) }
                    } else {
                        offset = skip(data, offset, wireType)
                    }
                }
                7 -> { // effect (uint32 varint)
                    if (wireType == WireType.VARINT) {
                        val (value, after) = readVarint(data, offset)
                        offset = after
                        effect = value.toInt()
                    } else {
                        offset = skip(data, offset, wireType)
                    }
                }
                10 -> { // header_text (TranslatedString)
                    if (wireType == WireType.LENGTH_DELIMITED) {
                        val (tsData, after) = readBytes(data, offset)
                        offset = after
                        headerText = parseTranslatedString(tsData)
                    } else {
                        offset = skip(data, offset, wireType)
                    }
                }
                11 -> { // description_text (TranslatedString)
                    if (wireType == WireType.LENGTH_DELIMITED) {
                        val (tsData, after) = readBytes(data, offset)
                        offset = after
                        descriptionText = parseTranslatedString(tsData)
                    } else {
                        offset = skip(data, offset, wireType)
                    }
                }
                else -> offset = skip(data, offset, wireType)
            }
        }

        return GTFSAlert(routeIds = routeIds, headerText = headerText, descriptionText = descriptionText, effect = effect)
    }

    private fun parseEntitySelectorRouteId(data: ByteArray): String? {
        var offset = 0
        var routeId: String? = null

        while (offset < data.size) {
            val (fieldNumber, wireType, afterTag) = readTag(data, offset)
            offset = afterTag

            if (fieldNumber == 2 && wireType == WireType.LENGTH_DELIMITED) { // route_id
                val (bytes, after) = readBytes(data, offset)
                offset = after
                routeId = String(bytes, Charsets.UTF_8)
            } else {
                offset = skip(data, offset, wireType)
            }
        }

        return routeId
    }

    private fun parseTranslatedString(data: ByteArray): String {
        var offset = 0
        var englishText = ""
        var firstText = ""

        while (offset < data.size) {
            val (fieldNumber, wireType, afterTag) = readTag(data, offset)
            offset = afterTag

            if (fieldNumber == 1 && wireType == WireType.LENGTH_DELIMITED) { // translation (repeated)
                val (translationData, after) = readBytes(data, offset)
                offset = after
                val (text, language) = parseTranslation(translationData)
                if (firstText.isEmpty()) firstText = text
                if (language == "en" || language.isEmpty()) englishText = text
            } else {
                offset = skip(data, offset, wireType)
            }
        }

        return if (englishText.isNotEmpty()) englishText else firstText
    }

    private fun parseTranslation(data: ByteArray): Pair<String, String> {
        var offset = 0
        var text = ""
        var language = ""

        while (offset < data.size) {
            val (fieldNumber, wireType, afterTag) = readTag(data, offset)
            offset = afterTag

            when (fieldNumber) {
                1 -> { // text
                    if (wireType == WireType.LENGTH_DELIMITED) {
                        val (bytes, after) = readBytes(data, offset)
                        offset = after
                        text = String(bytes, Charsets.UTF_8)
                    } else {
                        offset = skip(data, offset, wireType)
                    }
                }
                2 -> { // language
                    if (wireType == WireType.LENGTH_DELIMITED) {
                        val (bytes, after) = readBytes(data, offset)
                        offset = after
                        language = String(bytes, Charsets.UTF_8)
                    } else {
                        offset = skip(data, offset, wireType)
                    }
                }
                else -> offset = skip(data, offset, wireType)
            }
        }

        return Pair(text, language)
    }

    // MARK: - Trip Update Parsing

    private fun parseFeedEntity(data: ByteArray): GTFSTripUpdate? {
        var offset = 0
        var result: GTFSTripUpdate? = null

        while (offset < data.size) {
            val (fieldNumber, wireType, afterTag) = readTag(data, offset)
            offset = afterTag

            // FeedEntity.trip_update is field 3.
            if (fieldNumber == 3 && wireType == WireType.LENGTH_DELIMITED) {
                val (tuData, afterTU) = readBytes(data, offset)
                offset = afterTU
                result = parseTripUpdate(tuData)
            } else {
                offset = skip(data, offset, wireType)
            }
        }

        return result
    }

    private fun parseTripUpdate(data: ByteArray): GTFSTripUpdate? {
        var offset = 0
        var routeId = ""
        var tripId = ""
        var directionId: Int? = null
        val stopTimeUpdates = mutableListOf<GTFSStopTimeUpdate>()

        while (offset < data.size) {
            val (fieldNumber, wireType, afterTag) = readTag(data, offset)
            offset = afterTag

            when (fieldNumber) {
                1 -> { // TripUpdate.trip (TripDescriptor)
                    if (wireType == WireType.LENGTH_DELIMITED) {
                        val (tdData, afterTD) = readBytes(data, offset)
                        offset = afterTD
                        val td = parseTripDescriptor(tdData)
                        routeId = td.routeId
                        tripId = td.tripId
                        directionId = td.directionId
                    } else {
                        offset = skip(data, offset, wireType)
                    }
                }
                2 -> { // TripUpdate.stop_time_update (repeated)
                    if (wireType == WireType.LENGTH_DELIMITED) {
                        val (stuData, afterSTU) = readBytes(data, offset)
                        offset = afterSTU
                        parseStopTimeUpdate(stuData)?.let { stopTimeUpdates.add(it) }
                    } else {
                        offset = skip(data, offset, wireType)
                    }
                }
                else -> offset = skip(data, offset, wireType)
            }
        }

        if (routeId.isEmpty()) return null
        return GTFSTripUpdate(routeId, tripId, directionId, stopTimeUpdates)
    }

    private data class TripDescriptorResult(val routeId: String, val tripId: String, val directionId: Int?)

    private fun parseTripDescriptor(data: ByteArray): TripDescriptorResult {
        var offset = 0
        var routeId = ""
        var tripId = ""
        var directionId: Int? = null

        while (offset < data.size) {
            val (fieldNumber, wireType, afterTag) = readTag(data, offset)
            offset = afterTag

            when (fieldNumber) {
                1 -> { // trip_id
                    if (wireType == WireType.LENGTH_DELIMITED) {
                        val (bytes, after) = readBytes(data, offset)
                        offset = after
                        tripId = String(bytes, Charsets.UTF_8)
                    } else {
                        offset = skip(data, offset, wireType)
                    }
                }
                5 -> { // route_id
                    if (wireType == WireType.LENGTH_DELIMITED) {
                        val (bytes, after) = readBytes(data, offset)
                        offset = after
                        routeId = String(bytes, Charsets.UTF_8)
                    } else {
                        offset = skip(data, offset, wireType)
                    }
                }
                9 -> { // direction_id (uint32)
                    if (wireType == WireType.VARINT) {
                        val (value, after) = readVarint(data, offset)
                        offset = after
                        directionId = value.toInt()
                    } else {
                        offset = skip(data, offset, wireType)
                    }
                }
                else -> offset = skip(data, offset, wireType)
            }
        }

        return TripDescriptorResult(routeId, tripId, directionId)
    }

    private fun parseStopTimeUpdate(data: ByteArray): GTFSStopTimeUpdate? {
        var offset = 0
        var stopId = ""
        var arrivalTime: Instant? = null
        var departureTime: Instant? = null

        while (offset < data.size) {
            val (fieldNumber, wireType, afterTag) = readTag(data, offset)
            offset = afterTag

            when (fieldNumber) {
                2 -> { // arrival (StopTimeEvent)
                    if (wireType == WireType.LENGTH_DELIMITED) {
                        val (steData, after) = readBytes(data, offset)
                        offset = after
                        arrivalTime = parseStopTimeEvent(steData)
                    } else {
                        offset = skip(data, offset, wireType)
                    }
                }
                3 -> { // departure (StopTimeEvent)
                    if (wireType == WireType.LENGTH_DELIMITED) {
                        val (steData, after) = readBytes(data, offset)
                        offset = after
                        departureTime = parseStopTimeEvent(steData)
                    } else {
                        offset = skip(data, offset, wireType)
                    }
                }
                4 -> { // stop_id (string)
                    if (wireType == WireType.LENGTH_DELIMITED) {
                        val (bytes, after) = readBytes(data, offset)
                        offset = after
                        stopId = String(bytes, Charsets.UTF_8)
                    } else {
                        offset = skip(data, offset, wireType)
                    }
                }
                else -> offset = skip(data, offset, wireType)
            }
        }

        if (stopId.isEmpty()) return null
        return GTFSStopTimeUpdate(stopId, arrivalTime, departureTime)
    }

    private fun parseStopTimeEvent(data: ByteArray): Instant? {
        var offset = 0
        var timestamp: Long? = null

        while (offset < data.size) {
            val (fieldNumber, wireType, afterTag) = readTag(data, offset)
            offset = afterTag

            // StopTimeEvent.time is field 2 (int64 encoded as varint).
            if (fieldNumber == 2 && wireType == WireType.VARINT) {
                val (value, after) = readVarint(data, offset)
                offset = after
                timestamp = value.toLong()
            } else {
                offset = skip(data, offset, wireType)
            }
        }

        return timestamp?.let { Instant.ofEpochSecond(it) }
    }

    // MARK: - Protobuf Wire Primitives

    private data class TagResult(val fieldNumber: Int, val wireType: WireType, val offset: Int)

    private fun readTag(data: ByteArray, offset: Int): TagResult {
        val (raw, after) = readVarint(data, offset)
        val fieldNumber = (raw shr 3).toInt()
        if (fieldNumber <= 0) throw ParseError.InvalidData
        val wireType = WireType.fromInt((raw and 0x07UL).toInt()) ?: throw ParseError.InvalidData
        return TagResult(fieldNumber, wireType, after)
    }

    private data class VarintResult(val value: ULong, val offset: Int)

    private fun readVarint(data: ByteArray, start: Int): VarintResult {
        var result = 0UL
        var shift = 0
        var offset = start

        while (offset < data.size) {
            val byte = data[offset].toInt() and 0xFF
            offset++
            result = result or ((byte and 0x7F).toULong() shl shift)
            if (byte and 0x80 == 0) {
                return VarintResult(result, offset)
            }
            shift += 7
            if (shift >= 64) throw ParseError.InvalidData
        }
        throw ParseError.TruncatedMessage
    }

    private data class BytesResult(val data: ByteArray, val offset: Int)

    private fun readBytes(data: ByteArray, offset: Int): BytesResult {
        val (length, afterLength) = readVarint(data, offset)
        val end = afterLength + length.toInt()
        if (end > data.size) throw ParseError.TruncatedMessage
        return BytesResult(data.copyOfRange(afterLength, end), end)
    }

    private fun skip(data: ByteArray, offset: Int, wireType: WireType): Int {
        return when (wireType) {
            WireType.VARINT -> readVarint(data, offset).offset
            WireType.FIXED64 -> {
                if (offset + 8 > data.size) throw ParseError.TruncatedMessage
                offset + 8
            }
            WireType.LENGTH_DELIMITED -> readBytes(data, offset).offset
            WireType.FIXED32 -> {
                if (offset + 4 > data.size) throw ParseError.TruncatedMessage
                offset + 4
            }
        }
    }
}
