package com.jackwallner.streaks.ui

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.health.connect.client.PermissionController
import com.google.android.play.core.review.ReviewManagerFactory
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import com.jackwallner.streaks.AppGraph
import com.jackwallner.streaks.data.*
import com.jackwallner.streaks.model.*
import com.jackwallner.streaks.ui.nav.Navigation
import com.jackwallner.streaks.ui.screens.*
import com.jackwallner.streaks.ui.theme.*

@Composable fun RootScreen(g: AppGraph) {
    val store by g.store.state.collectAsState()
    val dark=when(g.settings.appearance){0->false;1->true;else->isSystemInDarkTheme()}
    StreakTheme(dark){
        val nav=rememberSaveable(saver=Navigation.saver){Navigation()};val scope=rememberCoroutineScope();val context=LocalContext.current;val view=androidx.compose.ui.platform.LocalView.current
        SideEffect{val activity=findActivity(context);if(activity!=null){androidx.core.view.WindowCompat.getInsetsController(activity.window,view).isAppearanceLightStatusBars=!dark;androidx.core.view.WindowCompat.getInsetsController(activity.window,view).isAppearanceLightNavigationBars=!dark}}
        var onboardingPhase by rememberSaveable{mutableStateOf("intro")}
        var selected by rememberSaveable{mutableStateOf(emptyList<String>())}
        var paywall by rememberSaveable{mutableStateOf(false)}
        var permissionRequested by rememberSaveable{mutableStateOf(false)}
        var error by remember{mutableStateOf<String?>(null)}
        val permissions=rememberLauncherForActivityResult(PermissionController.createRequestPermissionResultContract()){scope.launch{g.health.refresh();if(!g.settings.setup){selected=g.candidates.map{it.key};onboardingPhase=if(g.candidates.isEmpty())"empty"else"select"}}}
        val notifications=rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()){granted->g.settings.notifications(granted);Reminders.schedule(context,g.settings,store.isPro)}
        fun connect(){if(g.health.available){permissionRequested=true;permissions.launch(g.health.requested())}else runCatching{context.startActivity(g.health.settingsIntent())}.onFailure{error="Health Connect isn't available on this device."}}
        fun showPaywall(){paywall=true;scope.launch{g.store.fetchProducts()}}
        BackHandler(paywall||nav.route!="home"){if(paywall){paywall=false;if(!g.settings.setup&&onboardingPhase=="trial")g.finish(selected)}else nav.back()}
        LaunchedEffect(g.pendingRoute){g.pendingRoute?.let{nav.push(it);g.pendingRoute=null}}
        LaunchedEffect(store.isPro){if(store.isPro){if(!g.settings.setup&&onboardingPhase=="trial")g.finish(selected);paywall=false}}
        LaunchedEffect(g.streaks,nav.route,paywall,g.settings.setup){if(g.review.eligible(g.settings.setup,paywall||nav.route!="home")){delay(3500);if(g.review.eligible(g.settings.setup,paywall||nav.route!="home")){val manager=ReviewManagerFactory.create(context);manager.requestReviewFlow().addOnSuccessListener{info->if(g.review.eligible(g.settings.setup,paywall||nav.route!="home")){g.review.shown();manager.launchReviewFlow(context as Activity,info)}}}}}
        Surface(Modifier.fillMaxSize(),color=LocalPalette.current.bg){
            if(!g.settings.setup&&!paywall) {
                Onboarding(g,onboardingPhase,selected,{selected=it},{onboardingPhase=it},{connect()},{onboardingPhase="trial";showPaywall()})
            }else if(paywall)Paywall(g,context as Activity,{paywall=false;if(!g.settings.setup)g.finish(selected)})
            else Column(Modifier.fillMaxSize().safeDrawingPadding()) {
                val p=LocalPalette.current
                Row(Modifier.fillMaxWidth().padding(18.dp),verticalAlignment=Alignment.CenterVertically){
                    if(nav.route!="home")TextButton(onClick={nav.back()}){Label("‹ BACK",color=p.cyan)}
                    Column(Modifier.weight(1f)){Label(if(nav.route=="home")listOf("▶ STREAK FINDER","SAVES","STATS")[nav.tab] else nav.route.substringBefore(':').uppercase(),bold=true,size=16);if(nav.route=="home")Label(if(g.health.loading)"reading health..."else"from health connect",size=11,color=p.dim)}
                    if(nav.route=="home"&&nav.tab==0)TextButton(onClick={nav.push("settings")}){Label("SETTINGS",size=11,color=p.cyan)}
                }
                Box(Modifier.weight(1f)) {
                    when {
                        nav.route.startsWith("detail:")->g.candidates.firstOrNull{it.key==nav.route.removePrefix("detail:")}?.let{s->Detail(g,s,{showPaywall()},{nav.back()})}?:EmptyState("STREAK UNAVAILABLE","Refresh Health Connect or reconnect this activity type.")
                        nav.route=="settings"->SettingsScreen(g,{nav.push(it)},{showPaywall()},{connect()},{if(store.isPro){if(Build.VERSION.SDK_INT>=33)notifications.launch(Manifest.permission.POST_NOTIFICATIONS)else g.settings.notifications(true)}else showPaywall()})
                        nav.route=="picker"->Picker(g,{nav.push("custom")},{showPaywall()},{nav.back()})
                        nav.route=="custom"->CustomEditor(g,{nav.back()},{showPaywall()})
                        nav.route=="privacy"->PrivacyScreen()
                        nav.route=="tutorial"->TutorialScreen{g.values.put("hasSeenTutorial","true");nav.back()}
                        nav.route=="freeze"->FreezeEditor(g,{nav.back()},{showPaywall()})
                        nav.route.startsWith("broken:")->g.settings.broken.firstOrNull{it.key==nav.route.removePrefix("broken:")}?.let{BrokenScreen(g,it,{showPaywall()},{nav.push("picker")},{nav.back()})}
                        nav.tab==0->Dashboard(g,{nav.push("detail:$it")},{nav.push("picker")},{showPaywall()},{connect()},{nav.push("broken:$it")})
                        nav.tab==1->SavesScreen(g,{showPaywall()},{nav.push("freeze")})
                        else->StatsScreen(g,{nav.push("detail:$it")})
                    }
                }
                Row(Modifier.fillMaxWidth().border(2.dp,p.grid).background(p.raised)) {listOf("STREAKS","SAVES","STATS").forEachIndexed{i,title->TextButton(onClick={nav.select(i)},modifier=Modifier.weight(1f).heightIn(min=54.dp)){Label(title,size=12,bold=true,color=if(nav.tab==i)p.lime else p.dim)}}}
            }
        }
        error?.let{AlertDialog(onDismissRequest={error=null},title={Text("Health Connect")},text={Text(it)},confirmButton={TextButton(onClick={error=null}){Text("OK")}})}
    }
}
@Composable fun ScrollPage(content: @Composable ColumnScope.()->Unit){Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal=20.dp).padding(bottom=28.dp),verticalArrangement=Arrangement.spacedBy(18.dp),content=content)}
@Composable fun EmptyState(title: String,detail: String){PixelPanel{Label(title,bold=true,size=18);Label(detail,color=LocalPalette.current.dim)}}
