package com.move38.nowdeparting.navigation

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.wear.compose.material.HorizontalPageIndicator
import androidx.wear.compose.material.PageIndicatorState
import com.move38.nowdeparting.ui.screens.favorites.WearFavoritesScreen
import com.move38.nowdeparting.ui.screens.lines.WearLinesScreen
import com.move38.nowdeparting.ui.screens.nearby.WearNearbyScreen

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun WearHomeScreen(
    onNavigateToTimes: (lineId: String, stationName: String, stationDisplay: String, direction: String) -> Unit
) {
    val pageCount = 3
    val pagerState = rememberPagerState(initialPage = 0, pageCount = { pageCount })

    val pageIndicatorState = object : PageIndicatorState {
        override val pageOffset: Float get() = pagerState.currentPageOffsetFraction
        override val selectedPage: Int get() = pagerState.currentPage
        override val pageCount: Int get() = pageCount
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black),
        contentAlignment = Alignment.Center
    ) {
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.fillMaxSize()
        ) { page ->
            when (page) {
                0 -> WearNearbyScreen(onTrainClick = { train ->
                    onNavigateToTimes(train.lineId, train.stationName, train.stationDisplay, train.direction)
                })
                1 -> WearLinesScreen(onStationSelected = { lineId, station, direction ->
                    onNavigateToTimes(lineId, station.name, station.displayName, direction)
                })
                2 -> WearFavoritesScreen(onFavoriteClick = { favorite ->
                    onNavigateToTimes(favorite.lineId, favorite.stationName, favorite.stationDisplay, favorite.direction)
                })
            }
        }

        HorizontalPageIndicator(
            pageIndicatorState = pageIndicatorState,
            modifier = Modifier.align(Alignment.BottomCenter)
        )
    }
}
