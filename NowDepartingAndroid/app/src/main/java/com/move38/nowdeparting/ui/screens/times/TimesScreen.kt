package com.move38.nowdeparting.ui.screens.times

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.move38.nowdeparting.ui.components.LargeSubwayLineBadge
import com.move38.nowdeparting.ui.components.SubwayLineBadge
import java.time.Instant

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimesScreen(
    viewModel: TimesViewModel = hiltViewModel(),
    onBack: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(Unit) {
        viewModel.startPeriodicRefresh()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Train Times", color = Color.White) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.White
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Black
                ),
                actions = {
                    IconButton(onClick = { viewModel.toggleFavorite() }) {
                        Icon(
                            imageVector = if (uiState.isFavorite) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                            contentDescription = if (uiState.isFavorite) "Remove from favorites" else "Add to favorites",
                            tint = if (uiState.isFavorite) Color(0xFFFF3B30) else Color.White
                        )
                    }
                    IconButton(onClick = { viewModel.fetchTimes() }) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Refresh",
                            tint = Color.White
                        )
                    }
                }
            )
        },
        bottomBar = {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color.Black)
                    .padding(16.dp)
            ) {
                Button(
                    onClick = {
                        val stationName = uiState.stationDisplay.ifEmpty { uiState.stationName }
                        val searchQuery = "$stationName subway station NYC"
                        val encodedQuery = Uri.encode(searchQuery)
                        val geoUri = Uri.parse("geo:0,0?q=$encodedQuery")
                        val mapIntent = Intent(Intent.ACTION_VIEW, geoUri)
                        context.startActivity(mapIntent)
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF2C2C2E),
                        contentColor = Color.White
                    ),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Place,
                        contentDescription = null,
                        modifier = Modifier.size(24.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "View on Map",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
        },
        containerColor = Color.Black
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Header with line badge
            LargeSubwayLineBadge(lineId = uiState.lineId)

            Spacer(modifier = Modifier.height(16.dp))

            // Station name
            Text(
                text = uiState.stationDisplay.ifEmpty { uiState.stationName },
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                textAlign = TextAlign.Center
            )

            // Direction/destination
            Text(
                text = "to ${uiState.destination}",
                style = MaterialTheme.typography.bodyLarge,
                color = Color(0xFF8E8E93),
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(32.dp))

            // Loading/Error/Content
            when {
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
                        onRetry = { viewModel.fetchTimes() }
                    )
                }
                uiState.trains.isEmpty() -> {
                    NoTrainsContent()
                }
                else -> {
                    TrainTimesList(
                        trains = uiState.trains,
                        viewModel = viewModel,
                        currentTimeMillis = uiState.currentTimeMillis
                    )
                }
            }
        }
    }
}

@Composable
private fun TrainTimesList(
    trains: List<Instant>,
    viewModel: TimesViewModel,
    currentTimeMillis: Long // Used to trigger recomposition every second
) {
    // Filter out trains that have already departed (more than 30 seconds ago)
    // This ensures the display updates in real-time as trains depart
    val now = Instant.ofEpochMilli(currentTimeMillis)
    val activeTrains = trains.filter { trainTime ->
        val secondsUntil = java.time.temporal.ChronoUnit.SECONDS.between(now, trainTime)
        secondsUntil > -30 // Keep trains that are arriving now or in the future
    }

    if (activeTrains.isEmpty()) {
        NoTrainsContent()
        return
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        itemsIndexed(activeTrains.take(10)) { index, trainTime ->
            val minutes = viewModel.getMinutesUntil(trainTime)
            val seconds = viewModel.getSecondsUntil(trainTime)

            val timeText = when {
                seconds < 30 -> "Now"
                seconds < 60 -> "${seconds}s"
                minutes == 1L -> "1 min"
                else -> "$minutes min"
            }

            val isFirst = index == 0
            val isUrgent = minutes <= 1

            TrainTimeCard(
                timeText = timeText,
                isFirst = isFirst,
                isUrgent = isUrgent
            )
        }
    }
}

@Composable
private fun TrainTimeCard(
    timeText: String,
    isFirst: Boolean,
    isUrgent: Boolean
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(if (isFirst) Color(0xFF2C2C2E) else Color(0xFF1C1C1E))
            .padding(horizontal = 20.dp, vertical = if (isFirst) 24.dp else 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = if (isFirst) "Next train" else "Following",
            style = if (isFirst) MaterialTheme.typography.titleMedium else MaterialTheme.typography.bodyLarge,
            color = Color(0xFF8E8E93)
        )

        Text(
            text = timeText,
            style = if (isFirst) MaterialTheme.typography.headlineLarge else MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            fontSize = if (isFirst) 48.sp else 24.sp,
            color = if (isFirst) Color.White else Color(0xFFAAAAAA)
        )
    }
}

@Composable
private fun ErrorContent(message: String, onRetry: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize(),
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
private fun NoTrainsContent() {
    Column(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "No Trains Scheduled",
            style = MaterialTheme.typography.titleLarge,
            color = Color.White,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "There are no trains scheduled for this direction right now.",
            style = MaterialTheme.typography.bodyMedium,
            color = Color(0xFF8E8E93),
            textAlign = TextAlign.Center
        )
    }
}
