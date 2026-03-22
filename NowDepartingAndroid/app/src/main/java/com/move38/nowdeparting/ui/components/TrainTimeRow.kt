package com.move38.nowdeparting.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.move38.nowdeparting.data.model.NearbyTrain

@Composable
fun TrainTimeRow(
    train: NearbyTrain,
    isFavorite: Boolean,
    onFavoriteClick: () -> Unit,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color(0xFF1C1C1E))
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Line badge
        SubwayLineBadge(lineId = train.lineId, size = 36.dp, fontSize = 27.sp)

        Spacer(modifier = Modifier.width(12.dp))

        // Direction and destination
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = train.generalDirection.ifEmpty { train.directionText },
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                color = Color.White
            )
            Text(
                text = train.destination,
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFF8E8E93)
            )
        }

        // Arrival time
        Text(
            text = train.timeText,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = Color.White
        )

        Spacer(modifier = Modifier.width(8.dp))

        // Favorite button
        IconButton(
            onClick = onFavoriteClick,
            modifier = Modifier.size(32.dp)
        ) {
            Icon(
                imageVector = if (isFavorite) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                contentDescription = if (isFavorite) "Remove from favorites" else "Add to favorites",
                tint = if (isFavorite) Color(0xFFFF3B30) else Color(0xFF8E8E93)
            )
        }
    }
}

// Consolidated row showing primary train time and following times
@Composable
fun ConsolidatedTrainRow(
    primaryTrain: NearbyTrain,
    additionalTrains: List<NearbyTrain>,
    isFavorite: Boolean,
    hasAlert: Boolean = false,
    onFavoriteClick: () -> Unit,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color(0xFF1C1C1E))
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Line badge with optional alert indicator
        Box {
            SubwayLineBadge(lineId = primaryTrain.lineId, size = 48.dp, fontSize = 32.sp)
            if (hasAlert) {
                Icon(
                    imageVector = Icons.Default.Warning,
                    contentDescription = "Service alert",
                    tint = Color(0xFFFFCC00),
                    modifier = Modifier
                        .size(16.dp)
                        .align(Alignment.TopEnd)
                        .offset(x = 4.dp, y = (-4).dp)
                        .background(Color.Black, CircleShape)
                        .padding(1.dp)
                )
            }
        }

        Spacer(modifier = Modifier.width(12.dp))

        // Direction and destination
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = primaryTrain.generalDirection.ifEmpty { primaryTrain.directionText },
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
            Text(
                text = primaryTrain.destination,
                style = MaterialTheme.typography.bodySmall,
                color = Color(0xFF8E8E93)
            )
        }

        // Times column
        Column(horizontalAlignment = Alignment.End) {
            // Primary arrival time (large)
            Text(
                text = primaryTrain.preciseTimeText,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )

            // Following times (smaller, comma-separated)
            if (additionalTrains.isNotEmpty()) {
                Text(
                    text = additionalTrains.take(4).joinToString(", ") { it.timeText },
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF8E8E93)
                )
            }
        }

        Spacer(modifier = Modifier.width(8.dp))

        // Favorite button
        IconButton(
            onClick = onFavoriteClick,
            modifier = Modifier.size(32.dp)
        ) {
            Icon(
                imageVector = if (isFavorite) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                contentDescription = if (isFavorite) "Remove from favorites" else "Add to favorites",
                tint = if (isFavorite) Color(0xFFFF3B30) else Color(0xFF8E8E93)
            )
        }
    }
}

@Composable
fun NearbyStationHeader(
    stationName: String,
    distance: String,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = stationName,
            style = MaterialTheme.typography.headlineLarge,
            fontWeight = FontWeight.SemiBold,
            color = Color.White
        )
        Text(
            text = distance,
            style = MaterialTheme.typography.bodySmall,
            color = Color(0xFF8E8E93)
        )
    }
}
