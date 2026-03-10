package com.move38.nowdeparting

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.move38.nowdeparting.navigation.WearNavigation
import com.move38.nowdeparting.ui.theme.WearTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class WearMainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            WearTheme {
                WearNavigation()
            }
        }
    }
}
