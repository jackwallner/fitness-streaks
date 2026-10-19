package com.jackwallner.streaks

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import com.jackwallner.streaks.ui.RootScreen
import com.jackwallner.streaks.ui.screens.PrivacyScreen
import com.jackwallner.streaks.ui.theme.StreakTheme

class MainActivity: ComponentActivity() {
    private val graph get()=(application as StreaksApplication).graph
    override fun onCreate(savedInstanceState: Bundle?){super.onCreate(savedInstanceState);enableEdgeToEdge();DebugLaunchOptions.apply(this,graph,intent);if(!graph.review.automation){graph.review.launch();graph.diagnostics.recordAppOpen()};setContent{RootScreen(graph)}}
    override fun onNewIntent(intent: Intent){super.onNewIntent(intent);setIntent(intent);DebugLaunchOptions.apply(this,graph,intent)}
    override fun onResume(){super.onResume();lifecycleScope.launch{graph.store.start()};lifecycleScope.launch{graph.health.refresh()}}
}
class PermissionsRationaleActivity: ComponentActivity(){override fun onCreate(savedInstanceState: Bundle?){super.onCreate(savedInstanceState);setContent{StreakTheme(false){PrivacyScreen()}}}}
