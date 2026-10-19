package com.jackwallner.streaks

import java.time.LocalDate
import android.app.Application
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONObject
import com.jackwallner.streaks.data.*
import com.jackwallner.streaks.model.*

class StreaksApplication: Application() {
    val graph by lazy{AppGraph(this)}
    override fun onCreate(){super.onCreate();graph.start()}
}
class AppGraph(val context: Context) {
    val scope=CoroutineScope(SupervisorJob()+Dispatchers.Main.immediate)
    val values=Preferences(context)
    val settings=Settings(values)
    val diagnostics=ConversionDiagnostics(values)
    val review=ReviewTracker(values)
    val store=StoreService(context,diagnostics)
    val health=HealthService(context,settings)
    var candidates by mutableStateOf(emptyList<Streak>());private set
    var streaks by mutableStateOf(emptyList<Streak>());private set
    var pendingRoute by mutableStateOf<String?>(null)
    fun start(){health.onChange={changed->recompute(!changed)};scope.launch{var wasPro=false;store.state.collect{state->if(state.isPro&&!wasPro)settings.upgrade();wasPro=state.isPro;if(state.isResolved&&!state.isPro&&settings.notifications)settings.notifications(false);recompute(false);Reminders.schedule(context,settings,state.isPro)}};recompute(false)}
    fun recompute(detectBreaks: Boolean=false) {
        val today=LocalDate.now();val isPro=store.current.isPro
        val unsupported=Catalog.metrics.map{it.key}.toSet()-health.supportedMetrics()
        val hidden=settings.hidden+unsupported
        fun discover()=Engine.discover(health.history,today,settings.intensity,settings.lookback,hidden,settings.committed,settings.custom,settings.preservations,if(isPro)settings.freezes else emptySet(),health.hourly)
        var fresh=discover()
        if(detectBreaks) {
            val baseline=runCatching{JSONObject(values.string("lastKnownStreakLengths")?:"{}")}.getOrDefault(JSONObject())
            val old=streaks.associateBy{it.key}
            (baseline.keys().asSequence().toList()+old.keys).distinct().forEach {key->
                val previous=maxOf(old[key]?.current?:0,baseline.optInt(key));val now=fresh.firstOrNull{it.key==key}
                if(previous>=3&&now!=null&&now.current==0&&settings.broken.none{it.key==key}){
                    if(isPro)settings.preserve(Preservation(key,today.minusDays(1),previous,now.metric,now.threshold,now.cadence,now.hour))
                    else settings.broken(BrokenStreak(key,now.metric,now.threshold,previous,today,now.cadence,now.hour))
                }
            }
            fresh=discover()
        }
        val before=streaks
        candidates=fresh
        val selected=fresh.filter{it.key in settings.tracked}.sortedBy{settings.order.indexOf(it.key).takeIf{index->index>=0}?:Int.MAX_VALUE}
        streaks=if(isPro)selected else selected.take(3)
        if(detectBreaks&&streaks.any{s->val old=before.firstOrNull{it.key==s.key};old!=null&&(s.current>old.current||s.completed&&!old.completed)})review.positive()
        if(detectBreaks)values.put("lastKnownStreakLengths",JSONObject(streaks.associate{it.key to it.current}).toString())
    }
    fun finish(keys: List<String>){settings.finish(keys,store.current.isPro);settings.commit(candidates.filter{it.key in settings.tracked});recompute()}
    fun track(keys: Set<String>): Boolean {val ok=settings.track(keys,store.current.isPro);if(ok){settings.commit(candidates.filter{it.key in keys});recompute()};return ok}
    fun revive(b: BrokenStreak): Boolean {if(!store.current.isPro||b.broken<LocalDate.now().minusDays(1))return false;settings.preserve(Preservation(b.key,b.broken,b.length,b.metric,b.threshold,b.cadence,b.hour));recompute();return true}
}
