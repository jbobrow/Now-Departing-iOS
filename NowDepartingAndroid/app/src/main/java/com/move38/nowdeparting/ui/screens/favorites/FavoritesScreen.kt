package com.move38.nowdeparting.ui.screens.favorites

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.DragHandle
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.move38.nowdeparting.data.model.FavoriteItem
import com.move38.nowdeparting.data.repository.DirectionHelper
import com.move38.nowdeparting.ui.components.SubwayLineBadge
import org.burnoutcrew.reorderable.*
import java.time.Instant
import java.time.temporal.ChronoUnit

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FavoritesScreen(
    viewModel: FavoritesViewModel = hiltViewModel(),
    onFavoriteClick: (FavoriteItem) -> Unit
) {
    val uiState by viewModel.uiState.collectAsState()

    val reorderState = rememberReorderableLazyListState(onMove = { from, to ->
        viewModel.reorderFavorites(from.index, to.index)
    })

    LaunchedEffect(Unit) {
        viewModel.refreshTimes()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Favorites", color = Color.White) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Black
                ),
                actions = {
                    IconButton(onClick = { viewModel.refreshTimes() }) {
                        Icon(
                            imageVector = Icons.Default.Refresh,
                            contentDescription = "Refresh",
                            tint = Color.White
                        )
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
            if (uiState.favorites.isEmpty()) {
                EmptyFavoritesContent()
            } else {
                LazyColumn(
                    state = reorderState.listState,
                    modifier = Modifier
                        .fillMaxSize()
                        .reorderable(reorderState),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    itemsIndexed(
                        uiState.favorites,
                        key = { _, item -> item.favorite.id }
                    ) { index, favoriteWithTimes ->
                        ReorderableItem(reorderState, key = favoriteWithTimes.favorite.id) { isDragging ->
                            val elevation by animateDpAsState(
                                targetValue = if (isDragging) 8.dp else 0.dp,
                                label = "elevation"
                            )

                            FavoriteCard(
                                favoriteWithTimes = favoriteWithTimes,
                                onClick = { onFavoriteClick(favoriteWithTimes.favorite) },
                                onDelete = { viewModel.removeFavorite(favoriteWithTimes.favorite.id) },
                                modifier = Modifier
                                    .shadow(elevation, RoundedCornerShape(12.dp))
                                    .detectReorderAfterLongPress(reorderState)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FavoriteCard(
    favoriteWithTimes: FavoriteWithTimes,
    onClick: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier
) {
    val favorite = favoriteWithTimes.favorite
    val destination = DirectionHelper.getDestination(favorite.lineId, favorite.direction)

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color(0xFF1C1C1E))
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = Icons.Default.DragHandle,
            contentDescription = "Drag to reorder",
            tint = Color(0xFF8E8E93),
            modifier = Modifier.size(24.dp)
        )

        Spacer(modifier = Modifier.width(12.dp))

        SubwayLineBadge(lineId = favorite.lineId, size = 48.dp, fontSize = 32.sp)

        Spacer(modifier = Modifier.width(12.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = favorite.stationDisplay.ifEmpty { favorite.stationName },
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                color = Color.White
            )
            Text(
                text = "to $destination",
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFF8E8E93)
            )
        }

        // Time display
        if (favoriteWithTimes.isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.size(24.dp),
                color = Color.White,
                strokeWidth = 2.dp
            )
        } else {
            val timeText = favoriteWithTimes.nextTrain?.let { time ->
                val minutes = ChronoUnit.MINUTES.between(Instant.now(), time)
                when {
                    minutes < 0 -> "--"
                    minutes == 0L -> "Now"
                    minutes == 1L -> "1 min"
                    else -> "$minutes min"
                }
            } ?: "--"

            val isUrgent = favoriteWithTimes.nextTrain?.let { time ->
                ChronoUnit.MINUTES.between(Instant.now(), time) <= 1
            } ?: false

            Text(
                text = timeText,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }

        Spacer(modifier = Modifier.width(8.dp))

        // Delete button
        IconButton(
            onClick = onDelete,
            modifier = Modifier.size(32.dp)
        ) {
            Icon(
                imageVector = Icons.Default.Delete,
                contentDescription = "Delete",
                tint = Color(0xFF8E8E93)
            )
        }
    }
}

@Composable
private fun EmptyFavoritesContent() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "No Favorites",
            style = MaterialTheme.typography.titleLarge,
            color = Color.White,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Add your favorite stations from the Nearby or Lines tabs to see them here.",
            style = MaterialTheme.typography.bodyMedium,
            color = Color(0xFF8E8E93),
            textAlign = TextAlign.Center
        )
    }
}
