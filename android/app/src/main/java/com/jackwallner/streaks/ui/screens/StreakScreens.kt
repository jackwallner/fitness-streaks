package com.jackwallner.streaks.ui.screens

import java.time.LocalDate
import java.time.format.DateTimeFormatter
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import com.jackwallner.streaks.AppGraph
import com.jackwallner.streaks.model.*
import com.jackwallner.streaks.ui.*
import com.jackwallner.streaks.ui.theme.*

@Composable fun Dashboard(g: AppGraph,detail: (String)->Unit,picker: ()->Unit,upgrade: ()->Unit,connect: ()->Unit,broken: (String)->Unit){
    val p=LocalPalette.current;val scope=rememberCoroutineScope();val store by g.store.state.collectAsState()
    ScrollPage {
        g.health.message?.let{PixelPanel(accent=p.amber){Label(it,color=p.amber,size=12);PixelButton("HEALTH SETTINGS",onClick=connect)}}
        g.settings.broken.forEach{b->PixelButton("STREAK ENDED · ${b.length}-DAY ${Catalog.metric(b.metric).androidName.uppercase()}",onClick={broken(b.key)})}
        if(g.streaks.isEmpty()) {EmptyState("NO ACTIVE STREAKS","Connect Health Connect, refresh after activity, or build a custom streak to start.");PixelButton("REQUEST HEALTH ACCESS",onClick=connect)}
        g.streaks.forEachIndexed {i,s->
            if(i==1)Section("OTHER STREAKS · ${g.streaks.size-1} ACTIVE")
            StreakCard(s,i==0){detail(s.key)}
            if(!s.completed&&s.current>0)PixelButton("! AT RISK · ${if(store.isPro)"AUTO-SAVE ON" else "UNLOCK AUTO-SAVE"}",onClick={if(store.isPro)detail(s.key)else upgrade()})
        }
        PixelButton("+ FIND MORE STREAKS",onClick=picker)
        PixelButton(if(g.health.loading)"REFRESHING..."else"REFRESH",enabled=!g.health.loading,onClick={scope.launch{g.health.refresh()}})
    }
}
@Composable fun StreakCard(s: Streak,hero: Boolean=false,onClick: ()->Unit){val p=LocalPalette.current;val accent=p.accent(s.metric)
    PixelPanel(Modifier.clickable(onClick=onClick),accent){
        Label((if(hero)"YOUR HERO · "else"")+s.name.uppercase(),bold=true,size=12,color=accent)
        Row(verticalAlignment=androidx.compose.ui.Alignment.Bottom){Label(s.current.toString(),size=if(hero)76 else 42,bold=true,color=accent);Label(" ${if(s.cadence=="weekly")"WEEKS"else"DAYS"}",size=18,color=p.dim,modifier=Modifier.padding(bottom=10.dp))}
        Label(s.label.uppercase(),bold=true,size=14)
        Box(Modifier.fillMaxWidth().height(8.dp).background(p.grid)){Box(Modifier.fillMaxHeight().fillMaxWidth(s.progress.toFloat().coerceIn(0f,1f)).background(accent))}
        Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Label("${s.format(s.value,true)} / ${s.format(s.threshold)} ${s.unit}",size=12,color=p.dim);Label(if(s.completed)"✓ DONE"else"TODAY",size=12,color=accent)}
        Label("BEST ${s.best} · ${(s.rate*100).toInt()}% COMPLETION",size=11,color=p.dim)
    }
}
@Composable fun Detail(g: AppGraph,s: Streak,upgrade: ()->Unit,back: ()->Unit){
    val p=LocalPalette.current;val store by g.store.state.collectAsState();var confirm by remember{mutableStateOf<String?>(null)}
    var range by remember{mutableIntStateOf(30)};var selected by remember{mutableStateOf<Triple<LocalDate,Double,Boolean>?>(null)}
    val history=Engine.history(s,g.health.history,g.health.hourly).takeLast(range)
    ScrollPage {
        StreakCard(s,true){}
        Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){listOf("CURRENT" to s.current.toString(),"RECORD" to s.best.toString(),"RATE" to "${(s.rate*100).toInt()}%").forEach{(title,value)->Column{Section(title);Label(value,size=24,bold=true)}}}
        Label("Started: ${s.start?:"No active run"}\nLast hit: ${s.lastHit?:"None yet"}\nLast missed: ${s.lastMissed?:"None found"}",size=12,color=p.dim)
        Section("HISTORY")
        if(store.isPro){
            Row {listOf(30,90,365).forEach{days->TextButton(onClick={range=days}){Label("${days}D",color=if(range==days)p.lime else p.dim)}}}
            history.chunked(7).forEach {week->Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(5.dp)){week.forEach{entry->Box(Modifier.weight(1f).aspectRatio(1f).background(if(entry.third)p.accent(s.metric)else p.grid).semantics{contentDescription="${entry.first}: ${s.format(entry.second,true)} ${s.unit}, ${if(entry.third)"met"else"missed"}"}.clickable{selected=entry})};repeat(7-week.size){Spacer(Modifier.weight(1f))}}}
            selected?.let{Label("${it.first}: ${s.format(it.second,true)} ${s.unit} · ${if(it.third)"MET"else"MISSED"}",size=12)}
            val hits=history.count{it.third};Label("$hits HITS · ${if(history.isEmpty())"0.0"else String.format(java.util.Locale.US,"%.1f",hits.toDouble()/history.size*7)} / WK",color=p.dim,size=12)
            Section("BY DAY OF WEEK")
            (1..7).forEach {day->val rows=history.filter{it.first.dayOfWeek.value==day};Label("${java.time.DayOfWeek.of(day).name.take(3)}  ${rows.count{it.third}} / ${rows.size} HITS",size=12)}
        }else PixelPanel{Label("■ HISTORY · STREAKS+",bold=true);Label("See the whole chain. Unlock your history and calendar heatmap.",color=p.dim);PixelButton("UNLOCK WITH STREAKS+",primary=true,onClick=upgrade)}
        Section("ACTIONS")
        PixelButton(if(g.settings.order.firstOrNull()==s.key)"PRIMARY"else"MAKE PRIMARY"){g.settings.primary(s.key);g.recompute()}
        PixelButton("RECALIBRATE"){confirm="recalibrate"}
        PixelButton("UNTRACK STREAK"){confirm="untrack"}
        if(s.customID!=null){var goal by remember(s.threshold){mutableStateOf(s.threshold.toString())};OutlinedTextField(goal,{goal=it},label={Text("Custom daily goal")},singleLine=true,modifier=Modifier.fillMaxWidth());PixelButton("SAVE CUSTOM GOAL",enabled=goal.toDoubleOrNull()?.let{it.isFinite()&&it>0}==true){val custom=g.settings.custom.firstOrNull{it.id==s.customID};if(custom!=null){g.settings.custom(custom.copy(threshold=goal.toDouble()),store.isPro);g.recompute()}};PixelButton("DELETE CUSTOM STREAK"){confirm="delete"}}
        if(store.isPro){Section("THRESHOLD TIERS");Catalog.metric(s.metric).thresholds.forEach{t->val r=Engine.daily(s.metric,t,g.health.history.associate{it.date to it.value(s.metric)},LocalDate.now());Label("${Catalog.metric(s.metric).format(t)} ${s.unit} · ${r.current} / best ${r.best}",size=12)}}
    }
    confirm?.let{action->AlertDialog(onDismissRequest={confirm=null},title={Label(if(action=="recalibrate")"RECALIBRATE GOAL?"else"REMOVE STREAK?",bold=true)},text={Label(if(action=="recalibrate")"This re-analyzes your recent activity and may change your goal. A higher goal may break your streak."else"It will disappear from your dashboard. Your Health Connect data is unchanged.")},confirmButton={TextButton(onClick={when(action){"recalibrate"->{g.settings.recalibrate(s.key);g.recompute()};"delete"->{g.settings.deleteCustom(s.customID!!);g.recompute();back()};else->{g.track(g.settings.tracked-s.key);back()}};confirm=null}){Label("CONFIRM",color=p.red)}},dismissButton={TextButton(onClick={confirm=null}){Label("CANCEL")}})}
}
@Composable fun SavesScreen(g: AppGraph,upgrade: ()->Unit,freeze: ()->Unit){val p=LocalPalette.current;val store by g.store.state.collectAsState()
    ScrollPage {PixelPanel(accent=if(store.isPro)p.lime else p.magenta){Label(if(store.isPro)"AUTO-SAVE ON"else"AUTO-SAVE LOCKED",size=22,bold=true);Label(if(store.isPro)"Missed days are saved automatically when fresh health data arrives. Keep the chain alive."else"Streaks+ auto-saves your streaks when a day slips.",color=p.dim);if(!store.isPro)PixelButton("UNLOCK STREAKS+",primary=true,onClick=upgrade)}
        Section("RECENT SAVES");if(g.settings.preservations.isEmpty())Label("No saves yet.",color=p.dim)
        g.settings.preservations.values.sortedByDescending{it.granted}.forEach{p->PixelPanel{Label("${Catalog.metric(p.metric).androidName.uppercase()} · ${p.length}-DAY RUN",bold=true);Label(p.granted.toString())}}
        Section("PLANNED FREEZES");Label("Days you mark won't break or extend a streak.",color=p.dim)
        g.settings.freezes.sorted().forEach{day->PixelButton("$day · REMOVE"){if(store.isPro){g.settings.freeze(day,true);g.recompute()}else upgrade()}}
        if(g.settings.freezes.isEmpty())Label("No freeze days set.",color=p.dim)
        PixelButton("ADD FREEZE DAY",onClick=if(store.isPro)freeze else upgrade)
    }
}
@Composable fun StatsScreen(g: AppGraph,detail: (String)->Unit){val p=LocalPalette.current
    ScrollPage {if(g.streaks.isEmpty())EmptyState("NO STATS YET","Find some streaks on the Streaks tab and your stats will show up here.")
        else {PixelPanel{Label("${g.streaks.count{it.current>0}} ACTIVE STREAKS",size=24,bold=true,color=p.lime);Label("${g.streaks.sumOf{it.current}} DAYS COMBINED",size=20,color=p.magenta);Label("${g.streaks.maxOfOrNull{it.best}?:0} PERSONAL BEST",size=20,color=p.amber)}
            Section("ACROSS ALL STREAKS");Label("AVG COMPLETION  ${(g.streaks.map{it.rate}.average()*100).toInt()}%",bold=true);Label("STREAKS+ SAVES TO DATE  ${g.settings.preservations.size}",bold=true)
            Section("STREAK BREAKDOWN");g.streaks.forEach{s->PixelButton("${s.name.uppercase()} · ${s.current} DAYS"){detail(s.key)};Label("best ${s.best} · ${(s.rate*100).toInt()}%",color=p.dim)}
        }
    }
}
@Composable fun FreezeEditor(g: AppGraph,back: ()->Unit,upgrade: ()->Unit){var text by remember{mutableStateOf(LocalDate.now().plusDays(1).toString())};var error by remember{mutableStateOf<String?>(null)}
    ScrollPage {Label("PLAN A BREAK.",size=28,bold=true);Label("Freeze travel or rest days without breaking your chain.");OutlinedTextField(text,{text=it},label={Text("Date (YYYY-MM-DD)")},singleLine=true,modifier=Modifier.fillMaxWidth());error?.let{Label(it,color=LocalPalette.current.red)};PixelButton("SAVE FREEZE DAY",primary=true){val day=runCatching{LocalDate.parse(text)}.getOrNull();if(day==null||day<LocalDate.now())error="Choose today or a future date."else if(!g.settings.freeze(day,g.store.current.isPro))upgrade()else{g.recompute();back()}}}
}
@Composable fun BrokenScreen(g: AppGraph,b: BrokenStreak,upgrade: ()->Unit,pick: ()->Unit,back: ()->Unit){val store by g.store.state.collectAsState()
    ScrollPage{Label("STREAK ENDED",size=28,bold=true);Label("Your ${Catalog.metric(b.metric).androidName.lowercase()} run ended at ${b.length} days.");PixelButton("KEEP SAME GOAL"){g.settings.dismissBroken(b.key);back()};PixelButton("PICK A NEW GOAL",onClick=pick);if(b.broken>=LocalDate.now().minusDays(1))PixelButton(if(store.isPro)"REVIVE STREAK"else"REVIVE WITH STREAKS+",primary=true){if(store.isPro){g.revive(b);back()}else upgrade()};PixelButton("CLOSE",onClick=back)}
}
