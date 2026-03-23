package com.move38.nowdeparting.ui.screens.times

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.move38.nowdeparting.data.model.FavoriteItem
import com.move38.nowdeparting.data.repository.DirectionHelper
import com.move38.nowdeparting.data.repository.FavoritesRepository
import com.move38.nowdeparting.data.repository.SubwayRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.time.Instant
import java.time.temporal.ChronoUnit
import javax.inject.Inject

data class TimesUiState(
    val lineId: String = "",
    val stationName: String = "",
    val stationDisplay: String = "",
    val direction: String = "",
    val destination: String = "",
    val trains: List<Instant> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    val isFavorite: Boolean = false,
    val currentTimeMillis: Long = System.currentTimeMillis(), // For triggering recomposition
    val serviceAlerts: List<com.move38.nowdeparting.data.api.GTFSAlert> = emptyList()
)

@HiltViewModel
class TimesViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val subwayRepository: SubwayRepository,
    private val favoritesRepository: FavoritesRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(TimesUiState())
    val uiState: StateFlow<TimesUiState> = _uiState.asStateFlow()

    private var timerJob: Job? = null
    private var refreshJob: Job? = null

    init {
        // Get navigation arguments and decode URL encoding
        val lineId = savedStateHandle.get<String>("lineId") ?: ""
        val stationNameRaw = savedStateHandle.get<String>("stationName") ?: ""
        val stationDisplayRaw = savedStateHandle.get<String>("stationDisplay") ?: stationNameRaw
        val direction = savedStateHandle.get<String>("direction") ?: ""

        // URL decode the station names (handles + and %20 for spaces)
        val stationName = try {
            URLDecoder.decode(stationNameRaw, StandardCharsets.UTF_8.toString())
        } catch (e: Exception) { stationNameRaw }

        val stationDisplay = try {
            URLDecoder.decode(stationDisplayRaw, StandardCharsets.UTF_8.toString())
        } catch (e: Exception) { stationDisplayRaw }

        _uiState.update {
            it.copy(
                lineId = lineId,
                stationName = stationName,
                stationDisplay = stationDisplay,
                direction = direction,
                destination = DirectionHelper.getDestination(lineId, direction)
            )
        }

        observeFavorites()
        fetchTimes()
        fetchAlerts()
        startCountdownTimer()
    }

    private fun observeFavorites() {
        viewModelScope.launch {
            favoritesRepository.favorites.collect { favorites ->
                val state = _uiState.value
                val isFavorite = favorites.any {
                    it.lineId == state.lineId &&
                    it.stationName == state.stationName &&
                    it.direction == state.direction
                }
                _uiState.update { it.copy(isFavorite = isFavorite) }
            }
        }
    }

    fun fetchTimes() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            val state = _uiState.value
            subwayRepository.getTrainTimes(
                state.lineId,
                state.stationName,
                state.direction
            ).onSuccess { times ->
                _uiState.update {
                    it.copy(
                        trains = times,
                        isLoading = false,
                        error = null
                    )
                }
            }.onFailure { exception ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = exception.message ?: "Failed to fetch train times"
                    )
                }
            }
        }
    }

    private fun fetchAlerts() {
        viewModelScope.launch {
            subwayRepository.getServiceAlerts().onSuccess { alertsByRoute ->
                val lineAlerts = alertsByRoute[_uiState.value.lineId] ?: emptyList()
                _uiState.update { it.copy(serviceAlerts = lineAlerts) }
            }
        }
    }

    private fun startCountdownTimer() {
        timerJob?.cancel()
        timerJob = viewModelScope.launch {
            while (true) {
                delay(1000)
                _uiState.update { it.copy(currentTimeMillis = System.currentTimeMillis()) }
            }
        }
    }

    fun startPeriodicRefresh() {
        refreshJob?.cancel()
        refreshJob = viewModelScope.launch {
            while (true) {
                delay(60_000) // Refresh every 60 seconds
                fetchTimes()
            }
        }
    }

    fun toggleFavorite() {
        viewModelScope.launch {
            val state = _uiState.value
            if (state.isFavorite) {
                // Remove favorite
                favoritesRepository.favorites.first().find {
                    it.lineId == state.lineId &&
                    it.stationName == state.stationName &&
                    it.direction == state.direction
                }?.let { favorite ->
                    favoritesRepository.removeFavorite(favorite.id)
                }
            } else {
                // Add favorite
                favoritesRepository.addFavorite(
                    FavoriteItem(
                        lineId = state.lineId,
                        stationName = state.stationName,
                        stationDisplay = state.stationDisplay,
                        direction = state.direction
                    )
                )
            }
        }
    }

    fun getMinutesUntil(time: Instant): Long {
        return ChronoUnit.MINUTES.between(Instant.now(), time).coerceAtLeast(0)
    }

    fun getSecondsUntil(time: Instant): Long {
        return ChronoUnit.SECONDS.between(Instant.now(), time).coerceAtLeast(0)
    }

    override fun onCleared() {
        super.onCleared()
        timerJob?.cancel()
        refreshJob?.cancel()
    }
}
