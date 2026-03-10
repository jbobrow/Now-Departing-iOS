package com.move38.nowdeparting.navigation

import androidx.compose.runtime.Composable
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import com.move38.nowdeparting.ui.screens.favorites.WearFavoritesScreen
import com.move38.nowdeparting.ui.screens.lines.WearLinesScreen
import com.move38.nowdeparting.ui.screens.nearby.WearNearbyScreen
import com.move38.nowdeparting.ui.screens.times.WearTimesScreen

object WearRoutes {
    const val HOME = "home"
    const val TIMES = "times/{lineId}/{stationName}/{stationDisplay}/{direction}"

    fun timesRoute(lineId: String, stationName: String, stationDisplay: String, direction: String): String {
        val encodedStation = java.net.URLEncoder.encode(stationName, "UTF-8")
        val encodedDisplay = java.net.URLEncoder.encode(stationDisplay, "UTF-8")
        return "times/$lineId/$encodedStation/$encodedDisplay/$direction"
    }
}

@Composable
fun WearNavigation() {
    val navController = rememberSwipeDismissableNavController()

    SwipeDismissableNavHost(
        navController = navController,
        startDestination = WearRoutes.HOME
    ) {
        composable(WearRoutes.HOME) {
            WearHomeScreen(
                onNavigateToTimes = { lineId, stationName, stationDisplay, direction ->
                    navController.navigate(
                        WearRoutes.timesRoute(lineId, stationName, stationDisplay, direction)
                    )
                }
            )
        }

        composable(WearRoutes.TIMES) {
            WearTimesScreen(
                onBack = { navController.popBackStack() }
            )
        }
    }
}
