package com.move38.nowdeparting.ui.screens.lines

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.move38.nowdeparting.data.model.Station
import com.move38.nowdeparting.data.model.SubwayLine
import com.move38.nowdeparting.ui.components.SubwayLineBadge

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LinesScreen(
    viewModel: LinesViewModel = hiltViewModel(),
    onStationSelected: (lineId: String, station: Station, direction: String) -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = uiState.selectedLine?.let { "Line ${it.label}" } ?: "Lines",
                        color = Color.White
                    )
                },
                navigationIcon = {
                    if (uiState.selectedLine != null) {
                        IconButton(onClick = { viewModel.clearSelection() }) {
                            Icon(
                                imageVector = Icons.Default.ArrowBack,
                                contentDescription = "Back",
                                tint = Color.White
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Black
                )
            )
        },
        containerColor = Color.Black
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            if (uiState.selectedLine == null) {
                LinesGrid(
                    lines = uiState.lines,
                    onLineClick = { viewModel.selectLine(it) }
                )
            } else {
                StationsList(
                    lineId = uiState.selectedLine!!.id,
                    stations = uiState.stations,
                    isLoading = uiState.isLoadingStations,
                    onStationSelected = { station, direction ->
                        onStationSelected(uiState.selectedLine!!.id, station, direction)
                    }
                )
            }
        }
    }
}

@Composable
private fun LinesGrid(
    lines: List<SubwayLine>,
    onLineClick: (SubwayLine) -> Unit
) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(4),
        contentPadding = PaddingValues(16.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier.fillMaxSize()
    ) {
        items(lines, key = { it.id }) { line ->
            SubwayLineBadge(
                line = line,
                size = 64.dp,
                fontSize = 28.sp,
                modifier = Modifier.clickable { onLineClick(line) }
            )
        }
    }
}

@Composable
private fun StationsList(
    lineId: String,
    stations: List<Station>,
    isLoading: Boolean,
    onStationSelected: (Station, String) -> Unit
) {
    var expandedStation by remember { mutableStateOf<String?>(null) }

    if (isLoading) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator(color = Color.White)
        }
    } else {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(stations, key = { it.name }) { station ->
                StationItem(
                    station = station,
                    lineId = lineId,
                    isExpanded = expandedStation == station.name,
                    onExpandToggle = {
                        expandedStation = if (expandedStation == station.name) null else station.name
                    },
                    onDirectionSelected = { direction ->
                        onStationSelected(station, direction)
                    }
                )
            }
        }
    }
}

@Composable
private fun StationItem(
    station: Station,
    lineId: String,
    isExpanded: Boolean,
    onExpandToggle: () -> Unit,
    onDirectionSelected: (String) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color(0xFF1C1C1E))
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = onExpandToggle)
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            SubwayLineBadge(lineId = lineId, size = 32.dp, fontSize = 16.sp)
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = station.displayName,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                color = Color.White,
                modifier = Modifier.weight(1f)
            )
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = "Expand",
                tint = Color(0xFF8E8E93),
                modifier = Modifier.size(24.dp)
            )
        }

        if (isExpanded) {
            HorizontalDivider(color = Color(0xFF3A3A3C))
            DirectionButtons(
                onDirectionSelected = onDirectionSelected
            )
        }
    }
}

@Composable
private fun DirectionButtons(
    onDirectionSelected: (String) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Button(
            onClick = { onDirectionSelected("N") },
            modifier = Modifier.weight(1f),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color(0xFF2C2C2E),
                contentColor = Color.White
            ),
            shape = RoundedCornerShape(8.dp)
        ) {
            Text("Uptown")
        }
        Button(
            onClick = { onDirectionSelected("S") },
            modifier = Modifier.weight(1f),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color(0xFF2C2C2E),
                contentColor = Color.White
            ),
            shape = RoundedCornerShape(8.dp)
        ) {
            Text("Downtown")
        }
    }
}
