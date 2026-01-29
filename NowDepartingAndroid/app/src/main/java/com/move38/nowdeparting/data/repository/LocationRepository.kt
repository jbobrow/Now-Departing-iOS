package com.move38.nowdeparting.data.repository

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.*
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

@Singleton
class LocationRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    companion object {
        private const val TAG = "LocationRepository"
        private const val UPDATE_INTERVAL = 30_000L // 30 seconds
        private const val FASTEST_UPDATE_INTERVAL = 15_000L // 15 seconds
    }

    private val fusedLocationClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(context)

    fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED ||
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    @SuppressLint("MissingPermission")
    suspend fun getCurrentLocation(): Location? {
        if (!hasLocationPermission()) {
            Log.w(TAG, "Location permission not granted")
            return null
        }

        return suspendCancellableCoroutine { continuation ->
            fusedLocationClient.lastLocation
                .addOnSuccessListener { location ->
                    if (location != null) {
                        continuation.resume(location)
                    } else {
                        // Request a fresh location
                        val locationRequest = LocationRequest.Builder(
                            Priority.PRIORITY_HIGH_ACCURACY,
                            UPDATE_INTERVAL
                        ).setMaxUpdates(1).build()

                        val callback = object : LocationCallback() {
                            override fun onLocationResult(result: LocationResult) {
                                fusedLocationClient.removeLocationUpdates(this)
                                continuation.resume(result.lastLocation)
                            }
                        }

                        fusedLocationClient.requestLocationUpdates(
                            locationRequest,
                            callback,
                            Looper.getMainLooper()
                        )

                        continuation.invokeOnCancellation {
                            fusedLocationClient.removeLocationUpdates(callback)
                        }
                    }
                }
                .addOnFailureListener { exception ->
                    Log.e(TAG, "Error getting location", exception)
                    continuation.resume(null)
                }
        }
    }

    @SuppressLint("MissingPermission")
    fun getLocationUpdates(): Flow<Location> = callbackFlow {
        if (!hasLocationPermission()) {
            close()
            return@callbackFlow
        }

        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            UPDATE_INTERVAL
        ).setMinUpdateIntervalMillis(FASTEST_UPDATE_INTERVAL).build()

        val callback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let { location ->
                    trySend(location)
                }
            }
        }

        fusedLocationClient.requestLocationUpdates(
            locationRequest,
            callback,
            Looper.getMainLooper()
        )

        awaitClose {
            fusedLocationClient.removeLocationUpdates(callback)
        }
    }
}
