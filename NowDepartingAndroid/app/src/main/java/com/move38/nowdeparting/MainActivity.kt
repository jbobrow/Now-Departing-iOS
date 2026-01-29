package com.move38.nowdeparting

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.NearMe
import androidx.compose.material.icons.filled.Train
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.NearMe
import androidx.compose.material.icons.outlined.Train
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.move38.nowdeparting.data.model.NearbyTrain
import com.move38.nowdeparting.ui.screens.favorites.FavoritesScreen
import com.move38.nowdeparting.ui.screens.lines.LinesScreen
import com.move38.nowdeparting.ui.screens.nearby.NearbyScreen
import com.move38.nowdeparting.ui.screens.times.TimesScreen
import com.move38.nowdeparting.ui.theme.NowDepartingTheme
import dagger.hilt.android.AndroidEntryPoint
import java.net.URLDecoder
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            NowDepartingTheme {
                MainScreen()
            }
        }
    }
}

sealed class BottomNavItem(
    val route: String,
    val title: String,
    val selectedIcon: ImageVector,
    val unselectedIcon: ImageVector
) {
    object Nearby : BottomNavItem("nearby", "Nearby", Icons.Filled.NearMe, Icons.Outlined.NearMe)
    object Lines : BottomNavItem("lines", "Lines", Icons.Filled.Train, Icons.Outlined.Train)
    object Favorites : BottomNavItem("favorites", "Favorites", Icons.Filled.Favorite, Icons.Outlined.FavoriteBorder)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen() {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    val bottomNavItems = listOf(
        BottomNavItem.Nearby,
        BottomNavItem.Lines,
        BottomNavItem.Favorites
    )

    // Determine if we should show the bottom bar
    val showBottomBar = bottomNavItems.any { it.route == currentRoute }

    Scaffold(
        bottomBar = {
            if (showBottomBar) {
                NavigationBar(
                    containerColor = Color(0xFF1C1C1E)
                ) {
                    bottomNavItems.forEach { item ->
                        val isSelected = currentRoute == item.route
                        NavigationBarItem(
                            selected = isSelected,
                            onClick = {
                                if (currentRoute != item.route) {
                                    navController.navigate(item.route) {
                                        popUpTo(navController.graph.startDestinationId) {
                                            saveState = true
                                        }
                                        launchSingleTop = true
                                        restoreState = true
                                    }
                                }
                            },
                            icon = {
                                Icon(
                                    imageVector = if (isSelected) item.selectedIcon else item.unselectedIcon,
                                    contentDescription = item.title
                                )
                            },
                            label = { Text(item.title) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = Color.White,
                                selectedTextColor = Color.White,
                                unselectedIconColor = Color(0xFF8E8E93),
                                unselectedTextColor = Color(0xFF8E8E93),
                                indicatorColor = Color(0xFF3A3A3C)
                            )
                        )
                    }
                }
            }
        },
        containerColor = Color.Black
    ) { paddingValues ->
        NavHost(
            navController = navController,
            startDestination = BottomNavItem.Nearby.route,
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            composable(BottomNavItem.Nearby.route) {
                NearbyScreen(
                    onTrainClick = { train ->
                        navController.navigateToTimes(
                            lineId = train.lineId,
                            stationName = train.stationName,
                            stationDisplay = train.stationDisplay,
                            direction = train.direction
                        )
                    }
                )
            }

            composable(BottomNavItem.Lines.route) {
                LinesScreen(
                    onStationSelected = { lineId, station, direction ->
                        navController.navigateToTimes(
                            lineId = lineId,
                            stationName = station.name,
                            stationDisplay = station.displayName,
                            direction = direction
                        )
                    }
                )
            }

            composable(BottomNavItem.Favorites.route) {
                FavoritesScreen(
                    onFavoriteClick = { favorite ->
                        navController.navigateToTimes(
                            lineId = favorite.lineId,
                            stationName = favorite.stationName,
                            stationDisplay = favorite.stationDisplay,
                            direction = favorite.direction
                        )
                    }
                )
            }

            composable(
                route = "times/{lineId}/{stationName}/{stationDisplay}/{direction}",
                arguments = listOf(
                    navArgument("lineId") { type = NavType.StringType },
                    navArgument("stationName") { type = NavType.StringType },
                    navArgument("stationDisplay") { type = NavType.StringType },
                    navArgument("direction") { type = NavType.StringType }
                )
            ) {
                TimesScreen(
                    onBack = { navController.popBackStack() }
                )
            }
        }
    }
}

private fun androidx.navigation.NavController.navigateToTimes(
    lineId: String,
    stationName: String,
    stationDisplay: String,
    direction: String
) {
    val encodedStationName = URLEncoder.encode(stationName, StandardCharsets.UTF_8.toString())
    val encodedStationDisplay = URLEncoder.encode(stationDisplay, StandardCharsets.UTF_8.toString())
    navigate("times/$lineId/$encodedStationName/$encodedStationDisplay/$direction")
}
