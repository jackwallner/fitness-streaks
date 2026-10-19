package com.jackwallner.streaks.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.jackwallner.streaks.AppGraph
import com.jackwallner.streaks.ui.ScrollPage
import com.jackwallner.streaks.ui.theme.*

@Composable fun Onboarding(g: AppGraph,phase: String,selection: List<String>,select: (List<String>)->Unit,advance: (String)->Unit,connect: ()->Unit,trial: ()->Unit) {
    val p=LocalPalette.current
    Column(Modifier.fillMaxSize().safeDrawingPadding().padding(22.dp)) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(22.dp)) {
            Label("▶ STREAK FINDER",bold=true,size=16,color=p.magenta)
            when(phase) {
                "intro"->{Spacer(Modifier.height(24.dp));Label("YOU'RE ALREADY\nON A STREAK.",size=34,bold=true);Label("Find the habits hidden in your activity. Keep the chain alive.",size=17,color=p.dim);PixelPanel{Section("FROM HEALTH CONNECT");Label("Steps. Workouts. Sleep. Your daily progress, without manual logging.")};Label("Your activity stays on your device. Read-only access. Choose the types you share.",color=p.dim)}
                "intensity"->{Label("PICK YOUR\nINTENSITY.",size=31,bold=true);Label("We'll find goals that match the challenge you want.",color=p.dim);listOf("SUSTAINED" to "Goals you already hit most days. Turn them into unbroken streaks.","CHALLENGING" to "Goals you hit roughly 2 of 3 days. Push to make them daily.","LIFE CHANGING" to "Goals you hit about half the time. Building the daily habit changes everything.").forEachIndexed{i,(name,detail)->PixelButton((if(g.settings.intensity==i)"■ "else"□ ")+name,onClick={g.settings.intensity(i)});Label(detail,color=p.dim)};Label("Stand hours have no Health Connect equivalent. Workout minutes use recorded sessions. Data availability depends on the apps and devices sharing with Health Connect.",size=12,color=p.dim);TextButton(onClick={advance("empty")}){Label("CONTINUE WITHOUT HEALTH",color=p.cyan,size=12)}}
                "select"->{Label("YOUR STREAKS.\nYOUR CHOICE.",size=30,bold=true);Label("${selection.size} SELECTED · FREE TRACKS 3",color=p.lime);g.candidates.forEach{s->PixelButton((if(s.key in selection)"■ "else"□ ")+"${s.name.uppercase()} · ${s.current} DAYS",onClick={select(if(s.key in selection)selection-s.key else selection+s.key)});Label(s.label,color=p.dim)}}
                else->{Label(if(g.health.loading)"FINDING\nYOUR STREAKS..."else"EVERY CHAIN\nSTARTS HERE.",size=30,bold=true);Label(g.health.message?:"No active streaks yet. Refresh after activity or create your own goal.",color=p.dim);Label("Today stays live until the day ends. Sleep is credited to the day it ends.",color=p.dim);PixelButton("CONNECT HEALTH CONNECT",onClick=connect)}
            }
            Spacer(Modifier.height(10.dp))
        }
        Spacer(Modifier.height(12.dp))
        PixelButton(when(phase){"intro"->"▶ GET STARTED";"intensity"->if(g.health.loading)"CONNECTING..."else"▶ FIND MY STREAKS";"select"->"▶ START · ${selection.size}";else->"▶ CONTINUE"},primary=true,enabled=!g.health.loading&&(phase!="select"||selection.isNotEmpty())){when(phase){"intro"->advance("intensity");"intensity"->connect();"select"->trial();else->g.finish(emptyList())}}
        Row(Modifier.fillMaxWidth().heightIn(min=38.dp),horizontalArrangement=Arrangement.SpaceEvenly){TextButton(onClick={openUrl(g.context,com.jackwallner.streaks.data.Legal.TERMS_URL)}){Label("TERMS",size=11,color=p.dim)};TextButton(onClick={openUrl(g.context,com.jackwallner.streaks.data.Legal.PRIVACY_URL)}){Label("PRIVACY",size=11,color=p.dim)}}
    }
}
