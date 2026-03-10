package com.move38.nowdeparting.ui.screens.lines

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.move38.nowdeparting.data.model.Station
import com.move38.nowdeparting.data.model.SubwayConfiguration
import com.move38.nowdeparting.data.model.SubwayLine
import com.move38.nowdeparting.data.repository.SubwayRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class LinesUiState(
    val lines: List<SubwayLine> = SubwayConfiguration.allLines,
    val selectedLine: SubwayLine? = null,
    val stations: List<Station> = emptyList(),
    val isLoadingStations: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class LinesViewModel @Inject constructor(
    private val subwayRepository: SubwayRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(LinesUiState())
    val uiState: StateFlow<LinesUiState> = _uiState.asStateFlow()

    fun selectLine(line: SubwayLine) {
        _uiState.update { it.copy(selectedLine = line, isLoadingStations = true) }
        loadStations(line.id)
    }

    fun clearSelection() {
        _uiState.update { it.copy(selectedLine = null, stations = emptyList()) }
    }

    private fun loadStations(lineId: String) {
        viewModelScope.launch {
            try {
                val stations = subwayRepository.getStationsForLine(lineId)
                _uiState.update {
                    it.copy(
                        stations = stations,
                        isLoadingStations = false,
                        error = null
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isLoadingStations = false,
                        error = e.message ?: "Failed to load stations"
                    )
                }
            }
        }
    }
}
