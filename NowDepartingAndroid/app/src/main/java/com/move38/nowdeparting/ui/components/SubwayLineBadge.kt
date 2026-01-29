package com.move38.nowdeparting.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.move38.nowdeparting.data.model.SubwayConfiguration
import com.move38.nowdeparting.data.model.SubwayLine

@Composable
fun SubwayLineBadge(
    lineId: String,
    modifier: Modifier = Modifier,
    size: Dp = 40.dp,
    fontSize: TextUnit = 20.sp
) {
    val line = SubwayConfiguration.getSubwayLine(lineId)
    SubwayLineBadge(line = line, modifier = modifier, size = size, fontSize = fontSize)
}

@Composable
fun SubwayLineBadge(
    line: SubwayLine,
    modifier: Modifier = Modifier,
    size: Dp = 40.dp,
    fontSize: TextUnit = 20.sp
) {
    Box(
        modifier = modifier
            .size(size)
            .clip(CircleShape)
            .background(line.backgroundColor),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = line.label,
            color = line.foregroundColor,
            fontSize = fontSize,
            fontWeight = FontWeight.Bold
        )
    }
}

@Composable
fun SmallSubwayLineBadge(
    lineId: String,
    modifier: Modifier = Modifier
) {
    SubwayLineBadge(
        lineId = lineId,
        modifier = modifier,
        size = 28.dp,
        fontSize = 14.sp
    )
}

@Composable
fun LargeSubwayLineBadge(
    lineId: String,
    modifier: Modifier = Modifier
) {
    SubwayLineBadge(
        lineId = lineId,
        modifier = modifier,
        size = 60.dp,
        fontSize = 32.sp
    )
}
