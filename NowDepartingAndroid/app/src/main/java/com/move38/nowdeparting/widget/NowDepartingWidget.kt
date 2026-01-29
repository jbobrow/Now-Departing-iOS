package com.move38.nowdeparting.widget

import android.content.Context
import android.content.Intent
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.*
import androidx.glance.action.ActionParameters
import androidx.glance.action.clickable
import androidx.glance.appwidget.*
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.layout.*
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.move38.nowdeparting.MainActivity
import com.move38.nowdeparting.data.model.FavoriteItem
import com.move38.nowdeparting.data.model.SubwayConfiguration
import com.move38.nowdeparting.data.repository.DirectionHelper
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import java.time.Instant
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.concurrent.TimeUnit
import androidx.compose.ui.graphics.Color as ComposeColor

class NowDepartingWidget : GlanceAppWidget() {

    override val sizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val prefs = context.getSharedPreferences("favorites", Context.MODE_PRIVATE)
        val favoritesJson = prefs.getString("favorites_list", "[]") ?: "[]"

        val favorites = try {
            Json { ignoreUnknownKeys = true }.decodeFromString<List<FavoriteItem>>(favoritesJson)
        } catch (e: Exception) {
            emptyList()
        }

        val firstFavorite = favorites.firstOrNull()
        var nextTrainMinutes: Long? = null

        if (firstFavorite != null) {
            nextTrainMinutes = fetchNextTrainTime(
                firstFavorite.lineId,
                firstFavorite.stationName,
                firstFavorite.direction
            )
        }

        provideContent {
            WidgetContent(
                context = context,
                favorite = firstFavorite,
                nextTrainMinutes = nextTrainMinutes
            )
        }
    }

    private suspend fun fetchNextTrainTime(
        lineId: String,
        stationName: String,
        direction: String
    ): Long? = withContext(Dispatchers.IO) {
        try {
            val client = OkHttpClient.Builder()
                .connectTimeout(10, TimeUnit.SECONDS)
                .readTimeout(10, TimeUnit.SECONDS)
                .build()

            val request = Request.Builder()
                .url("https://api.wheresthefuckingtrain.com/by-route/$lineId")
                .build()

            val response = client.newCall(request).execute()
            val body = response.body?.string() ?: return@withContext null

            // Parse JSON manually to find train times
            val json = Json { ignoreUnknownKeys = true }
            val responseMap = json.decodeFromString<Map<String, Map<String, List<Map<String, String>>>>>(body)
            val stationData = responseMap[stationName] ?: return@withContext null
            val trains = stationData[direction] ?: return@withContext null

            val now = Instant.now()
            for (train in trains) {
                val timeStr = train["time"] ?: continue
                val route = train["route"] ?: continue
                if (route != lineId) continue

                val arrivalTime = try {
                    ZonedDateTime.parse(timeStr, DateTimeFormatter.ISO_OFFSET_DATE_TIME).toInstant()
                } catch (e: Exception) {
                    continue
                }

                if (arrivalTime.isAfter(now.minusSeconds(60))) {
                    return@withContext ChronoUnit.MINUTES.between(now, arrivalTime).coerceAtLeast(0)
                }
            }

            null
        } catch (e: Exception) {
            null
        }
    }
}

@Composable
private fun WidgetContent(
    context: Context,
    favorite: FavoriteItem?,
    nextTrainMinutes: Long?
) {
    val size = LocalSize.current
    val intent = Intent(context, MainActivity::class.java)

    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(ColorProvider(ComposeColor.Black))
            .cornerRadius(16.dp)
            .clickable(actionStartActivity(intent)),
        contentAlignment = Alignment.Center
    ) {
        if (favorite == null) {
            Text(
                text = "Add a favorite",
                style = TextStyle(
                    color = ColorProvider(ComposeColor.White),
                    fontSize = 14.sp
                )
            )
        } else {
            val lineColors = SubwayConfiguration.getSubwayLine(favorite.lineId)
            val destination = DirectionHelper.getDestination(favorite.lineId, favorite.direction)

            Column(
                modifier = GlanceModifier
                    .fillMaxSize()
                    .padding(12.dp),
                horizontalAlignment = Alignment.Start,
                verticalAlignment = Alignment.Top
            ) {
                // Line badge and station
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Line badge
                    Box(
                        modifier = GlanceModifier
                            .size(32.dp)
                            .background(ColorProvider(ComposeColor(lineColors.bgColor)))
                            .cornerRadius(16.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = lineColors.label,
                            style = TextStyle(
                                color = ColorProvider(ComposeColor(lineColors.fgColor)),
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold
                            )
                        )
                    }

                    Spacer(modifier = GlanceModifier.width(8.dp))

                    Column(modifier = GlanceModifier.defaultWeight()) {
                        Text(
                            text = favorite.stationDisplay.ifEmpty { favorite.stationName },
                            style = TextStyle(
                                color = ColorProvider(ComposeColor.White),
                                fontSize = 12.sp,
                                fontWeight = FontWeight.Medium
                            ),
                            maxLines = 1
                        )
                        Text(
                            text = "to $destination",
                            style = TextStyle(
                                color = ColorProvider(ComposeColor(0xFF8E8E93)),
                                fontSize = 10.sp
                            ),
                            maxLines = 1
                        )
                    }
                }

                Spacer(modifier = GlanceModifier.defaultWeight())

                // Time display
                val timeText = when {
                    nextTrainMinutes == null -> "--"
                    nextTrainMinutes == 0L -> "Now"
                    nextTrainMinutes == 1L -> "1 min"
                    else -> "$nextTrainMinutes min"
                }

                Text(
                    text = timeText,
                    style = TextStyle(
                        color = ColorProvider(
                            if (nextTrainMinutes != null && nextTrainMinutes <= 1)
                                ComposeColor(0xFFFF9500)
                            else
                                ComposeColor.White
                        ),
                        fontSize = if (size.width > 150.dp) 36.sp else 28.sp,
                        fontWeight = FontWeight.Bold
                    )
                )
            }
        }
    }
}

class NowDepartingWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = NowDepartingWidget()
}

class RefreshAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        NowDepartingWidget().update(context, glanceId)
    }
}
