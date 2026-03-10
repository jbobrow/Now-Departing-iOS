package com.move38.nowdeparting.ui.screens.favorites

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
import com.move38.nowdeparting.data.model.FavoriteItem
import com.move38.nowdeparting.data.repository.DirectionHelper
import com.move38.nowdeparting.ui.components.WearSubwayLineBadge
import com.move38.nowdeparting.ui.screens.nearby.WearEmptyContent
import java.time.Instant
import java.time.temporal.ChronoUnit

@Composable
fun WearFavoritesScreen(
    viewModel: FavoritesViewModel = hiltViewModel(),
    onFavoriteClick: (FavoriteItem) -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.refreshTimes()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        if (uiState.favorites.isEmpty()) {
            WearEmptyContent(message = "No favorites yet.\nAdd from Nearby or Lines.")
        } else {
            ScalingLazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 24.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                item {
                    Text(
                        text = "Favorites",
                        style = MaterialTheme.typography.title2,
                        color = Color.White,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                items(uiState.favorites.size) { index ->
                    val favoriteWithTimes = uiState.favorites[index]
                    val favorite = favoriteWithTimes.favorite
                    val destination = DirectionHelper.getDestination(favorite.lineId, favorite.direction)

                    val timeText = if (favoriteWithTimes.isLoading) {
                        "..."
                    } else {
                        favoriteWithTimes.nextTrain?.let { time ->
                            val minutes = ChronoUnit.MINUTES.between(Instant.now(), time)
                            when {
                                minutes < 0 -> "--"
                                minutes == 0L -> "Now"
                                minutes == 1L -> "1 min"
                                else -> "$minutes min"
                            }
                        } ?: "--"
                    }

                    Chip(
                        onClick = { onFavoriteClick(favorite) },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ChipDefaults.chipColors(
                            backgroundColor = Color(0xFF1C1C1E)
                        ),
                        label = {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                WearSubwayLineBadge(lineId = favorite.lineId, size = 24.dp, fontSize = 14.sp)
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = favorite.stationDisplay.ifEmpty { favorite.stationName },
                                        color = Color.White,
                                        fontSize = 12.sp,
                                        maxLines = 1
                                    )
                                    Text(
                                        text = "to $destination",
                                        color = Color(0xFF8E8E93),
                                        fontSize = 10.sp,
                                        maxLines = 1
                                    )
                                }
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
