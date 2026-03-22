package com.move38.nowdeparting.ui.screens.nearby

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.move38.nowdeparting.data.model.NearbyTrain
import com.move38.nowdeparting.ui.components.ConsolidatedTrainRow
import com.move38.nowdeparting.ui.components.NearbyStationHeader

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NearbyScreen(
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

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Nearby", color = Color.White) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Black
                ),
                actions = {
                    if (uiState.hasLocationPermission) {
                        IconButton(onClick = { viewModel.fetchNearbyTrains() }) {
                            Icon(
                                imageVector = Icons.Default.Refresh,
                                contentDescription = "Refresh",
                                tint = Color.White
                            )
                        }
                    }
                }
            )
        },
        containerColor = Color.Black
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when {
                !uiState.hasLocationPermission -> {
                    LocationPermissionRequest(
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
                        CircularProgressIndicator(color = Color.White)
                    }
                }
                uiState.error != null && uiState.trains.isEmpty() -> {
                    ErrorContent(
                        message = uiState.error!!,
                        onRetry = { viewModel.fetchNearbyTrains() }
                    )
                }
                uiState.trains.isEmpty() -> {
                    EmptyContent()
                }
                else -> {
                    NearbyTrainsList(
                        stationGroups = uiState.groupedTrains,
                        onTrainClick = onTrainClick,
                        isFavorite = { viewModel.isFavorite(it) },
                        hasAlert = { viewModel.hasAlert(it) },
                        onFavoriteClick = { viewModel.toggleFavorite(it) }
                    )
                }
            }
        }
    }
}

@Composable
private fun NearbyTrainsList(
    stationGroups: List<StationGroup>,
    onTrainClick: (NearbyTrain) -> Unit,
    isFavorite: (NearbyTrain) -> Boolean,
    hasAlert: (String) -> Boolean,
    onFavoriteClick: (NearbyTrain) -> Unit
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        stationGroups.forEach { stationGroup ->
            item(key = "header_${stationGroup.stationName}") {
                NearbyStationHeader(
                    stationName = stationGroup.stationDisplay,
                    distance = stationGroup.distanceText
                )
            }

            // One row per line/direction combination
            stationGroup.lineDirectionGroups.forEach { lineGroup ->
                item(key = "${stationGroup.stationName}_${lineGroup.lineId}_${lineGroup.direction}") {
                    val primaryTrain = lineGroup.trains.first()
                    val additionalTrains = lineGroup.trains.drop(1)

                    ConsolidatedTrainRow(
                        primaryTrain = primaryTrain,
                        additionalTrains = additionalTrains,
                        isFavorite = isFavorite(primaryTrain),
                        hasAlert = hasAlert(lineGroup.lineId),
                        onFavoriteClick = { onFavoriteClick(primaryTrain) },
                        onClick = { onTrainClick(primaryTrain) }
                    )
                }
            }

            item(key = "spacer_${stationGroup.stationName}") {
                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }
}

@Composable
private fun LocationPermissionRequest(onRequestPermission: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = Icons.Default.LocationOn,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = Color(0xFF8E8E93)
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "Location Access Required",
            style = MaterialTheme.typography.titleLarge,
            color = Color.White,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "We need your location to show nearby subway stations and train times.",
            style = MaterialTheme.typography.bodyMedium,
            color = Color(0xFF8E8E93),
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(24.dp))
        Button(
            onClick = onRequestPermission,
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.White,
                contentColor = Color.Black
            )
        ) {
            Text("Enable Location")
        }
    }
}

@Composable
private fun ErrorContent(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "Something went wrong",
            style = MaterialTheme.typography.titleLarge,
            color = Color.White,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = message,
            style = MaterialTheme.typography.bodyMedium,
            color = Color(0xFF8E8E93),
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(24.dp))
        Button(
            onClick = onRetry,
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.White,
                contentColor = Color.Black
            )
        ) {
            Text("Try Again")
        }
    }
}

@Composable
private fun EmptyContent() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "No Nearby Trains",
            style = MaterialTheme.typography.titleLarge,
            color = Color.White,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "No subway stations found nearby. Try moving closer to a station.",
            style = MaterialTheme.typography.bodyMedium,
            color = Color(0xFF8E8E93),
            textAlign = TextAlign.Center
        )
    }
}
