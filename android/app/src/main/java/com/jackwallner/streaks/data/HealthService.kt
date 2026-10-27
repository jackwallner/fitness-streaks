@file:OptIn(androidx.health.connect.client.feature.ExperimentalMindfulnessSessionApi::class)

package com.jackwallner.streaks.data

import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.Period
import java.time.ZoneId
import kotlin.reflect.KClass
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.AggregateGroupByPeriodRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import com.jackwallner.streaks.model.*

class HealthService(private val context: Context,private val settings: Settings) {
    private val mutex=Mutex()
    val status get()=HealthConnectClient.getSdkStatus(context)
    private val client get()=HealthConnectClient.getOrCreate(context)
    val available get()=status==HealthConnectClient.SDK_AVAILABLE
    var history by mutableStateOf(Codec.days(settings.values.string("healthCache")?:"[]"));private set
    var hourly by mutableStateOf(emptyMap<LocalDate,Map<Int,Double>>());private set
    var permissions by mutableStateOf(Codec.strings(settings.values.string("healthGranted")).toSet());private set
    var message by mutableStateOf<String?>(null);private set
    var loading by mutableStateOf(false);private set
    var updated by mutableStateOf(settings.values.long("healthUpdated"));private set
    var onChange: (Boolean)->Unit={}
    var debugSeeded=false
    private val types: List<KClass<out Record>> = listOf(StepsRecord::class,ActiveCaloriesBurnedRecord::class,DistanceRecord::class,FloorsClimbedRecord::class,ExerciseSessionRecord::class,SleepSessionRecord::class,HeartRateRecord::class)
    fun feature(id: Int)=available&&client.features.getFeatureStatus(id)==HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
    fun requested(): Set<String> {
        val p=types.map(HealthPermission::getReadPermission).toMutableSet()
        if(feature(HealthConnectFeatures.FEATURE_MINDFULNESS_SESSION))p+=HealthPermission.getReadPermission(MindfulnessSessionRecord::class)
        if(feature(HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_HISTORY))p+=HealthPermission.PERMISSION_READ_HEALTH_DATA_HISTORY
        if(feature(HealthConnectFeatures.FEATURE_READ_HEALTH_DATA_IN_BACKGROUND))p+=HealthPermission.PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND
        return p
    }
    fun supportedMetrics(): Set<String> {
        val keys=mutableSetOf<String>()
        fun granted(type: KClass<out Record>)=HealthPermission.getReadPermission(type) in permissions
        if(granted(StepsRecord::class))keys+="steps"
        if(granted(ActiveCaloriesBurnedRecord::class))keys+="activeEnergy"
        if(granted(DistanceRecord::class))keys+="distanceMiles"
        if(granted(FloorsClimbedRecord::class))keys+="flightsClimbed"
        if(granted(ExerciseSessionRecord::class))keys+=listOf("workouts","exerciseMinutes")
        if(granted(SleepSessionRecord::class))keys+="sleepHours"
        if(granted(HeartRateRecord::class))keys+="heartRateMinutes"
        if(granted(MindfulnessSessionRecord::class))keys+="mindfulMinutes"
        if("exerciseMinutes" in keys&&"activeEnergy" in keys)keys+="intensityRatio"
        return keys
    }
    suspend fun refresh()=mutex.withLock {
        if(debugSeeded)return@withLock
        if(!available){history=emptyList();hourly=emptyMap();settings.clearHealth();message="Install or update Health Connect to find your streaks.";onChange(true);return@withLock}
        loading=true
        try {
            val granted=client.permissionController.getGrantedPermissions()
            val prior=Codec.strings(settings.values.string("healthGranted")).toSet()
            val changed=prior!=granted
            val previous=history
            permissions=granted
            if(changed){history=emptyList();hourly=emptyMap();settings.clearHealth();onChange(true)}
            settings.values.put("healthGranted",org.json.JSONArray(granted.toList()).toString())
            if(types.none{HealthPermission.getReadPermission(it) in granted}) {history=emptyList();settings.clearHealth();message="Connect Health Connect and allow the activity types you want to track.";onChange(true);return@withLock}
            val zone=ZoneId.systemDefault();val today=LocalDate.now(zone)
            val days=if(HealthPermission.PERMISSION_READ_HEALTH_DATA_HISTORY in granted)400 else 30
            val first=today.minusDays(days-1L)
            val start=first.atStartOfDay(zone).toInstant();val end=Instant.now()
            val daily=(0 until days).associate{first.plusDays(it.toLong()) to mutableMapOf<String,Double>()}.toMutableMap()
            val workouts=mutableMapOf<LocalDate,MutableMap<String,WorkoutStat>>()
            val aggregate=buildSet {
                if(HealthPermission.getReadPermission(StepsRecord::class) in granted)add(StepsRecord.COUNT_TOTAL)
                if(HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class) in granted)add(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL)
                if(HealthPermission.getReadPermission(DistanceRecord::class) in granted)add(DistanceRecord.DISTANCE_TOTAL)
                if(HealthPermission.getReadPermission(FloorsClimbedRecord::class) in granted)add(FloorsClimbedRecord.FLOORS_CLIMBED_TOTAL)
            }
            if(aggregate.isNotEmpty())client.aggregateGroupByPeriod(AggregateGroupByPeriodRequest(aggregate,TimeRangeFilter.between(first.atStartOfDay(),java.time.LocalDateTime.now()),Period.ofDays(1))).forEach {r->
                val row=daily[r.startTime.toLocalDate()]?:return@forEach
                row["steps"]=(r.result[StepsRecord.COUNT_TOTAL]?:0L).toDouble()
                row["activeEnergy"]=r.result[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories?:0.0
                row["distanceMiles"]=r.result[DistanceRecord.DISTANCE_TOTAL]?.inMiles?:0.0
                row["flightsClimbed"]=r.result[FloorsClimbedRecord.FLOORS_CLIMBED_TOTAL]?:0.0
            }
            suspend fun <T: Record> read(type: KClass<T>): List<T> {
                if(HealthPermission.getReadPermission(type) !in granted)return emptyList()
                val out=mutableListOf<T>();var token: String?=null
                do {val page=client.readRecords(ReadRecordsRequest(type,TimeRangeFilter.between(start,end),pageSize=1000,pageToken=token));out+=page.records;token=page.pageToken}while(!token.isNullOrEmpty())
                return out
            }
            fun add(day: LocalDate,key: String,value: Double){daily[day]?.let{it[key]=(it[key]?:0.0)+value}}
            read(ExerciseSessionRecord::class).forEach{r->
                val day=r.startTime.atZone(zone).toLocalDate()
                val pauses=r.segments.filter{it.segmentType==ExerciseSegment.EXERCISE_SEGMENT_TYPE_PAUSE}.map{it.startTime to it.endTime}
                val minutes=((Duration.between(r.startTime,r.endTime).toMillis()-HealthMath.unionMillis(pauses))/60000.0).coerceAtLeast(0.0)
                add(day,"exerciseMinutes",minutes);add(day,"workouts",1.0)
                AndroidWorkouts.key(r.exerciseType)?.let {key->val map=workouts.getOrPut(day){mutableMapOf()};var miles=0.0
                    if(HealthPermission.getReadPermission(DistanceRecord::class) in granted)miles=client.aggregate(androidx.health.connect.client.request.AggregateRequest(setOf(DistanceRecord.DISTANCE_TOTAL),TimeRangeFilter.between(r.startTime,r.endTime)))[DistanceRecord.DISTANCE_TOTAL]?.inMiles?:0.0
                    map[key]=(map[key]?:WorkoutStat())+WorkoutStat(1.0,minutes,miles)
                }
            }
            val asleep=read(SleepSessionRecord::class).groupBy{it.endTime.atZone(zone).toLocalDate()}
            asleep.forEach{(day,records)->val intervals=records.flatMap {r->if(r.stages.isEmpty())listOf(r.startTime to r.endTime)else r.stages.filter{it.stage in setOf(SleepSessionRecord.STAGE_TYPE_SLEEPING,SleepSessionRecord.STAGE_TYPE_LIGHT,SleepSessionRecord.STAGE_TYPE_DEEP,SleepSessionRecord.STAGE_TYPE_REM)}.map{it.startTime to it.endTime}};add(day,"sleepHours",HealthMath.unionMillis(intervals)/3600000.0)}
            read(HeartRateRecord::class).flatMap{it.samples}.filter{it.beatsPerMinute>100}.distinctBy{it.time}.groupBy{it.time.atZone(zone).toLocalDate()}.forEach{(day,samples)->val times=samples.sortedBy{it.time}.map{it.time};add(day,"heartRateMinutes",HealthMath.cardioMinutes(times))}
            if(feature(HealthConnectFeatures.FEATURE_MINDFULNESS_SESSION))read(MindfulnessSessionRecord::class).groupBy{it.startTime.atZone(zone).toLocalDate()}.forEach{(day,records)->add(day,"mindfulMinutes",HealthMath.unionMillis(records.map{it.startTime to it.endTime})/60000.0)}
            val fresh=daily.map{(day,v)->ActivityDay(day,v,workouts[day].orEmpty())}.sortedBy{it.date}
            if(!changed&&HealthMath.likelyDataLoss(fresh,previous,today)){message="No recent data returned. Keeping your last successful history. Check Health Connect access and refresh.";return@withLock}
            history=if(changed)fresh else HealthMath.mergeMissing(fresh,previous,today)
            updated=System.currentTimeMillis();settings.values.put("healthUpdated",updated.toString());settings.values.put("healthCache",Codec.days(history).toString())
            message=if(HealthPermission.PERMISSION_READ_HEALTH_DATA_HISTORY !in granted)"Showing up to 30 days. Allow past data for longer history."else null
            onChange(changed)
        }catch(error: SecurityException){history=emptyList();hourly=emptyMap();permissions=emptySet();settings.clearHealth();message="Health access changed. Reconnect Health Connect.";onChange(true)}
        catch(error: Exception){if(error is kotlinx.coroutines.CancellationException)throw error;message="Couldn't refresh Health Connect. Your last successful history is kept. Try again."}
        finally{loading=false}
    }
    suspend fun backgroundAllowed()=available&&HealthPermission.PERMISSION_READ_HEALTH_DATA_IN_BACKGROUND in client.permissionController.getGrantedPermissions()
    suspend fun disconnect(){if(available)client.permissionController.revokeAllPermissions();permissions=emptySet();history=emptyList();hourly=emptyMap();debugSeeded=false;settings.clearHealth();onChange(true);message="Health Connect disconnected. Local activity history deleted."}
    fun settingsIntent()=if(available)HealthConnectClient.getHealthConnectManageDataIntent(context)else Intent(Intent.ACTION_VIEW,Uri.parse("market://details?id=com.google.android.apps.healthdata"))
    fun seed(days: List<ActivityDay>){debugSeeded=true;history=days;permissions=requested();onChange(true)}
}
object HealthMath {
    fun signal(days: List<ActivityDay>)=days.sumOf{d->Catalog.metrics.filter{it.key!="intensityRatio"}.sumOf{d.value(it.key)}}
    fun likelyDataLoss(fresh: List<ActivityDay>,previous: List<ActivityDay>,today: LocalDate): Boolean {val cutoff=today.minusDays(13);return signal(fresh.filter{it.date>=cutoff})==0.0&&signal(previous.filter{it.date>=cutoff})>0}
    fun mergeMissing(fresh: List<ActivityDay>,previous: List<ActivityDay>,today: LocalDate): List<ActivityDay> {val cache=previous.associateBy{it.date};return fresh.map{d->if(d.date<today&&signal(listOf(d))==0.0&&cache[d.date]?.let{signal(listOf(it))>0}==true)cache[d.date]!! else d}}

    fun unionMillis(intervals: List<Pair<Instant,Instant>>): Long {
        val sorted=intervals.filter{it.second>it.first}.sortedBy{it.first};if(sorted.isEmpty())return 0
        var start=sorted.first().first;var end=sorted.first().second;var total=0L
        sorted.drop(1).forEach{(s,e)->if(s<=end)end=maxOf(end,e)else{total+=Duration.between(start,end).toMillis();start=s;end=e}}
        return total+Duration.between(start,end).toMillis()
    }
    fun cardioMinutes(times: List<Instant>): Double {if(times.isEmpty())return 0.0;return (5.0+times.sorted().zipWithNext().sumOf{(a,b)->minOf(30.0,Duration.between(a,b).toMillis()/1000.0)})/60}
}
