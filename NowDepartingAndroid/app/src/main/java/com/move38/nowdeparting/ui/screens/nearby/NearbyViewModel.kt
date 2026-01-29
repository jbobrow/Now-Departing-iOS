package com.move38.nowdeparting.ui.screens.nearby

import android.location.Location
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.move38.nowdeparting.data.model.FavoriteItem
import com.move38.nowdeparting.data.model.NearbyTrain
import com.move38.nowdeparting.data.repository.FavoritesRepository
import com.move38.nowdeparting.data.repository.LocationRepository
import com.move38.nowdeparting.data.repository.SubwayRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import javax.inject.Inject

data class NearbyUiState(
    val isLoading: Boolean = false,
    val trains: List<NearbyTrain> = emptyList(),
    val trainsByStation: Map<String, List<NearbyTrain>> = emptyMap(),
    val groupedTrains: List<StationGroup> = emptyList(), // New grouped format
    val error: String? = null,
    val hasLocationPermission: Boolean = false,
    val currentLocation: Location? = null,
    val favorites: Set<String> = emptySet() // Set of "lineId|stationName|direction"
)

// Group of trains for a single line/direction at a station
data class LineDirectionGroup(
    val lineId: String,
    val direction: String,
    val generalDirection: String,
    val destination: String,
    val trains: List<NearbyTrain> // Sorted by arrival time
)

// Group of all line/direction groups for a station
data class StationGroup(
    val stationName: String,
    val stationDisplay: String,
    val distanceText: String,
    val distanceInMeters: Double,
    val lineDirectionGroups: List<LineDirectionGroup>
)

@HiltViewModel
class NearbyViewModel @Inject constructor(
    private val subwayRepository: SubwayRepository,
    private val locationRepository: LocationRepository,
    private val favoritesRepository: FavoritesRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(NearbyUiState())
    val uiState: StateFlow<NearbyUiState> = _uiState.asStateFlow()

    private var locationUpdatesJob: Job? = null

    init {
        checkLocationPermission()
        observeFavorites()
    }

    private fun observeFavorites() {
        viewModelScope.launch {
            favoritesRepository.favorites.collect { favorites ->
                val favoriteKeys = favorites.map { "${it.lineId}|${it.stationName}|${it.direction}" }.toSet()
                _uiState.update { it.copy(favorites = favoriteKeys) }
            }
        }
    }

    fun checkLocationPermission() {
        val hasPermission = locationRepository.hasLocationPermission()
        _uiState.update { it.copy(hasLocationPermission = hasPermission) }
        if (hasPermission) {
            startLocationUpdates()
            fetchNearbyTrains()
        }
    }

    private fun startLocationUpdates() {
        locationUpdatesJob?.cancel()
        locationUpdatesJob = viewModelScope.launch {
            locationRepository.getLocationUpdates()
                .distinctUntilChanged { old, new ->
                    // Only trigger update if location changed significantly (50 meters)
                    val distance = FloatArray(1)
                    Location.distanceBetween(
                        old.latitude, old.longitude,
                        new.latitude, new.longitude,
                        distance
                    )
                    distance[0] < 50f
                }
                .collect { location ->
                    _uiState.update { it.copy(currentLocation = location) }
                    fetchNearbyTrainsForLocation(location)
                }
        }
    }

    fun fetchNearbyTrains() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            val location = locationRepository.getCurrentLocation()
            if (location == null) {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = "Unable to get current location"
                    )
                }
                return@launch
            }

            _uiState.update { it.copy(currentLocation = location) }
            fetchNearbyTrainsForLocation(location)
        }
    }

    private suspend fun fetchNearbyTrainsForLocation(location: Location) {
        _uiState.update { it.copy(isLoading = true, error = null) }

        subwayRepository.getNearbyTrains(location.latitude, location.longitude)
            .onSuccess { trains ->
                val trainsByStation = trains.groupBy { it.stationName }
                val groupedTrains = groupTrainsByStation(trains)
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        trains = trains,
                        trainsByStation = trainsByStation,
                        groupedTrains = groupedTrains,
                        error = null
                    )
                }
            }
            .onFailure { exception ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = exception.message ?: "Failed to fetch nearby trains"
                    )
                }
            }
    }

    private fun groupTrainsByStation(trains: List<NearbyTrain>): List<StationGroup> {
        // Group trains by station
        val byStation = trains.groupBy { it.stationName }

        return byStation.map { (stationName, stationTrains) ->
            val firstTrain = stationTrains.first()

            // Group by line + direction within this station
            val byLineDirection = stationTrains.groupBy { "${it.lineId}|${it.direction}" }

            val lineDirectionGroups = byLineDirection.map { (_, lineTrains) ->
                val sortedTrains = lineTrains.sortedBy { it.arrivalTime }
                val first = sortedTrains.first()
                LineDirectionGroup(
                    lineId = first.lineId,
                    direction = first.direction,
                    generalDirection = first.generalDirection,
                    destination = first.destination,
                    trains = sortedTrains
                )
            }.sortedBy { it.trains.first().arrivalTime } // Sort by next arrival

            StationGroup(
                stationName = stationName,
                stationDisplay = firstTrain.stationDisplay,
                distanceText = firstTrain.distanceText,
                distanceInMeters = firstTrain.distanceInMeters,
                lineDirectionGroups = lineDirectionGroups
            )
        }.sortedBy { it.distanceInMeters } // Sort stations by distance
    }

    fun startPeriodicRefresh() {
        viewModelScope.launch {
            while (true) {
                delay(30_000) // 30 seconds
                if (_uiState.value.hasLocationPermission) {
                    fetchNearbyTrains()
                }
            }
        }
    }

    fun toggleFavorite(train: NearbyTrain) {
        viewModelScope.launch {
            val key = "${train.lineId}|${train.stationName}|${train.direction}"
            val isFavorite = _uiState.value.favorites.contains(key)

            if (isFavorite) {
                // Find and remove the favorite
                favoritesRepository.favorites.first().find {
                    it.lineId == train.lineId &&
                    it.stationName == train.stationName &&
                    it.direction == train.direction
                }?.let { favorite ->
                    favoritesRepository.removeFavorite(favorite.id)
                }
            } else {
                // Add as favorite
                favoritesRepository.addFavorite(
                    FavoriteItem(
                        lineId = train.lineId,
                        stationName = train.stationName,
                        stationDisplay = train.stationDisplay,
                        direction = train.direction
                    )
                )
            }
        }
    }

    fun isFavorite(train: NearbyTrain): Boolean {
        val key = "${train.lineId}|${train.stationName}|${train.direction}"
        return _uiState.value.favorites.contains(key)
    }

    override fun onCleared() {
        super.onCleared()
        locationUpdatesJob?.cancel()
    }
}
