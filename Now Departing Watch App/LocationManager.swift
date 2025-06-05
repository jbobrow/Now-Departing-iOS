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
    
    private let locationManager = CLLocationManager()
    private var locationTimeout: Timer?
    private var updateTimer: Timer?
    private var isActivelyTracking = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        // Use more appropriate settings for Apple Watch
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100 // Update location when user moves 100 meters
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
        
        // Set a timeout for location acquisition - more generous timeout
        locationTimeout?.invalidate()
        locationTimeout = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: false) { [weak self] _ in
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
        
        // Reset timeout for each update attempt
        locationTimeout?.invalidate()
        locationTimeout = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
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
        // For periodic timeouts, don't show error if we have an existing location
        if location == nil {
            locationError = "Unable to update your location. Please try again."
            isSearchingForLocation = false
        }
        // If we have an existing location, just silently continue
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
        
        // Set timeout for one-time update
        locationTimeout?.invalidate()
        locationTimeout = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            self?.handleLocationTimeout()
        }
        
        locationManager.requestLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // Filter out old or inaccurate locations
        let age = abs(newLocation.timestamp.timeIntervalSinceNow)
        if age > 30 || newLocation.horizontalAccuracy > 1000 || newLocation.horizontalAccuracy < 0 {
            print("DEBUG: Filtering out location - age: \(age), accuracy: \(newLocation.horizontalAccuracy)")
            return
        }
        
        print("DEBUG: Location updated: \(newLocation.coordinate.latitude), \(newLocation.coordinate.longitude), accuracy: \(newLocation.horizontalAccuracy)")
        
        location = newLocation
        isSearchingForLocation = false
        locationError = nil
        locationTimeout?.invalidate()
        
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
                locationError = "Unable to find your location. Make sure you're outdoors or near a window."
            case .denied:
                locationError = "Location access denied. Please enable location services in Settings."
            case .network:
                locationError = "Network error. Please check your internet connection."
            case .headingFailure:
                locationError = "Unable to determine your heading."
            case .regionMonitoringDenied, .regionMonitoringFailure:
                locationError = "Region monitoring not available."
            case .regionMonitoringSetupDelayed:
                locationError = "Location setup delayed. Please try again."
            default:
                locationError = "Location error: \(error.localizedDescription)"
            }
        } else {
            locationError = "Unable to determine your location. Please try again."
        }
        
        // If we're actively tracking and get an error, try again after a delay
        if isActivelyTracking && location == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
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
            if isActivelyTracking {
                startLocationUpdates()
            }
        } else {
            stopLocationUpdates()
            if authorizationStatus == .denied {
                locationError = "Location access denied. Please enable location services in Settings."
            }
        }
    }
}
