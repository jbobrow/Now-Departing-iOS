package com.move38.nowdeparting.ui.screens.lines

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.material.*
import com.move38.nowdeparting.data.model.Station
import com.move38.nowdeparting.data.model.SubwayConfiguration
import com.move38.nowdeparting.data.model.SubwayLine
import com.move38.nowdeparting.ui.components.WearSubwayLineBadge

@Composable
fun WearLinesScreen(
    viewModel: LinesViewModel = hiltViewModel(),
    onStationSelected: (lineId: String, station: Station, direction: String) -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        if (uiState.selectedLine == null) {
            WearLinesGrid(
                lines = uiState.lines,
                onLineClick = { viewModel.selectLine(it) }
            )
        } else {
            WearStationsList(
                line = uiState.selectedLine!!,
                stations = uiState.stations,
                isLoading = uiState.isLoadingStations,
                onBack = { viewModel.clearSelection() },
                onStationSelected = { station, direction ->
                    onStationSelected(uiState.selectedLine!!.id, station, direction)
                }
            )
        }
    }
}

@Composable
private fun WearLinesGrid(
    lines: List<SubwayLine>,
    onLineClick: (SubwayLine) -> Unit
) {
    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        item {
            Text(
                text = "Lines",
                style = MaterialTheme.typography.title2,
                color = Color.White,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
            )
        }

        // Display 4 lines per row, preserving spacer slots for correct alignment
        val rows = lines.chunked(4)

        rows.forEach { rowLines ->
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    rowLines.forEach { line ->
                        if (SubwayConfiguration.isSpacer(line.id)) {
                            Box(modifier = Modifier.size(36.dp))
                        } else {
                            WearSubwayLineBadge(
                                line = line,
                                size = 36.dp,
                                fontSize = 22.sp,
                                modifier = Modifier.clickable { onLineClick(line) }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun WearStationsList(
    line: SubwayLine,
    stations: List<Station>,
    isLoading: Boolean,
    onBack: () -> Unit,
    onStationSelected: (Station, String) -> Unit
) {
    var expandedStation by remember { mutableStateOf<String?>(null) }

    if (isLoading) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator()
        }
        return
    }

    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                WearSubwayLineBadge(line = line, size = 32.dp, fontSize = 20.sp)
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "Select Station",
                    style = MaterialTheme.typography.title3,
                    color = Color.White
                )
            }
        }

        stations.forEach { station ->
            if (expandedStation == station.name) {
                // Direction selection
                item(key = "${station.name}_header") {
                    Text(
                        text = station.displayName,
                        style = MaterialTheme.typography.caption1,
                        color = Color.White,
                        modifier = Modifier.padding(horizontal = 8.dp)
                    )
                }
                item(key = "${station.name}_uptown") {
                    Chip(
                        onClick = { onStationSelected(station, "N") },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ChipDefaults.chipColors(
                            backgroundColor = Color(0xFF2C2C2E)
                        ),
                        label = { Text("Uptown / N", color = Color.White) }
                    )
                }
                item(key = "${station.name}_downtown") {
                    Chip(
                        onClick = { onStationSelected(station, "S") },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ChipDefaults.chipColors(
                            backgroundColor = Color(0xFF2C2C2E)
                        ),
                        label = { Text("Downtown / S", color = Color.White) }
                    )
                }
                item(key = "${station.name}_back") {
                    CompactChip(
                        onClick = { expandedStation = null },
                        label = { Text("Back", fontSize = 11.sp) },
                        colors = ChipDefaults.chipColors(
                            backgroundColor = Color(0xFF1C1C1E)
                        )
                    )
                }
            } else {
                item(key = station.name) {
                    Chip(
                        onClick = { expandedStation = station.name },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ChipDefaults.chipColors(
                            backgroundColor = Color(0xFF1C1C1E)
                        ),
                        enabled = station.hasAvailableTimes,
                        label = {
                            Text(
                                text = station.displayName,
                                color = if (station.hasAvailableTimes) Color.White else Color(0xFF5A5A5A),
                                fontSize = 13.sp
                            )
                        }
                    )
                }
            }
        }
    }
}
