package com.jackwallner.streaks.ui.screens

import java.util.UUID
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import com.jackwallner.streaks.AppGraph
import com.jackwallner.streaks.data.*
import com.jackwallner.streaks.model.*
import com.jackwallner.streaks.ui.*
import com.jackwallner.streaks.ui.theme.*

fun openUrl(context: Context,url: String){runCatching{context.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))}}
@Composable fun Paywall(g: AppGraph,activity: Activity,close: ()->Unit){val state by g.store.state.collectAsState();val scope=rememberCoroutineScope();val p=LocalPalette.current
    var selected by remember{mutableStateOf<String?>(null)};var busy by remember{mutableStateOf(false)};var message by remember{mutableStateOf<String?>(null)}
    val plans=state.planOptions.sortedBy{when(it.displayName){"Yearly"->0;"Monthly"->1;else->2}}
    val plan=plans.firstOrNull{it.id==selected}?:plans.firstOrNull()
    LaunchedEffect(Unit){g.store.trackPaywallImpression("streaks_paywall");g.store.fetchProducts()}
    Column(Modifier.fillMaxSize().safeDrawingPadding().padding(20.dp)) {
        Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Label("STREAKS+",size=20,bold=true,color=p.magenta);TextButton(onClick=close,enabled=!busy){Label("CLOSE",color=p.dim)}}
        Column(Modifier.weight(1f).verticalScroll(androidx.compose.foundation.rememberScrollState()),verticalArrangement=Arrangement.spacedBy(16.dp)){
            Label("DON'T BREAK\nTHE STREAK.",size=33,bold=true);Label("Auto-save every streak. Track every habit you build.",color=p.dim)
            PixelPanel(accent=p.magenta){Label("AUTO-SAVES",bold=true);Label("Keep a missed day from ending the chain.",color=p.dim);Label("FREEZE DAYS",bold=true);Label("Plan breaks without breaking the chain.",color=p.dim);Label("AT-RISK ALERTS",bold=true);Label("Heads-up before a streak slips.",color=p.dim);Label("UNLIMITED STREAKS + HISTORY",bold=true)}
            if(state.isLoadingProducts)Label("LOADING PRICES...",color=p.dim)
            plans.forEach{option->PixelButton((if(option.id==plan?.id)"■ "else"□ ")+"${option.displayName.uppercase()} · ${option.priceLabel}",enabled=!busy,onClick={selected=option.id});option.trialLabel?.let{Label(it,color=p.lime)}}
            if(plans.isEmpty()&&!state.isLoadingProducts){Label("PRICES DIDN'T LOAD",bold=true,color=p.amber);Label(state.lastError?:"Check your connection and try again.",color=p.dim);PixelButton("TRY AGAIN"){scope.launch{g.store.fetchProducts()}}}
            message?.let{Label(it,color=p.amber)};state.restoreError?.let{Label(it,color=p.amber)}
        }
        Spacer(Modifier.height(12.dp))
        PixelButton(if(busy)"PLEASE WAIT..."else if(plan?.trialLabel!=null)"START FREE TRIAL"else"UNLOCK STREAKS+",primary=true,enabled=plan!=null&&!busy){scope.launch{busy=true;try{when(g.store.purchase(activity,plan!!)){PurchaseOutcome.PURCHASED->close();PurchaseOutcome.PENDING->message="Purchase pending. Access unlocks after payment completes.";PurchaseOutcome.CANCELLED->message="Purchase wasn't completed."}}catch(e: Exception){if(e is kotlinx.coroutines.CancellationException)throw e;message=e.message?:"Couldn't complete purchase."}finally{busy=false}}}
        plan?.let{Label(if(it.recurring)ConversionCopy.disclosure(it.trialLabel,it.priceLabel,it.trialLabel!=null)else"${it.priceLabel}. One-time purchase. No renewal.",size=10,color=p.dim,modifier=Modifier.padding(top=10.dp))}
        Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceEvenly){TextButton(onClick={openUrl(g.context,Legal.TERMS_URL)}){Label("TERMS",size=11,color=p.dim)};TextButton(onClick={openUrl(g.context,Legal.PRIVACY_URL)}){Label("PRIVACY",size=11,color=p.dim)};TextButton(enabled=!busy,onClick={scope.launch{busy=true;g.store.restorePurchases();if(g.store.current.isPro)close();busy=false}}){Label("RESTORE",size=11,color=p.cyan)}}
        TextButton(onClick=close,enabled=!busy,modifier=Modifier.fillMaxWidth()){Label("CONTINUE WITH FREE",size=12,color=p.dim)}
    }
}
fun findActivity(context: Context): Activity? {var c=context;while(c is android.content.ContextWrapper){if(c is Activity)return c;c=c.baseContext};return null}
@Composable fun SettingsScreen(g: AppGraph,push: (String)->Unit,upgrade: ()->Unit,connect: ()->Unit,notify: ()->Unit){val scope=rememberCoroutineScope();val store by g.store.state.collectAsState();val p=LocalPalette.current;var confirm by remember{mutableStateOf<String?>(null)}
    ScrollPage {
        PixelPanel{Label(if(store.isPro)"STREAKS+ · AUTO-SAVE ON"else"AUTO-SAVE · STREAKS+",bold=true);if(!store.isPro)PixelButton("UNLOCK STREAKS+",primary=true,onClick=upgrade)else PixelButton("MANAGE SUBSCRIPTION"){openUrl(g.context,"https://play.google.com/store/account/subscriptions?package=com.jackwallner.streaks")}}
        Section("APPEARANCE");Row{listOf("LIGHT","DARK","SYSTEM").forEachIndexed{i,name->TextButton(onClick={g.settings.appearance(i)}){Label((if(g.settings.appearance==i)"■ "else"")+name,size=12,color=p.cyan)}}}
        Section("INTENSITY");listOf("SUSTAINED","CHALLENGING","LIFE CHANGING").forEachIndexed{i,name->PixelButton((if(g.settings.intensity==i)"■ "else"□ ")+name){g.settings.intensity(i);g.recompute()}}
        PixelButton("RECALIBRATE ALL GOALS"){confirm="recalibrate"}
        PixelButton("TRACKED STREAKS"){push("picker")}
        Section("DISCOVERY WINDOW · ${g.settings.lookback} DAYS");Row{listOf(7,30,90,180,365).forEach{n->TextButton(onClick={g.settings.lookback(n);g.recompute()}){Label(n.toString(),color=if(g.settings.lookback==n)p.lime else p.dim,size=12)}}};Label("Existing goals stay locked at their committed value.",size=12,color=p.dim)
        Section("PROACTIVE AT-RISK ALERTS");PixelButton(if(g.settings.notifications)"NOTIFICATIONS ON · TURN OFF"else"ENABLE NOTIFICATIONS"){if(g.settings.notifications){g.settings.notifications(false);Reminders.schedule(g.context,g.settings,store.isPro)}else notify()}
        if(store.isPro){var time by remember{mutableStateOf(String.format(java.util.Locale.US,"%02d:%02d",g.settings.notificationHour,g.settings.notificationMinute))};OutlinedTextField(time,{time=it},label={Text("Reminder time (HH:MM)")},singleLine=true,modifier=Modifier.fillMaxWidth());PixelButton("SAVE REMINDER TIME"){val parts=time.split(':').mapNotNull(String::toIntOrNull);if(parts.size==2&&parts[0] in 0..23&&parts[1] in 0..59){g.settings.notifications(g.settings.notifications,parts[0],parts[1]);Reminders.schedule(g.context,g.settings,true)}}}
        Label("Inexact daily nudge if a tracked goal is still waiting. Fresh background data requires optional Health Connect background access.",size=12,color=p.dim)
        Section("METRICS TRACKED");Catalog.metrics.filter{it.key!="earlySteps"}.forEach{m->val available=m.key in g.health.supportedMetrics();PixelButton((if(m.key !in g.settings.hidden&&available)"■ "else"□ ")+m.androidName.uppercase(),enabled=available){g.settings.hidden(if(m.key in g.settings.hidden)g.settings.hidden-m.key else g.settings.hidden+m.key);g.recompute()};if(!available)Label(if(m.key=="standHours")"No equivalent in Health Connect."else"Allow this type in Health Connect, if supported.",size=11,color=p.dim)}
        Section("DATA");PixelButton("REFRESH NOW",enabled=!g.health.loading){scope.launch{g.health.refresh()}};PixelButton("HEALTH CONNECT ACCESS",onClick=connect);PixelButton("HEALTH DATA & PRIVACY"){push("privacy")};PixelButton("DISCONNECT & DELETE LOCAL HEALTH DATA"){confirm="disconnect"}
        Section("PLANNED FREEZES");PixelButton("ADD FREEZE DAY"){if(store.isPro)push("freeze")else upgrade()}
        Section("COACHING");Label("Live 1-on-1 virtual personal training and nutrition coaching with Elsa.");PixelButton("MEET YOUR COACH"){openUrl(g.context,"https://e3fit.me")}
        Section("ABOUT");PixelButton("PRIVACY POLICY"){openUrl(g.context,Legal.PRIVACY_URL)};PixelButton("TERMS"){openUrl(g.context,Legal.TERMS_URL)}
        PixelButton("RATE STREAKS"){g.review.openedReview();openUrl(g.context,Legal.PLAY_LISTING_URL)}
        PixelButton("SEND FEEDBACK"){g.review.feedback();openUrl(g.context,"mailto:${Legal.FEEDBACK_EMAIL}?subject=Streak%20Finder%20Android%20feedback")}
        PixelButton("REPLAY TUTORIAL"){push("tutorial")}
        PixelButton("RESTORE PURCHASES"){scope.launch{g.store.restorePurchases()}};store.restoreError?.let{Label(it,color=p.amber)}
        Label("STREAK FINDER 1.3.1\nREAD-ONLY · HEALTH DATA LOCAL-ONLY\nChanges save automatically.",size=11,color=p.dim)
    }
    confirm?.let{action->AlertDialog(onDismissRequest={confirm=null},title={Label(if(action=="disconnect")"DELETE LOCAL HEALTH DATA?"else"RECALIBRATE ALL GOALS?",bold=true)},text={Label(if(action=="disconnect")"Health Connect records stay in Health Connect. Local health history and saved run data will be cleared."else"New goals may be higher. Your active streak lengths may change.")},confirmButton={TextButton(onClick={if(action=="disconnect")scope.launch{g.health.disconnect()}else{g.settings.committed.keys.toList().forEach(g.settings::recalibrate);g.recompute()};confirm=null}){Label("CONFIRM",color=p.red)}},dismissButton={TextButton(onClick={confirm=null}){Label("CANCEL")}})}
}
@Composable fun Picker(g: AppGraph,custom: ()->Unit,upgrade: ()->Unit,back: ()->Unit){val store by g.store.state.collectAsState();var selection by remember(g.settings.tracked){mutableStateOf(g.settings.tracked)}
    ScrollPage {Label("TRACKED STREAKS",size=25,bold=true);Label("${selection.size} SELECTED · ${if(store.isPro)"UNLIMITED"else"FREE TRACKS 3"}",color=LocalPalette.current.lime)
        g.candidates.forEach{s->PixelButton((if(s.key in selection)"■ "else"□ ")+s.name.uppercase()+" · ${s.label}"){if(s.key in selection)selection=selection-s.key else if(store.isPro||selection.size<3)selection=selection+s.key else upgrade()}}
        if(g.candidates.isEmpty())EmptyState("NO STREAKS FOUND","Connect Health Connect or create a custom streak.")
        PixelButton("+ BUILD A CUSTOM STREAK",onClick=custom);PixelButton("SAVE SELECTION",primary=true){if(g.track(selection))back()else upgrade()}
    }
}
@Composable fun CustomEditor(g: AppGraph,back: ()->Unit,upgrade: ()->Unit){
    val available=Catalog.metrics.filter{it.key in g.health.supportedMetrics()&&it.key!="earlySteps"};var metric by remember{mutableStateOf(available.firstOrNull()?.key?:"steps")};var workout by remember{mutableStateOf<String?>(null)};var measure by remember{mutableStateOf("count")};var value by remember{mutableStateOf("5000")};var error by remember{mutableStateOf<String?>(null)};var timed by remember{mutableStateOf(false)};var hour by remember{mutableIntStateOf(10)}
    ScrollPage {Label("BUILD YOUR\nOWN CHAIN.",size=28,bold=true);Section("METRIC");Dropdown(available.map{it.key to it.androidName},metric){metric=it;workout=null;value=Catalog.metric(it).thresholds.first().toString()}
        if(metric=="workouts"){Section("WORKOUT TYPE");val workouts=Catalog.workouts.filter{it.key in AndroidWorkouts.available};Dropdown(listOf("all" to "Any workout")+workouts.map{it.key to it.name},workout?:"all"){workout=it.takeUnless{it=="all"};value="1"};if(workout!=null){Dropdown(listOf("count" to "Sessions","minutes" to "Minutes")+(if(workouts.firstOrNull{it.key==workout}?.distance==true)listOf("miles" to "Miles")else emptyList()),measure){measure=it;value=if(it=="minutes")"20"else"1"}}}
        if(metric=="steps"){PixelButton(if(timed)"TIME WINDOW ON"else"TIME WINDOW OFF"){timed=!timed};if(timed)Dropdown((0..23).map{it.toString() to hourLabel(it)},hour.toString()){hour=it.toInt()}}
        OutlinedTextField(value,{value=it},label={Text("Daily goal")},singleLine=true,keyboardOptions=androidx.compose.foundation.text.KeyboardOptions(keyboardType=androidx.compose.ui.text.input.KeyboardType.Decimal),modifier=Modifier.fillMaxWidth())
        error?.let{Label(it,color=LocalPalette.current.red)}
        Label("Daily goals. Free includes 3 custom streaks and 3 tracked streaks.",color=LocalPalette.current.dim,size=12)
        PixelButton("CREATE STREAK",primary=true,enabled=available.isNotEmpty()){val goal=value.toDoubleOrNull();if(goal==null||!goal.isFinite()||goal<=0||goal>1_000_000)error="Enter a goal greater than zero."else {val c=CustomStreak(UUID.randomUUID().toString(),metric,goal,hour=hour.takeIf{timed&&metric=="steps"},workoutType=workout,measure=measure.takeIf{workout!=null});if(!g.settings.custom(c,g.store.current.isPro))upgrade()else{g.recompute();if(g.store.current.isPro||g.settings.tracked.size<3)g.track(g.settings.tracked+c.key);back()}}}
        if(available.isEmpty())Label("Allow an activity type in Health Connect before creating a streak.")
    }
}
@Composable fun Dropdown(options: List<Pair<String,String>>,value: String,onChange: (String)->Unit){var expanded by remember{mutableStateOf(false)};Box{PixelButton(options.firstOrNull{it.first==value}?.second?:"Choose"){expanded=true};DropdownMenu(expanded,{expanded=false}){options.forEach{(key,title)->DropdownMenuItem(text={Label(title)},onClick={onChange(key);expanded=false})}}}}
@Composable fun PrivacyScreen(){ScrollPage{Label("YOUR HEALTH.\nYOUR DEVICE.",size=28,bold=true);Label("Streak Finder reads the activity types you allow in Health Connect. Activity values and calculated streaks stay on this device. The app never writes or deletes your Health Connect records.");Section("ANDROID METRICS");Label("Workout minutes come from recorded sessions with pauses removed. Stand hours have no equivalent and are unavailable. Mindfulness depends on device support. Sleep is credited to the day it ends. Cardio Minutes approximate time above 100 bpm from recorded samples, with each gap capped at 30 seconds. Distance includes the distance records shared with Health Connect.");Section("CONTROL YOUR DATA");Label("Change each permission in Health Connect. Removing access clears local health history before the next read. Disconnect and delete local health data in Settings to revoke access and erase local activity history.");Section("PURCHASES");Label("RevenueCat receives purchase and app interaction information to manage Streaks+. Health values are never sent to RevenueCat. This is a habit tracker, not medical advice.");Section("HOW TO USE");Label("1. Connect Health Connect.\n2. Choose your intensity and tracked streaks.\n3. Open a streak to see today's goal.\n4. Add custom goals from Find more streaks.\n5. Plan freezes and review saves on the Saves tab.")}}

@Composable fun TutorialScreen(close: ()->Unit){var step by remember{mutableIntStateOf(0)};val pages=listOf("YOUR HERO STREAK" to "Your primary streak stays at the top. Today's progress stays live until the day ends.","OTHER ACTIVE STREAKS" to "Keep the rest of your habits in view. Open a streak to see its goal and personal best.","FIND MORE STREAKS" to "Choose which discovered streaks to track, or build a custom goal for a metric or workout type.","TUNE EVERYTHING ELSE" to "Use Settings to change intensity, connect activity types, recalibrate goals and manage reminders.")
    ScrollPage{Section("${step+1} / ${pages.size}");Label(pages[step].first,size=26,bold=true);Label(pages[step].second);PixelButton(if(step==pages.lastIndex)"GOT IT"else"NEXT",primary=true){if(step==pages.lastIndex)close()else step++};if(step<pages.lastIndex)PixelButton("SKIP TUTORIAL",onClick=close)}
}
