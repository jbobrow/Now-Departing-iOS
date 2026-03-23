//
//  GTFSRTParser.swift
//  Now Departing
//
//  A minimal binary Protocol Buffers decoder for GTFS-RT feeds.
//
//  Rather than pulling in a full protobuf library (which would add build
//  complexity and a third-party dependency), this parser decodes only the
//  subset of the GTFS-RT schema that the app actually uses:
//
//    FeedMessage
//      └─ entity[]          (FeedEntity, field 2)
//           └─ trip_update  (TripUpdate, field 4)
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
//  All other fields are skipped safely; the decoder is forward-compatible
//  with future additions to the GTFS-RT spec.
//
//  Proto reference: https://github.com/google/transit/blob/master/gtfs-realtime/proto/gtfs-realtime.proto
//

import Foundation

// MARK: - Output Types

/// A parsed GTFS-RT Alert message.
struct GTFSAlert {
    /// Route IDs this alert applies to (from informed_entity[].route_id).
    let routeIds: [String]
    /// Short summary of the alert (TranslatedString, field 10).
    let headerText: String
    /// Detailed description of the alert (TranslatedString, field 11).
    let descriptionText: String
    /// Raw GTFS-RT Effect enum value (field 7). See ServiceAlert.AlertEffect for values.
    let effect: Int
    /// Time windows during which this alert is active (field 1, repeated TimeRange).
    /// Empty means the alert is always active.
    let activePeriods: [(start: Date?, end: Date?)]
}

/// A parsed GTFS-RT TripUpdate message.
struct GTFSTripUpdate {
    let routeId: String
    let tripId: String
    /// GTFS direction_id: 0 = one direction, 1 = the other.
    /// MTA convention: 1 = southbound / outbound, 0 = northbound / inbound
    /// (varies slightly by line — use the stop_id suffix "N"/"S" as the
    /// authoritative direction indicator).
    let directionId: Int?
    let stopTimeUpdates: [GTFSStopTimeUpdate]
}

/// A parsed StopTimeUpdate within a TripUpdate.
struct GTFSStopTimeUpdate {
    /// GTFS stop_id, e.g. "127N" for northbound Times Square on the 1/2/3 platforms.
    let stopId: String
    /// Predicted arrival time, if provided.
    let arrivalTime: Date?
    /// Predicted departure time, if provided.
    let departureTime: Date?
}

// MARK: - Parser

/// Decodes a raw GTFS-RT binary protobuf byte buffer into an array of
/// `GTFSTripUpdate` values.  Vehicle positions and service alerts are ignored.
final class GTFSRTParser {

    // MARK: - Public API

    enum ParseError: Error {
        case invalidData
        case truncatedMessage
    }

    // MARK: - Alert Parsing

    /// Parses the binary GTFS-RT Alerts feed and returns an array of `GTFSAlert` values.
    /// Skips entities that do not contain an alert (e.g. trip_update entities).
    func parseAlerts(_ data: Data) throws -> [GTFSAlert] {
        var alerts: [GTFSAlert] = []
        var offset = 0

        while offset < data.count {
            let (fieldNumber, wireType, afterTag) = try readTag(data, at: offset)
            offset = afterTag

            if fieldNumber == 2, wireType == .lengthDelimited {
                let (entityData, afterEntity) = try readBytes(data, at: offset)
                offset = afterEntity
                if let alert = try parseFeedEntityForAlert(entityData) {
                    alerts.append(alert)
                }
            } else {
                offset = try skip(data, at: offset, wireType: wireType)
            }
        }

        return alerts
    }

    private func parseFeedEntityForAlert(_ data: Data) throws -> GTFSAlert? {
        var offset = 0

        while offset < data.count {
            let (fieldNumber, wireType, afterTag) = try readTag(data, at: offset)
            offset = afterTag

            // FeedEntity.alert is field 5.
            if fieldNumber == 5, wireType == .lengthDelimited {
                let (alertData, afterAlert) = try readBytes(data, at: offset)
                offset = afterAlert
                return try parseAlert(alertData)
            } else {
                offset = try skip(data, at: offset, wireType: wireType)
            }
        }

        return nil
    }

    private func parseAlert(_ data: Data) throws -> GTFSAlert {
        var offset = 0
        var routeIds: [String] = []
        var headerText = ""
        var descriptionText = ""
        var effect = 0
        var activePeriods: [(start: Date?, end: Date?)] = []

        while offset < data.count {
            let (fieldNumber, wireType, afterTag) = try readTag(data, at: offset)
            offset = afterTag

            switch fieldNumber {
            case 1: // active_period (repeated TimeRange)
                if wireType == .lengthDelimited {
                    let (trData, after) = try readBytes(data, at: offset)
                    offset = after
                    activePeriods.append(try parseTimeRange(trData))
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }

            case 5: // informed_entity (repeated EntitySelector)
                if wireType == .lengthDelimited {
                    let (selectorData, after) = try readBytes(data, at: offset)
                    offset = after
                    if let routeId = try parseEntitySelectorRouteId(selectorData) {
                        routeIds.append(routeId)
                    }
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }

            case 7: // effect (uint32 varint)
                if wireType == .varint {
                    let (value, after) = try readVarint(data, at: offset)
                    offset = after
                    effect = Int(value)
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }

            case 10: // header_text (TranslatedString)
                if wireType == .lengthDelimited {
                    let (tsData, after) = try readBytes(data, at: offset)
                    offset = after
                    headerText = try parseTranslatedString(tsData)
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }

            case 11: // description_text (TranslatedString)
                if wireType == .lengthDelimited {
                    let (tsData, after) = try readBytes(data, at: offset)
                    offset = after
                    descriptionText = try parseTranslatedString(tsData)
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }

            default:
                offset = try skip(data, at: offset, wireType: wireType)
            }
        }

        return GTFSAlert(
            routeIds: routeIds,
            headerText: headerText,
            descriptionText: descriptionText,
            effect: effect,
            activePeriods: activePeriods
        )
    }

    /// Parses a GTFS-RT TimeRange message (start=field1, end=field2, both uint64 Unix timestamps).
    private func parseTimeRange(_ data: Data) throws -> (start: Date?, end: Date?) {
        var offset = 0
        var start: Date?
        var end: Date?

        while offset < data.count {
            let (fieldNumber, wireType, afterTag) = try readTag(data, at: offset)
            offset = afterTag

            switch fieldNumber {
            case 1: // start (uint64)
                if wireType == .varint {
                    let (value, after) = try readVarint(data, at: offset)
                    offset = after
                    start = Date(timeIntervalSince1970: TimeInterval(value))
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }
            case 2: // end (uint64)
                if wireType == .varint {
                    let (value, after) = try readVarint(data, at: offset)
                    offset = after
                    end = Date(timeIntervalSince1970: TimeInterval(value))
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }
            default:
                offset = try skip(data, at: offset, wireType: wireType)
            }
        }

        return (start, end)
    }

    /// Reads the route_id (field 5) from an EntitySelector message.
    private func parseEntitySelectorRouteId(_ data: Data) throws -> String? {
        var offset = 0
        var routeId: String?

        while offset < data.count {
            let (fieldNumber, wireType, afterTag) = try readTag(data, at: offset)
            offset = afterTag

            if fieldNumber == 2, wireType == .lengthDelimited { // route_id
                let (bytes, after) = try readBytes(data, at: offset)
                offset = after
                routeId = String(data: bytes, encoding: .utf8)
            } else {
                offset = try skip(data, at: offset, wireType: wireType)
            }
        }

        return routeId
    }

    /// Reads the English (or first available) text from a TranslatedString message.
    private func parseTranslatedString(_ data: Data) throws -> String {
        var offset = 0
        var englishText = ""
        var firstText = ""

        while offset < data.count {
            let (fieldNumber, wireType, afterTag) = try readTag(data, at: offset)
            offset = afterTag

            if fieldNumber == 1, wireType == .lengthDelimited { // translation (repeated)
                let (translationData, after) = try readBytes(data, at: offset)
                offset = after
                let (text, language) = try parseTranslation(translationData)
                if firstText.isEmpty { firstText = text }
                if language == "en" || language.isEmpty { englishText = text }
            } else {
                offset = try skip(data, at: offset, wireType: wireType)
            }
        }

        return englishText.isEmpty ? firstText : englishText
    }

    /// Reads (text, language) from a Translation message.
    private func parseTranslation(_ data: Data) throws -> (text: String, language: String) {
        var offset = 0
        var text = ""
        var language = ""

        while offset < data.count {
            let (fieldNumber, wireType, afterTag) = try readTag(data, at: offset)
            offset = afterTag

            switch fieldNumber {
            case 1: // text
                if wireType == .lengthDelimited {
                    let (bytes, after) = try readBytes(data, at: offset)
                    offset = after
                    text = String(data: bytes, encoding: .utf8) ?? ""
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }
            case 2: // language
                if wireType == .lengthDelimited {
                    let (bytes, after) = try readBytes(data, at: offset)
                    offset = after
                    language = String(data: bytes, encoding: .utf8) ?? ""
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }
            default:
                offset = try skip(data, at: offset, wireType: wireType)
            }
        }

        return (text, language)
    }

    // MARK: - Trip Update Parsing

    func parse(_ data: Data) throws -> [GTFSTripUpdate] {
        var updates: [GTFSTripUpdate] = []
        var offset = 0

        while offset < data.count {
            let (fieldNumber, wireType, afterTag) = try readTag(data, at: offset)
            offset = afterTag

            // FeedMessage.entity is field 2, wire-type length-delimited.
            if fieldNumber == 2, wireType == .lengthDelimited {
                let (entityData, afterEntity) = try readBytes(data, at: offset)
                offset = afterEntity
                if let update = try parseFeedEntity(entityData) {
                    updates.append(update)
                }
            } else {
                offset = try skip(data, at: offset, wireType: wireType)
            }
        }

        return updates
    }

    // MARK: - Message Parsers

    private func parseFeedEntity(_ data: Data) throws -> GTFSTripUpdate? {
        var offset = 0
        var result: GTFSTripUpdate?

        while offset < data.count {
            let (fieldNumber, wireType, afterTag) = try readTag(data, at: offset)
            offset = afterTag

            // FeedEntity.trip_update is field 3.
            if fieldNumber == 3, wireType == .lengthDelimited {
                let (tuData, afterTU) = try readBytes(data, at: offset)
                offset = afterTU
                result = try parseTripUpdate(tuData)
            } else {
                offset = try skip(data, at: offset, wireType: wireType)
            }
        }

        return result
    }

    private func parseTripUpdate(_ data: Data) throws -> GTFSTripUpdate? {
        var offset = 0
        var routeId = ""
        var tripId = ""
        var directionId: Int?
        var stopTimeUpdates: [GTFSStopTimeUpdate] = []

        while offset < data.count {
            let (fieldNumber, wireType, afterTag) = try readTag(data, at: offset)
            offset = afterTag

            switch fieldNumber {
            case 1: // TripUpdate.trip (TripDescriptor)
                if wireType == .lengthDelimited {
                    let (tdData, afterTD) = try readBytes(data, at: offset)
                    offset = afterTD
                    (routeId, tripId, directionId) = try parseTripDescriptor(tdData)
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }

            case 2: // TripUpdate.stop_time_update (repeated)
                if wireType == .lengthDelimited {
                    let (stuData, afterSTU) = try readBytes(data, at: offset)
                    offset = afterSTU
                    if let stu = try parseStopTimeUpdate(stuData) {
                        stopTimeUpdates.append(stu)
                    }
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }

            default:
                offset = try skip(data, at: offset, wireType: wireType)
            }
        }

        guard !routeId.isEmpty else { return nil }
        return GTFSTripUpdate(
            routeId: routeId,
            tripId: tripId,
            directionId: directionId,
            stopTimeUpdates: stopTimeUpdates
        )
    }

    private func parseTripDescriptor(_ data: Data) throws -> (routeId: String, tripId: String, directionId: Int?) {
        var offset = 0
        var routeId = ""
        var tripId = ""
        var directionId: Int?

        while offset < data.count {
            let (fieldNumber, wireType, afterTag) = try readTag(data, at: offset)
            offset = afterTag

            switch fieldNumber {
            case 1: // trip_id
                if wireType == .lengthDelimited {
                    let (bytes, after) = try readBytes(data, at: offset)
                    offset = after
                    tripId = String(data: bytes, encoding: .utf8) ?? ""
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }

            case 5: // route_id
                if wireType == .lengthDelimited {
                    let (bytes, after) = try readBytes(data, at: offset)
                    offset = after
                    routeId = String(data: bytes, encoding: .utf8) ?? ""
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }

            case 9: // direction_id (uint32)
                if wireType == .varint {
                    let (value, after) = try readVarint(data, at: offset)
                    offset = after
                    directionId = Int(value)
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }

            default:
                offset = try skip(data, at: offset, wireType: wireType)
            }
        }

        return (routeId, tripId, directionId)
    }

    private func parseStopTimeUpdate(_ data: Data) throws -> GTFSStopTimeUpdate? {
        var offset = 0
        var stopId = ""
        var arrivalTime: Date?
        var departureTime: Date?

        while offset < data.count {
            let (fieldNumber, wireType, afterTag) = try readTag(data, at: offset)
            offset = afterTag

            switch fieldNumber {
            case 2: // arrival (StopTimeEvent)
                if wireType == .lengthDelimited {
                    let (steData, after) = try readBytes(data, at: offset)
                    offset = after
                    arrivalTime = try parseStopTimeEvent(steData)
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }

            case 3: // departure (StopTimeEvent)
                if wireType == .lengthDelimited {
                    let (steData, after) = try readBytes(data, at: offset)
                    offset = after
                    departureTime = try parseStopTimeEvent(steData)
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }

            case 4: // stop_id (string)
                if wireType == .lengthDelimited {
                    let (bytes, after) = try readBytes(data, at: offset)
                    offset = after
                    stopId = String(data: bytes, encoding: .utf8) ?? ""
                } else {
                    offset = try skip(data, at: offset, wireType: wireType)
                }

            default:
                offset = try skip(data, at: offset, wireType: wireType)
            }
        }

        guard !stopId.isEmpty else { return nil }
        return GTFSStopTimeUpdate(stopId: stopId, arrivalTime: arrivalTime, departureTime: departureTime)
    }

    /// Parses a StopTimeEvent and returns the predicted time as a Date (using
    /// the `time` field, which is a Unix timestamp in seconds).
    private func parseStopTimeEvent(_ data: Data) throws -> Date? {
        var offset = 0
        var timestamp: Int64?

        while offset < data.count {
            let (fieldNumber, wireType, afterTag) = try readTag(data, at: offset)
            offset = afterTag

            // StopTimeEvent.time is field 2 (int64 encoded as varint).
            if fieldNumber == 2, wireType == .varint {
                let (value, after) = try readVarint(data, at: offset)
                offset = after
                timestamp = Int64(bitPattern: value)
            } else {
                offset = try skip(data, at: offset, wireType: wireType)
            }
        }

        guard let ts = timestamp else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(ts))
    }

    // MARK: - Protobuf Wire Primitives

    private enum WireType: UInt64 {
        case varint          = 0
        case fixed64Bit      = 1
        case lengthDelimited = 2
        case fixed32Bit      = 5
        // Wire types 3 (SGROUP) and 4 (EGROUP) are deprecated and not used in GTFS-RT.
    }

    /// Reads the next field tag, returning (fieldNumber, wireType, offsetAfterTag).
    private func readTag(_ data: Data, at offset: Int) throws -> (Int, WireType, Int) {
        let (raw, after) = try readVarint(data, at: offset)
        let fieldNumber = Int(raw >> 3)
        guard fieldNumber > 0 else { throw ParseError.invalidData }
        guard let wireType = WireType(rawValue: raw & 0x07) else {
            throw ParseError.invalidData
        }
        return (fieldNumber, wireType, after)
    }

    /// Reads a base-128 varint (LEB128), returning (value, offsetAfterVarint).
    private func readVarint(_ data: Data, at start: Int) throws -> (UInt64, Int) {
        var result: UInt64 = 0
        var shift = 0
        var offset = start

        while offset < data.count {
            let byte = data[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return (result, offset)
            }
            shift += 7
            if shift >= 64 { throw ParseError.invalidData }
        }
        throw ParseError.truncatedMessage
    }

    /// Reads a length-delimited field, returning (fieldBytes, offsetAfterField).
    private func readBytes(_ data: Data, at offset: Int) throws -> (Data, Int) {
        let (length, afterLength) = try readVarint(data, at: offset)
        let end = afterLength + Int(length)
        guard end <= data.count else { throw ParseError.truncatedMessage }
        // Copy the slice so its indices always start at 0, avoiding Data slice
        // index pitfalls where subscript uses absolute offsets from the original buffer.
        return (Data(data[afterLength..<end]), end)
    }

    /// Skips a field whose content we do not need.
    private func skip(_ data: Data, at offset: Int, wireType: WireType) throws -> Int {
        switch wireType {
        case .varint:
            let (_, after) = try readVarint(data, at: offset)
            return after
        case .fixed64Bit:
            guard offset + 8 <= data.count else { throw ParseError.truncatedMessage }
            return offset + 8
        case .lengthDelimited:
            let (_, after) = try readBytes(data, at: offset)
            return after
        case .fixed32Bit:
            guard offset + 4 <= data.count else { throw ParseError.truncatedMessage }
            return offset + 4
        }
    }
}
