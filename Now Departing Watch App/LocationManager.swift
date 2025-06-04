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
            return
        }
        
        isSearchingForLocation = true
        locationError = nil
        
        // Try requesting a one-time location first (more reliable on Watch)
        locationManager.requestLocation()
        
        // Set a timeout for location acquisition
        locationTimeout?.invalidate()
        locationTimeout = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            self?.handleLocationTimeout()
        }
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        locationTimeout?.invalidate()
        isSearchingForLocation = false
    }
    
    private func handleLocationTimeout() {
        if location == nil {
            locationError = "Unable to find your location. Please ensure location services are enabled and try again."
            isSearchingForLocation = false
        }
    }
    
    func retryLocation() {
        guard isLocationEnabled else { return }
        
        locationError = nil
        startLocationUpdates()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        
        // Filter out old or inaccurate locations
        let age = abs(newLocation.timestamp.timeIntervalSinceNow)
        if age > 30 || newLocation.horizontalAccuracy > 1000 || newLocation.horizontalAccuracy < 0 {
            return
        }
        
        location = newLocation
        isSearchingForLocation = false
        locationError = nil
        locationTimeout?.invalidate()
        
        // Stop continuous updates after getting a good location
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        
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
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        isLocationEnabled = (authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways)
        
        if isLocationEnabled {
            startLocationUpdates()
        } else {
            stopLocationUpdates()
            if authorizationStatus == .denied {
                locationError = "Location access denied. Please enable location services in Settings."
            }
        }
    }
}
