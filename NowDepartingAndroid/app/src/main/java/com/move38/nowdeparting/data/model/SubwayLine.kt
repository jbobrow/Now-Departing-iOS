package com.move38.nowdeparting.data.model

import androidx.compose.ui.graphics.Color
import kotlinx.serialization.Serializable

@Serializable
data class SubwayLine(
    val id: String,
    val label: String,
    val bgColor: Long,
    val fgColor: Long
) {
    val backgroundColor: Color get() = Color(bgColor)
    val foregroundColor: Color get() = Color(fgColor)
}

object SubwayConfiguration {
    // Official MTA color scheme for all 23 lines
    private val lineColors = mapOf(
        "1" to Pair(0xFFEE352E, 0xFFFFFFFF),
        "2" to Pair(0xFFEE352E, 0xFFFFFFFF),
        "3" to Pair(0xFFEE352E, 0xFFFFFFFF),
        "4" to Pair(0xFF00933C, 0xFFFFFFFF),
        "5" to Pair(0xFF00933C, 0xFFFFFFFF),
        "6" to Pair(0xFF00933C, 0xFFFFFFFF),
        "6X" to Pair(0xFF00933C, 0xFFFFFFFF),
        "7" to Pair(0xFFB933AD, 0xFFFFFFFF),
        "7X" to Pair(0xFFB933AD, 0xFFFFFFFF),
        "A" to Pair(0xFF0039A6, 0xFFFFFFFF),
        "C" to Pair(0xFF0039A6, 0xFFFFFFFF),
        "E" to Pair(0xFF0039A6, 0xFFFFFFFF),
        "B" to Pair(0xFFFF6319, 0xFFFFFFFF),
        "D" to Pair(0xFFFF6319, 0xFFFFFFFF),
        "F" to Pair(0xFFFF6319, 0xFFFFFFFF),
        "FX" to Pair(0xFFFF6319, 0xFFFFFFFF),
        "M" to Pair(0xFFFF6319, 0xFFFFFFFF),
        "G" to Pair(0xFF6CBE45, 0xFFFFFFFF),
        "J" to Pair(0xFF996633, 0xFFFFFFFF),
        "Z" to Pair(0xFF996633, 0xFFFFFFFF),
        "L" to Pair(0xFFA7A9AC, 0xFF000000),
        "N" to Pair(0xFFFCCC0A, 0xFF000000),
        "Q" to Pair(0xFFFCCC0A, 0xFF000000),
        "R" to Pair(0xFFFCCC0A, 0xFF000000),
        "W" to Pair(0xFFFCCC0A, 0xFF000000),
        "S" to Pair(0xFF808183, 0xFFFFFFFF),
        "SI" to Pair(0xFF0039A6, 0xFFFFFFFF),
        "SIR" to Pair(0xFF0039A6, 0xFFFFFFFF)
    )

    fun getSubwayLine(id: String): SubwayLine {
        val colors = lineColors[id] ?: Pair(0xFF808183, 0xFFFFFFFF)
        return SubwayLine(
            id = id,
            label = id.replace("X", ""),
            bgColor = colors.first,
            fgColor = colors.second
        )
    }

    // Ordered for 4-column grid display: [1,2,3,X], [4,5,6,7], [A,C,E,G], [B,D,F,M], [N,Q,R,W], [J,Z,L,X]
    // "X" is an invisible spacer
    val allLines: List<SubwayLine> = listOf(
        "1", "2", "3", "X",
        "4", "5", "6", "7",
        "A", "C", "E", "G",
        "B", "D", "F", "M",
        "N", "Q", "R", "W",
        "J", "Z", "L", "X"
    ).map { getSubwayLine(it) }

    // Check if a line is a spacer (invisible)
    fun isSpacer(id: String): Boolean = id == "X"

    // Lines grouped by color family for grid display
    val redLines = listOf("1", "2", "3").map { getSubwayLine(it) }
    val greenLines = listOf("4", "5", "6").map { getSubwayLine(it) }
    val purpleLine = listOf("7").map { getSubwayLine(it) }
    val blueLines = listOf("A", "C", "E").map { getSubwayLine(it) }
    val orangeLines = listOf("B", "D", "F", "M").map { getSubwayLine(it) }
    val limeGreenLine = listOf("G").map { getSubwayLine(it) }
    val brownLines = listOf("J", "Z").map { getSubwayLine(it) }
    val grayLine = listOf("L").map { getSubwayLine(it) }
    val yellowLines = listOf("N", "Q", "R", "W").map { getSubwayLine(it) }
    val shuttleLine = listOf("S").map { getSubwayLine(it) }
}
