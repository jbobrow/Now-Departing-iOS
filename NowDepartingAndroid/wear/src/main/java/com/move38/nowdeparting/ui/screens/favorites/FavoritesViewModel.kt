package com.move38.nowdeparting.ui.screens.favorites

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.move38.nowdeparting.data.model.FavoriteItem
import com.move38.nowdeparting.data.repository.FavoritesRepository
import com.move38.nowdeparting.data.repository.SubwayRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import java.time.Instant
import javax.inject.Inject

data class FavoriteWithTimes(
    val favorite: FavoriteItem,
    val nextTrain: Instant? = null,
    val isLoading: Boolean = false
)

data class FavoritesUiState(
    val favorites: List<FavoriteWithTimes> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class FavoritesViewModel @Inject constructor(
    private val favoritesRepository: FavoritesRepository,
    private val subwayRepository: SubwayRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(FavoritesUiState())
    val uiState: StateFlow<FavoritesUiState> = _uiState.asStateFlow()

    init {
        observeFavorites()
    }

    private fun observeFavorites() {
        viewModelScope.launch {
            favoritesRepository.favorites.collect { favorites ->
                val favoritesWithTimes = favorites.map { FavoriteWithTimes(it, isLoading = true) }
                _uiState.update { it.copy(favorites = favoritesWithTimes) }

                // Fetch times for each favorite
                favorites.forEachIndexed { index, favorite ->
                    fetchTimesForFavorite(index, favorite)
                }
            }
        }
    }

    private fun fetchTimesForFavorite(index: Int, favorite: FavoriteItem) {
        viewModelScope.launch {
            subwayRepository.getTrainTimes(
                favorite.lineId,
                favorite.stationName,
                favorite.direction
            ).onSuccess { times ->
                _uiState.update { state ->
                    val updatedFavorites = state.favorites.toMutableList()
                    if (index < updatedFavorites.size) {
                        updatedFavorites[index] = updatedFavorites[index].copy(
                            nextTrain = times.firstOrNull(),
                            isLoading = false
                        )
                    }
                    state.copy(favorites = updatedFavorites)
                }
            }.onFailure {
                _uiState.update { state ->
                    val updatedFavorites = state.favorites.toMutableList()
                    if (index < updatedFavorites.size) {
                        updatedFavorites[index] = updatedFavorites[index].copy(
                            isLoading = false
                        )
                    }
                    state.copy(favorites = updatedFavorites)
                }
            }
        }
    }

    fun refreshTimes() {
        viewModelScope.launch {
            val currentFavorites = _uiState.value.favorites
            currentFavorites.forEachIndexed { index, favoriteWithTimes ->
                fetchTimesForFavorite(index, favoriteWithTimes.favorite)
            }
        }
    }

    fun removeFavorite(favoriteId: String) {
        viewModelScope.launch {
            favoritesRepository.removeFavorite(favoriteId)
        }
    }

    fun reorderFavorites(fromIndex: Int, toIndex: Int) {
        viewModelScope.launch {
            val currentList = _uiState.value.favorites.toMutableList()
            val item = currentList.removeAt(fromIndex)
            currentList.add(toIndex, item)
            _uiState.update { it.copy(favorites = currentList) }

            // Persist the new order
            favoritesRepository.reorderFavorites(currentList.map { it.favorite })
        }
    }
}
