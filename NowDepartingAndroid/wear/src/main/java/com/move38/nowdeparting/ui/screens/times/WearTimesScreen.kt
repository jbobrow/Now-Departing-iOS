package com.move38.nowdeparting.ui.screens.times

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
import androidx.wear.compose.material.*
import com.move38.nowdeparting.ui.components.WearSubwayLineBadge
import java.time.Instant
import java.time.temporal.ChronoUnit

@Composable
fun WearTimesScreen(
    viewModel: TimesViewModel = hiltViewModel(),
    onBack: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.startPeriodicRefresh()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        when {
            uiState.isLoading && uiState.trains.isEmpty() -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            }
            uiState.error != null && uiState.trains.isEmpty() -> {
                Column(
                    modifier = Modifier.fillMaxSize().padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(
                        text = "Error loading trains",
                        color = Color.White,
                        textAlign = TextAlign.Center,
                        style = MaterialTheme.typography.body2
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Chip(
                        onClick = { viewModel.fetchTimes() },
                        label = { Text("Retry") },
                        colors = ChipDefaults.primaryChipColors()
                    )
                }
            }
            else -> {
                WearTimesContent(
                    uiState = uiState,
                    viewModel = viewModel
                )
            }
        }
    }
}

@Composable
private fun WearTimesContent(
    uiState: TimesUiState,
    viewModel: TimesViewModel
) {
    val now = Instant.ofEpochMilli(uiState.currentTimeMillis)
    val activeTrains = uiState.trains.filter { trainTime ->
        val secondsUntil = ChronoUnit.SECONDS.between(now, trainTime)
        secondsUntil > -30
    }

    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 24.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Header: line badge + station + direction
        item {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.fillMaxWidth()
            ) {
                WearSubwayLineBadge(
                    lineId = uiState.lineId,
                    size = 36.dp,
                    fontSize = 22.sp
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = uiState.stationDisplay.ifEmpty { uiState.stationName },
                    style = MaterialTheme.typography.title3,
                    color = Color.White,
                    textAlign = TextAlign.Center,
                    maxLines = 2
                )
                Text(
                    text = "to ${uiState.destination}",
                    style = MaterialTheme.typography.caption2,
                    color = Color(0xFF8E8E93),
                    textAlign = TextAlign.Center,
                    maxLines = 1
                )
            }
        }

        if (activeTrains.isEmpty()) {
            item {
                Text(
                    text = "No trains scheduled",
                    style = MaterialTheme.typography.body2,
                    color = Color(0xFF8E8E93),
                    textAlign = TextAlign.Center
                )
            }
        } else {
            // First train - large display
            item {
                val firstTrain = activeTrains.first()
                val seconds = viewModel.getSecondsUntil(firstTrain)
                val minutes = viewModel.getMinutesUntil(firstTrain)

                val timeText = when {
                    seconds < 30 -> "Now"
                    seconds < 60 -> "${seconds}s"
                    minutes == 1L -> "1 min"
                    else -> "$minutes min"
                }

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color(0xFF2C2C2E), shape = androidx.compose.foundation.shape.RoundedCornerShape(12.dp))
                        .padding(vertical = 12.dp, horizontal = 16.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = "Next train",
                            style = MaterialTheme.typography.caption2,
                            color = Color(0xFF8E8E93)
                        )
                        Text(
                            text = timeText,
                            fontSize = 36.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White
                        )
                    }
                }
            }

            // Following trains
            activeTrains.drop(1).take(4).forEachIndexed { index, trainTime ->
                item(key = "train_${index + 1}") {
                    val seconds = viewModel.getSecondsUntil(trainTime)
                    val minutes = viewModel.getMinutesUntil(trainTime)

                    val timeText = when {
                        seconds < 30 -> "Now"
                        seconds < 60 -> "${seconds}s"
                        minutes == 1L -> "1 min"
                        else -> "$minutes min"
                    }

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(Color(0xFF1C1C1E), shape = androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "Following",
                            style = MaterialTheme.typography.caption2,
                            color = Color(0xFF8E8E93)
                        )
                        Text(
                            text = timeText,
                            style = MaterialTheme.typography.body1,
                            fontWeight = FontWeight.Bold,
                            color = Color(0xFFAAAAAA)
                        )
                    }
                }
            }

            // Favorite toggle chip
            item {
                Spacer(modifier = Modifier.height(4.dp))
                CompactChip(
                    onClick = { viewModel.toggleFavorite() },
                    label = {
                        Text(
                            text = if (uiState.isFavorite) "Remove Favorite" else "Add Favorite",
                            fontSize = 11.sp
                        )
                    },
                    colors = ChipDefaults.chipColors(
                        backgroundColor = if (uiState.isFavorite) Color(0xFF3A1010) else Color(0xFF1C1C1E)
                    )
                )
            }
        }
    }
}
