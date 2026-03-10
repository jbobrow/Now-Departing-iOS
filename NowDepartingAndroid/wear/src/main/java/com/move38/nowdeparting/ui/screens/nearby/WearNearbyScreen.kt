package com.move38.nowdeparting.ui.screens.nearby

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.items
import androidx.wear.compose.material.*
import com.move38.nowdeparting.data.model.NearbyTrain
import com.move38.nowdeparting.ui.components.WearSubwayLineBadge

@Composable
fun WearNearbyScreen(
    viewModel: NearbyViewModel = hiltViewModel(),
    onTrainClick: (NearbyTrain) -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val granted = permissions.values.any { it }
        if (granted) {
            viewModel.checkLocationPermission()
        }
    }

    LaunchedEffect(Unit) {
        viewModel.startPeriodicRefresh()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        when {
            !uiState.hasLocationPermission -> {
                WearLocationPermissionRequest(
                    onRequestPermission = {
                        permissionLauncher.launch(
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION
                            )
                        )
                    }
                )
            }
            uiState.isLoading && uiState.trains.isEmpty() -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            }
            uiState.error != null && uiState.trains.isEmpty() -> {
                WearErrorContent(
                    message = uiState.error!!,
                    onRetry = { viewModel.fetchNearbyTrains() }
                )
            }
            uiState.trains.isEmpty() -> {
                WearEmptyContent(message = "No subway stations found nearby.")
            }
            else -> {
                WearNearbyTrainsList(
                    stationGroups = uiState.groupedTrains,
                    onTrainClick = onTrainClick
                )
            }
        }
    }
}

@Composable
private fun WearNearbyTrainsList(
    stationGroups: List<StationGroup>,
    onTrainClick: (NearbyTrain) -> Unit
) {
    val items = stationGroups.flatMap { stationGroup ->
        buildList {
            add(stationGroup to null as LineDirectionGroup?)
            stationGroup.lineDirectionGroups.forEach { lineGroup ->
                add(stationGroup to lineGroup)
            }
        }
    }

    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        item {
            Text(
                text = "Nearby",
                style = MaterialTheme.typography.title2,
                color = Color.White,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
            )
        }

        items.forEach { (stationGroup, lineGroup) ->
            if (lineGroup == null) {
                item {
                    Text(
                        text = stationGroup.stationDisplay,
                        style = MaterialTheme.typography.caption1,
                        color = Color(0xFF8E8E93),
                        modifier = Modifier.padding(top = 8.dp, start = 8.dp)
                    )
                }
            } else {
                item {
                    val primaryTrain = lineGroup.trains.first()
                    val timeText = primaryTrain.timeText

                    Chip(
                        onClick = { onTrainClick(primaryTrain) },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ChipDefaults.chipColors(
                            backgroundColor = Color(0xFF1C1C1E)
                        ),
                        label = {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                WearSubwayLineBadge(lineId = lineGroup.lineId, size = 24.dp, fontSize = 14.sp)
                                Text(
                                    text = lineGroup.generalDirection.ifEmpty { lineGroup.destination },
                                    color = Color.White,
                                    fontSize = 13.sp,
                                    modifier = Modifier.weight(1f)
                                )
                                Text(
                                    text = timeText,
                                    color = Color.White,
                                    fontSize = 14.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun WearLocationPermissionRequest(onRequestPermission: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "Location needed",
            style = MaterialTheme.typography.title3,
            color = Color.White,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(8.dp))
        Chip(
            onClick = onRequestPermission,
            label = { Text("Enable Location") },
            colors = ChipDefaults.primaryChipColors()
        )
    }
}

@Composable
fun WearErrorContent(message: String, onRetry: () -> Unit) {
    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        item {
            Text(
                text = "Error",
                style = MaterialTheme.typography.title3,
                color = Color.White,
                textAlign = TextAlign.Center
            )
        }
        item {
            Text(
                text = message,
                style = MaterialTheme.typography.caption2,
                color = Color(0xFF8E8E93),
                textAlign = TextAlign.Center
            )
        }
        item {
            Chip(
                onClick = onRetry,
                label = { Text("Try Again") },
                colors = ChipDefaults.primaryChipColors()
            )
        }
    }
}

@Composable
fun WearEmptyContent(message: String) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = message,
            style = MaterialTheme.typography.body2,
            color = Color(0xFF8E8E93),
            textAlign = TextAlign.Center
        )
    }
}
