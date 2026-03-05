package com.move38.nowdeparting.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStore

/**
 * Singleton holder for the favorites DataStore.
 * This ensures both FavoritesRepository and NowDepartingWidget
 * use the same DataStore instance, avoiding caching/sync issues.
 */
object FavoritesDataStore {
    private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "favorites")

    fun getInstance(context: Context): DataStore<Preferences> = context.dataStore
}
