//
//  LocationManager.swift
//  Now Departing
//
//  Created by Jonathan Bobrow on 6/4/25.
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled: Bool = false
    @Published var locationError: String?
    @Published var isSearchingForLocation: Bool = false
    
    // NEW: iOS-specific user preference tracking
    @Published private var _hasUserEnabledLocation: Bool = false
    
    var hasUserEnabledLocation: Bool {
        get {
            #if os(iOS)
            return UserDefaults.standard.bool(forKey: "hasUserEnabledLocation_iOS")
            #else
            return true // watchOS always assumes enabled for simplicity
            #endif
        }
        set {
            #if os(iOS)
            UserDefaults.standard.set(newValue, forKey: "hasUserEnabledLocation_iOS")
            _hasUserEnabledLocation = newValue // Trigger @Published updates
            #endif
        }
    }
    
    private let locationManager = CLLocationManager()
    private var locationTimeout: Timer?
    private var updateTimer: Timer?
    private var isActivelyTracking = false
    
    // NEW: Cached location for instant loading on iOS
    private var cachedLocation: CLLocation? {
        get {
            #if os(iOS)
            guard let data = UserDefaults.standard.data(forKey: "cachedLocation_iOS"),
                  let location = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? CLLocation else {
                return nil
            }
            // Only use cached location if it's less than 1 hour old
            return Date().timeIntervalSince(location.timestamp) < 3600 ? location : nil
            #else
            return nil // watchOS doesn't use cached locations
            #endif
        }
        set {
            #if os(iOS)
            if let location = newValue {
                let data = try? NSKeyedArchiver.archivedData(withRootObject: location, requiringSecureCoding: true)
                UserDefaults.standard.set(data, forKey: "cachedLocation_iOS")
            } else {
                UserDefaults.standard.removeObject(forKey: "cachedLocation_iOS")
            }
            #endif
        }
    }
    
    override init() {
        super.init()
        locationManager.delegate = self
        // Better settings for mobile use (biking, walking, etc.)
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters // More precise for movement
        locationManager.distanceFilter = 50 // Update more frequently when moving (50m instead of 100m)
        
        authorizationStatus = locationManager.authorizationStatus
        isLocationEnabled = (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways)
        
        // Initialize the preference tracking
        #if os(iOS)
        _hasUserEnabledLocation = UserDefaults.standard.bool(forKey: "hasUserEnabledLocation_iOS")
        #endif
        
        // NEW: Load cached location immediately on iOS if user previously enabled
        #if os(iOS)
        if hasUserEnabledLocation && isLocationEnabled {
            location = cachedLocation
            if let cached = cachedLocation {
                print("DEBUG: Loaded cached location immediately: \(cached)")
            }
        }
        #endif
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        print("DEBUG: Starting location updates")
        
        // Clear any existing error state
        locationError = nil
        
        // NEW: On iOS, if we have cached location, use it immediately
        #if os(iOS)
        if let cached = cachedLocation {
            location = cached
            print("DEBUG: Using cached location for instant results")
        }
        #endif
        
        // Only show searching if we don't have a recent location
        if location == nil || abs(location!.timestamp.timeIntervalSinceNow) > 300 { // 5 minutes old
            isSearchingForLocation = true
        }
        
        isActivelyTracking = true
        
        // Stop any existing updates first
        locationManager.stopUpdatingLocation()
        
        // Start continuous location updates
        locationManager.startUpdatingLocation()
        
        // Set up timer to request updates every 30 seconds when actively viewing
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.requestPeriodicUpdate()
        }
        
        // More generous timeout for mobile scenarios - 30 seconds instead of 20
        locationTimeout?.invalidate()
        locationTimeout = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            self?.handleLocationTimeout()
        }
    }
    
    func stopLocationUpdates() {
        print("DEBUG: Stopping location updates")
        isActivelyTracking = false
        isSearchingForLocation = false
        locationManager.stopUpdatingLocation()
        locationTimeout?.invalidate()
        updateTimer?.invalidate()
        locationTimeout = nil
        updateTimer = nil
    }
    
    private func requestPeriodicUpdate() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        
        guard isActivelyTracking else {
            return
        }
        
        print("DEBUG: Requesting periodic location update")
        
        // Reset timeout for each update attempt - more generous for mobile
        locationTimeout?.invalidate()
        locationTimeout = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: false) { [weak self] _ in
            self?.handlePeriodicTimeout()
        }
        
        // Use requestLocation for periodic updates to be more reliable
        locationManager.requestLocation()
    }
    
    private func handleLocationTimeout() {
        print("DEBUG: Location timeout - initial")
        if location == nil && isSearchingForLocation {
            locationError = "Unable to find your location. Please ensure location services are enabled and try again."
            isSearchingForLocation = false
        }
    }
    
    private func handlePeriodicTimeout() {
        print("DEBUG: Location timeout - periodic")
        // For periodic timeouts, be more lenient - don't show error if we have a reasonably recent location
        if location == nil || abs(location!.timestamp.timeIntervalSinceNow) > 600 { // Only error if no location or very old (10 minutes)
            locationError = "Unable to update your location. Please try again."
            isSearchingForLocation = false
        }
        // If we have a recent-ish location, just silently continue
    }
    
    func retryLocation() {
        print("DEBUG: Retrying location")
        guard isLocationEnabled else {
            requestLocationPermission()
            return
        }
        
        locationError = nil
        isSearchingForLocation = true
        
        if isActivelyTracking {
            startLocationUpdates()
        } else {
            requestOneTimeUpdate()
        }
    }
    
    func requestOneTimeUpdate() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        
        print("DEBUG: Requesting one-time location update")
        
        // If we don't have a location yet, show searching indicator
        if location == nil {
            isSearchingForLocation = true
        }
        
        // Set timeout for one-time update - more generous
        locationTimeout?.invalidate()
        locationTimeout = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: false) { [weak self] _ in
            self?.handleLocationTimeout()
        }
        
        locationManager.requestLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // More lenient filtering for mobile scenarios
        let age = abs(newLocation.timestamp.timeIntervalSinceNow)
        
        // Allow older locations when moving (up to 60 seconds) and be more lenient with accuracy
        if age > 60 || newLocation.horizontalAccuracy > 2000 || newLocation.horizontalAccuracy < 0 {
            print("DEBUG: Filtering out location - age: \(age), accuracy: \(newLocation.horizontalAccuracy)")
            return
        }
        
        // If we have an existing location, check if the new one is significantly better
        if let existingLocation = location {
            let existingAge = abs(existingLocation.timestamp.timeIntervalSinceNow)
            let newAge = age
            
            // Only update if:
            // 1. New location is significantly more recent (more than 30 seconds newer), OR
            // 2. New location is much more accurate (more than 50m better), OR
            // 3. Existing location is getting old (more than 2 minutes)
            let isSignificantlyNewer = existingAge - newAge > 30
            let isMuchMoreAccurate = existingLocation.horizontalAccuracy - newLocation.horizontalAccuracy > 50
            let existingIsOld = existingAge > 120
            
            if !isSignificantlyNewer && !isMuchMoreAccurate && !existingIsOld {
                print("DEBUG: Keeping existing location - not significant improvement")
                return
            }
        }
        
        print("DEBUG: Location updated: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude), accuracy: \(newLocation.horizontalAccuracy)")
        
        location = newLocation
        isSearchingForLocation = false
        locationError = nil
        locationTimeout?.invalidate()
        
        // NEW: Cache the location on iOS for next app launch
        #if os(iOS)
        cachedLocation = newLocation
        #endif
        
        // Don't stop continuous updates if we're actively tracking
        if !isActivelyTracking {
            locationManager.stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("DEBUG: Location error: \(error.localizedDescription)")
        
        // Always clear the searching state on error
        isSearchingForLocation = false
        locationTimeout?.invalidate()
        
        if let clError = error as? CLError {
            switch clError.code {
            case .locationUnknown:
                // Be more lenient with this error - don't show error if we have a recent location
                if location == nil || abs(location!.timestamp.timeIntervalSinceNow) > 300 {
                    locationError = "Unable to find your location. Make sure you're outdoors or near a window."
                }
            case .denied:
                locationError = "Location access denied. Please enable location services in Settings."
            case .network:
                locationError = "Network error. Please check your internet connection."
            case .headingFailure:
                // Don't show heading errors for this use case
                break
            case .regionMonitoringDenied, .regionMonitoringFailure:
                // Don't show region monitoring errors for this use case
                break
            case .regionMonitoringSetupDelayed:
                // Don't show setup delay errors for this use case
                break
            default:
                // Only show other errors if we don't have a recent location
                if location == nil || abs(location!.timestamp.timeIntervalSinceNow) > 300 {
                    locationError = "Location error: \(error.localizedDescription)"
                }
            }
        } else {
            // Only show generic errors if we don't have a recent location
            if location == nil || abs(location!.timestamp.timeIntervalSinceNow) > 300 {
                locationError = "Unable to determine your location. Please try again."
            }
        }
        
        // If we're actively tracking and get an error, try again after a delay - but only if we don't have any location
        if isActivelyTracking && (location == nil || abs(location!.timestamp.timeIntervalSinceNow) > 300) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in // Longer delay for retries
                guard let self = self, self.isActivelyTracking else { return }
                print("DEBUG: Retrying after error")
                self.requestPeriodicUpdate()
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        isLocationEnabled = (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways)
        
        print("DEBUG: Location authorization changed to: \(authorizationStatus.rawValue)")
        
        if isLocationEnabled {
            // NEW: On iOS, when permission is granted and user previously enabled, start immediately
            #if os(iOS)
            if hasUserEnabledLocation && isActivelyTracking {
                startLocationUpdates()
            } else if isActivelyTracking {
                startLocationUpdates()
            }
            #else
            if isActivelyTracking {
                startLocationUpdates()
            }
            #endif
        } else {
            stopLocationUpdates()
            if authorizationStatus == .denied {
                locationError = "Location access denied. Please enable location services in Settings."
            }
        }
    }
}
