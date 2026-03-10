package com.move38.nowdeparting.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Text
import com.move38.nowdeparting.data.model.SubwayConfiguration
import com.move38.nowdeparting.data.model.SubwayLine

@Composable
fun WearSubwayLineBadge(
    lineId: String,
    modifier: Modifier = Modifier,
    size: Dp = 28.dp,
    fontSize: TextUnit = 18.sp
) {
    val line = SubwayConfiguration.getSubwayLine(lineId)
    WearSubwayLineBadge(line = line, modifier = modifier, size = size, fontSize = fontSize)
}

@Composable
fun WearSubwayLineBadge(
    line: SubwayLine,
    modifier: Modifier = Modifier,
    size: Dp = 28.dp,
    fontSize: TextUnit = 18.sp
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
