//
//  ComplicationController.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 1/31/25.
//

import ClockKit

class ComplicationController: NSObject, CLKComplicationDataSource {
    // Storage keys
    private let lastStationKey = "lastViewedStation"
    private let lastLineKey = "lastViewedLine"
    private let lastDirectionKey = "lastViewedDirection"
    
    private func getNextTrainInfo() -> String {
        let defaults = UserDefaults.standard
        guard let stationName = defaults.string(forKey: lastStationKey),
              let lineId = defaults.string(forKey: lastLineKey),
              let direction = defaults.string(forKey: lastDirectionKey) else {
            return "--"
        }
        
        if let nextTrainTime = defaults.array(forKey: "nextTrains_\(stationName)_\(lineId)_\(direction)") as? [Int],
           let nextTrain = nextTrainTime.first {
            return nextTrain == 0 ? "Now" : "\(nextTrain)m"
        }
        
        return "--"
    }
    
    private func createTemplate(for complication: CLKComplication) -> CLKComplicationTemplate? {
        let nextTrain = getNextTrainInfo()
        
        switch complication.family {
        case .modularSmall:
            guard let image = UIImage(systemName: "tram.fill")?.withTintColor(.white, renderingMode: .alwaysTemplate) else { return nil }
            let imageProvider = CLKImageProvider(onePieceImage: image)
            let textProvider = CLKSimpleTextProvider(text: nextTrain)
            return CLKComplicationTemplateModularSmallStackImage(line1ImageProvider: imageProvider,
                                                               line2TextProvider: textProvider)
            
        case .graphicCircular:
            if #available(watchOSApplicationExtension 7.0, *) {
                guard let image = UIImage(systemName: "tram.fill")?.withTintColor(.white, renderingMode: .alwaysTemplate) else { return nil }
                let imageProvider = CLKFullColorImageProvider(fullColorImage: image)
                let textProvider = CLKSimpleTextProvider(text: nextTrain)
                return CLKComplicationTemplateGraphicCircularStackImage(line1ImageProvider: imageProvider,
                                                                      line2TextProvider: textProvider)
            }
            return nil
            
        case .graphicCorner:
            if #available(watchOSApplicationExtension 7.0, *) {
                let innerTextProvider = CLKSimpleTextProvider(text: "Next")
                let outerTextProvider = CLKSimpleTextProvider(text: nextTrain)
                return CLKComplicationTemplateGraphicCornerStackText(innerTextProvider: innerTextProvider,
                                                                   outerTextProvider: outerTextProvider)
            }
            return nil
            
        case .graphicBezel:
            if #available(watchOSApplicationExtension 7.0, *) {
                guard let image = UIImage(systemName: "tram.fill")?.withTintColor(.white, renderingMode: .alwaysTemplate) else { return nil }
                let imageProvider = CLKFullColorImageProvider(fullColorImage: image)
                let circularTextProvider = CLKSimpleTextProvider(text: nextTrain)
                
                let circularTemplate = CLKComplicationTemplateGraphicCircularStackImage(
                    line1ImageProvider: imageProvider,
                    line2TextProvider: circularTextProvider
                )
                
                let textProvider = CLKSimpleTextProvider(text: "Next train")
                return CLKComplicationTemplateGraphicBezelCircularText(circularTemplate: circularTemplate,
                                                                     textProvider: textProvider)
            }
            return nil
            
        default:
            return nil
        }
    }
    
    func getCurrentTimelineEntry(for complication: CLKComplication,
                               withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        guard let template = createTemplate(for: complication) else {
            handler(nil)
            return
        }
        
        let entry = CLKComplicationTimelineEntry(
            date: Date(),
            complicationTemplate: template
        )
        
        handler(entry)
    }
    
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "com.yourdomain.nowdeparting.basic",
                displayName: "Now Departing",
                supportedFamilies: [
                    .modularSmall,
                    .graphicCircular,
                    .graphicCorner,
                    .graphicBezel
                ]
            )
        ]
        
        handler(descriptors)
    }
    
    func getTimelineEndDate(for complication: CLKComplication,
                           withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }
    
    func getPrivacyBehavior(for complication: CLKComplication,
                           withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }
}
