package com.move38.nowdeparting.data.repository

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.appwidget.GlanceAppWidgetManager
import com.move38.nowdeparting.data.FavoritesDataStore
import com.move38.nowdeparting.data.model.FavoriteItem
import com.move38.nowdeparting.widget.NowDepartingWidget
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FavoritesRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val json = Json { ignoreUnknownKeys = true }
    private val favoritesKey = stringPreferencesKey("favorites_list")
    private val dataStore = FavoritesDataStore.getInstance(context)

    val favorites: Flow<List<FavoriteItem>> = dataStore.data.map { preferences ->
        val jsonString = preferences[favoritesKey] ?: "[]"
        try {
            json.decodeFromString<List<FavoriteItem>>(jsonString)
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun addFavorite(favorite: FavoriteItem) {
        dataStore.edit { preferences ->
            val currentList = getCurrentFavorites(preferences)

            // Check for duplicates
            val isDuplicate = currentList.any {
                it.lineId == favorite.lineId &&
                it.stationName == favorite.stationName &&
                it.direction == favorite.direction
            }

            if (!isDuplicate) {
                val newList = currentList + favorite
                preferences[favoritesKey] = json.encodeToString(newList)
            }
        }
        updateWidgets()
    }

    suspend fun removeFavorite(favoriteId: String) {
        dataStore.edit { preferences ->
            val currentList = getCurrentFavorites(preferences)
            val newList = currentList.filter { it.id != favoriteId }
            preferences[favoritesKey] = json.encodeToString(newList)
        }
        updateWidgets()
    }

    suspend fun reorderFavorites(newOrder: List<FavoriteItem>) {
        dataStore.edit { preferences ->
            preferences[favoritesKey] = json.encodeToString(newOrder)
        }
        updateWidgets()
    }

    private suspend fun updateWidgets() {
        try {
            val manager = GlanceAppWidgetManager(context)
            val glanceIds = manager.getGlanceIds(NowDepartingWidget::class.java)
            glanceIds.forEach { glanceId ->
                NowDepartingWidget().update(context, glanceId)
            }
        } catch (e: Exception) {
            // Widget update failed, ignore
        }
    }

    suspend fun isFavorite(lineId: String, stationName: String, direction: String): Boolean {
        var result = false
        dataStore.edit { preferences ->
            val currentList = getCurrentFavorites(preferences)
            result = currentList.any {
                it.lineId == lineId &&
                it.stationName == stationName &&
                it.direction == direction
            }
        }
        return result
    }

    private fun getCurrentFavorites(preferences: Preferences): List<FavoriteItem> {
        val jsonString = preferences[favoritesKey] ?: "[]"
        return try {
            json.decodeFromString(jsonString)
        } catch (e: Exception) {
            emptyList()
        }
    }
}
