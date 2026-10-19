package com.jackwallner.streaks.data

import java.time.LocalDate
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import org.json.JSONArray
import org.json.JSONObject
import com.jackwallner.streaks.model.*

class Preferences(context: Context): Values {
    private val prefs=context.getSharedPreferences("streaks",Context.MODE_PRIVATE)
    override fun string(key: String)=prefs.getString(key,null)
    override fun put(key: String,value: String){prefs.edit().putString(key,value).apply()}
    override fun entries()=prefs.all.mapValues{it.value.toString()}
}
object Codec {
    fun days(days: List<ActivityDay>)=JSONArray(days.map{a->JSONObject().put("date",a.date.toString()).put("values",JSONObject(a.values)).put("workouts",JSONObject(a.workouts.mapValues{(_,w)->JSONObject().put("count",w.count).put("minutes",w.minutes).put("miles",w.miles)}))})
    fun days(raw: String): List<ActivityDay> = runCatching { val a=JSONArray(raw);(0 until a.length()).map{i->val d=a.getJSONObject(i);val v=d.getJSONObject("values");val w=d.getJSONObject("workouts");ActivityDay(LocalDate.parse(d.getString("date")),v.keys().asSequence().associateWith(v::getDouble),w.keys().asSequence().associateWith{k->val s=w.getJSONObject(k);WorkoutStat(s.getDouble("count"),s.getDouble("minutes"),s.getDouble("miles"))})} }.getOrDefault(emptyList())
    fun strings(raw: String?)=runCatching{val a=JSONArray(raw?:"[]");(0 until a.length()).map(a::getString)}.getOrDefault(emptyList())
}
class Settings(val values: Values) {
    var setup by mutableStateOf(values.bool("hasCompletedSetup"));private set
    var appearance by mutableStateOf(values.string("appearance")?.toIntOrNull()?:0);private set
    var intensity by mutableStateOf(values.string("discoveryVibe")?.toIntOrNull()?:1);private set
    var lookback by mutableStateOf((values.string("lookbackDays")?.toIntOrNull()?:30).coerceIn(7,365));private set
    var tracked by mutableStateOf(Codec.strings(values.string("trackedStreaks")).toSet());private set
    var order by mutableStateOf(Codec.strings(values.string("manualStreakOrder")));private set
    var hidden by mutableStateOf(Codec.strings(values.string("hiddenMetrics")).toSet());private set
    var freezes by mutableStateOf(Codec.strings(values.string("plannedFreezes")).mapNotNull{runCatching{LocalDate.parse(it)}.getOrNull()}.filter{it>=LocalDate.now().minusDays(30)}.toSet());private set
    var committed by mutableStateOf(runCatching{val o=JSONObject(values.string("committedThresholds")?:"{}");o.keys().asSequence().associateWith(o::getDouble)}.getOrDefault(emptyMap()));private set
    var custom by mutableStateOf(runCatching{val a=JSONArray(values.string("customStreaks")?:"[]");(0 until a.length()).map {i->a.getJSONObject(i).let{CustomStreak(it.getString("id"),it.getString("metric"),it.getDouble("threshold"),it.optString("cadence","daily"),it.optInt("hour",-1).takeIf{h->h>=0},it.optString("workoutType").takeIf(String::isNotBlank),it.optString("measure").takeIf(String::isNotBlank))}}}.getOrDefault(emptyList()));private set
    var preservations by mutableStateOf(runCatching{val a=JSONArray(values.string("gracePreservations")?:"[]");(0 until a.length()).map{i->a.getJSONObject(i).let{Preservation(it.getString("key"),LocalDate.parse(it.getString("missed")),it.getInt("length"),it.getString("metric"),it.getDouble("threshold"),granted=LocalDate.parse(it.getString("granted")))}}.associateBy{it.key}}.getOrDefault(emptyMap()));private set
    var broken by mutableStateOf(runCatching{val a=JSONArray(values.string("recentlyBroken")?:"[]");(0 until a.length()).map{i->a.getJSONObject(i).let{BrokenStreak(it.getString("key"),it.getString("metric"),it.getDouble("threshold"),it.getInt("length"),LocalDate.parse(it.getString("broken")))}}.filter{it.broken>=LocalDate.now().minusDays(14)}}.getOrDefault(emptyList()));private set
    var notifications by mutableStateOf(values.bool("notificationsEnabled"));private set
    var notificationHour by mutableStateOf(values.string("notificationHour")?.toIntOrNull()?:19);private set
    var notificationMinute by mutableStateOf(values.int("notificationMinute"));private set
    fun appearance(value: Int){appearance=value.coerceIn(0,2);values.put("appearance",appearance.toString())}
    fun intensity(value: Int){intensity=value.coerceIn(0,2);values.put("discoveryVibe",intensity.toString())}
    fun lookback(value: Int){lookback=value.coerceIn(7,365);values.put("lookbackDays",lookback.toString())}
    fun hidden(value: Set<String>){hidden=value;values.put("hiddenMetrics",JSONArray(value.toList()).toString())}
    fun track(keys: Set<String>,isPro: Boolean): Boolean {if(!isPro&&keys.size>3)return false;tracked=keys;values.put("trackedStreaks",JSONArray(keys.toList()).toString());return true}
    fun finish(keys: List<String>,isPro: Boolean){values.put("lastOnboardingTrackedKeys",JSONArray(keys).toString());values.put("lastOnboardingPickedCount",keys.size.toString());track((if(isPro)keys else keys.take(3)).toSet(),isPro);setup=true;values.put("hasCompletedSetup","true");values.put("hasSeenTrialOffer","true")}
    fun upgrade(){val intent=Codec.strings(values.string("lastOnboardingTrackedKeys"));if(intent.size>tracked.size){track(intent.toSet(),true);order=intent;values.put("manualStreakOrder",JSONArray(order).toString())}}
    fun primary(key: String){order=listOf(key)+order.filter{it!=key};values.put("manualStreakOrder",JSONArray(order).toString())}
    fun commit(streaks: List<Streak>){committed=committed+streaks.filter{it.customID==null&&it.key !in committed}.associate{it.key to it.threshold};persistCommitted()}
    fun recalibrate(key: String){committed=committed-key;persistCommitted()}
    private fun persistCommitted(){values.put("committedThresholds",JSONObject(committed).toString())}
    fun custom(value: CustomStreak,isPro: Boolean): Boolean {if(!isPro&&custom.size>=3&&custom.none{it.id==value.id})return false;custom=custom.filter{it.id!=value.id}+value;saveCustom();return true}
    fun deleteCustom(id: String){custom=custom.filter{it.id!=id};saveCustom();track(tracked-"custom-$id",true)}
    private fun saveCustom(){values.put("customStreaks",JSONArray(custom.map{JSONObject().put("id",it.id).put("metric",it.metric).put("threshold",it.threshold).put("cadence",it.cadence).put("hour",it.hour).put("workoutType",it.workoutType?:"").put("measure",it.measure?:"")}).toString())}
    fun freeze(day: LocalDate,isPro: Boolean): Boolean {if(!isPro)return false;freezes=if(day in freezes)freezes-day else freezes+day;values.put("plannedFreezes",JSONArray(freezes.map(LocalDate::toString)).toString());return true}
    fun preserve(p: Preservation){preservations=preservations+(p.key to p);values.put("gracePreservations",JSONArray(preservations.values.map{JSONObject().put("key",it.key).put("missed",it.missed.toString()).put("length",it.length).put("metric",it.metric).put("threshold",it.threshold).put("granted",it.granted.toString())}).toString());dismissBroken(p.key)}
    fun broken(b: BrokenStreak){if(broken.any{it.key==b.key})return;broken=broken+b;saveBroken()}
    fun dismissBroken(key: String){broken=broken.filter{it.key!=key};saveBroken()}
    private fun saveBroken(){values.put("recentlyBroken",JSONArray(broken.map{JSONObject().put("key",it.key).put("metric",it.metric).put("threshold",it.threshold).put("length",it.length).put("broken",it.broken.toString())}).toString())}
    fun notifications(enabled: Boolean,hour: Int=notificationHour,minute: Int=notificationMinute){notifications=enabled;notificationHour=hour.coerceIn(0,23);notificationMinute=minute.coerceIn(0,59);values.put("notificationsEnabled",enabled.toString());values.put("notificationHour",notificationHour.toString());values.put("notificationMinute",notificationMinute.toString())}
    fun clearHealth(){values.put("healthCache","[]");values.put("lastKnownStreakLengths","{}");preservations=emptyMap();broken=emptyList();values.put("gracePreservations","[]");saveBroken()}
}
class ReviewTracker(private val values: Values,private val clock: ()->Long=System::currentTimeMillis) {
    var automation=false
    fun launch(){values.put("reviewPrompt.appLaunchCount",(values.int("reviewPrompt.appLaunchCount")+1).toString())}
    fun positive(){values.put("reviewPrompt.pendingPositiveMoment","true");values.put("reviewPrompt.positiveMomentCount",(values.int("reviewPrompt.positiveMomentCount")+1).toString())}
    fun eligible(setup: Boolean,interrupted: Boolean)=!automation&&setup&&!interrupted&&values.int("reviewPrompt.appLaunchCount")>=2&&values.bool("reviewPrompt.pendingPositiveMoment")&&values.string("reviewPrompt.outcome")!="openedWriteReview"&&(values.long("reviewPrompt.lastShownDate")?.let{clock()-it>=30*86400000L}?:true)
    fun shown(){values.put("reviewPrompt.lastShownDate",clock().toString());values.put("reviewPrompt.pendingPositiveMoment","false")}
    fun openedReview(){values.put("reviewPrompt.outcome","openedWriteReview");shown()}
    fun feedback(){values.put("reviewPrompt.feedbackDate",clock().toString())}
}
