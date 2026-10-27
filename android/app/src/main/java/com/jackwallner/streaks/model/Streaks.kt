package com.jackwallner.streaks.model

import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.Locale
import kotlin.math.abs
import kotlin.math.floor
import org.json.JSONObject

data class Metric(val key: String,val name: String,val unit: String,val weight: Double,val thresholds: List<Double>) {
    fun format(value: Double, live: Boolean = false): String {
        val v=if(live)floor(value*10)/10 else value
        return when(key) {
            "sleepHours","intensityRatio"->String.format(Locale.US,"%.1f",v)
            "distanceMiles"->String.format(Locale.US,if(v<10)"%.1f" else "%.0f",v)
            else->(if(live)floor(value) else floor(value+0.5)).toLong().toString()
        }
    }
    val androidName get()=if(key=="exerciseMinutes")"Workout minutes" else name
}
data class WorkoutType(val key: String,val name: String,val distance: Boolean)
object Catalog {
    private val json=JSONObject(Catalog::class.java.getResourceAsStream("/catalog.json")!!.bufferedReader().use{it.readText()})
    val metrics=(0 until json.getJSONArray("metrics").length()).map { i->json.getJSONArray("metrics").getJSONObject(i).let { m->Metric(m.getString("key"),m.getString("name"),m.getString("unit"),m.getDouble("weight"),m.getJSONArray("thresholds").let{a->(0 until a.length()).map(a::getDouble)}) } }
    val workouts=(0 until json.getJSONArray("workouts").length()).map { i->json.getJSONArray("workouts").getJSONObject(i).let{WorkoutType(it.getString("key"),it.getString("name"),it.getBoolean("distance"))} }
    fun metric(key: String)=metrics.first{it.key==key}
}
data class WorkoutStat(val count: Double=0.0,val minutes: Double=0.0,val miles: Double=0.0) {
    fun value(measure: String)=when(measure){"minutes"->minutes;"miles"->miles;else->count}
    operator fun plus(other: WorkoutStat)=WorkoutStat(count+other.count,minutes+other.minutes,miles+other.miles)
}
data class ActivityDay(val date: LocalDate,val values: Map<String,Double> = emptyMap(),val workouts: Map<String,WorkoutStat> = emptyMap()) {
    fun value(key: String): Double=if(key=="intensityRatio") {val mins=values["exerciseMinutes"]?:0.0;if(mins>0)(values["activeEnergy"]?:0.0)/mins else 0.0} else values[key]?:0.0
}
data class CustomStreak(val id: String,val metric: String,val threshold: Double,val cadence: String="daily",val hour: Int?=null,val workoutType: String?=null,val measure: String?=null){val key get()="custom-$id"}
data class Preservation(val key: String,val missed: LocalDate,val length: Int,val metric: String,val threshold: Double,val cadence: String="daily",val hour: Int?=null,val granted: LocalDate=LocalDate.now())
data class BrokenStreak(val key: String,val metric: String,val threshold: Double,val length: Int,val broken: LocalDate,val cadence: String="daily",val hour: Int?=null)
data class Streak(val metric: String,val threshold: Double,val cadence: String="daily",val customID: String?=null,val hour: Int?=null,val workoutType: String?=null,val measure: String?=null,val current: Int=0,val best: Int=0,val start: LocalDate?=null,val lastHit: LocalDate?=null,val lastMissed: LocalDate?=null,val completed: Boolean=false,val progress: Double=0.0,val value: Double=0.0,val rate: Double=0.0,val lookback: Int=0) {
    val key get()=customID?.let{"custom-$it"} ?: "$metric-$cadence"+(hour?.let{"-h$it"}?:"")
    val id get()="$key-${threshold.toInt()}"
    val name get()=Catalog.workouts.firstOrNull{it.key==workoutType}?.name?:Catalog.metric(metric).androidName
    val unit get()=when(measure){"minutes"->"min";"miles"->"mi";"count"->"session";else->Catalog.metric(metric).unit}
    fun format(v: Double,live: Boolean=false)=if(measure!=null) when(measure){"miles"->String.format(Locale.US,if(v<10)"%.1f" else "%.0f",if(live)floor(v*10)/10 else v);else->(if(live)floor(v) else floor(v+0.5)).toInt().toString()} else Catalog.metric(metric).format(v,live)
    val label get()=if(metric=="workouts"&&workoutType==null)"Any workout" else "${format(threshold)} $unit${workoutType?.let{" ${name.lowercase()}"}?:""}"
    val score get(): Double {val bonus=if(hour==null)1.0 else 1.0+(Engine.hourThresholds.indexOfFirst{it>=threshold}.takeIf{it>=0}?:Engine.hourThresholds.size)*.15;return current*Catalog.metric(metric).weight*(1+(1-rate)*.5)*bonus}
}
object Engine {
    fun reminder(streaks: List<Streak>)=streaks.filter{!it.completed&&it.current>=2}.sortedWith(compareByDescending<Streak>{it.current}.thenBy{it.progress}).firstOrNull()
    fun circularHourDistance(a: Int,b: Int)=minOf(abs(a-b),24-abs(a-b))
    val hourThresholds=listOf(250.0,500.0,1000.0,1500.0,2000.0,3000.0)
    fun daily(metric: String,threshold: Double,values: Map<LocalDate,Double>,today: LocalDate,freezes: Set<LocalDate> = emptySet()): Streak {
        if(threshold<=0)return Streak(metric,threshold)
        val value=values[today]?:0.0;val met=value>=threshold
        var current=if(met)1 else 0;var start: LocalDate?=if(met)today else null
        var cursor=today.minusDays(1)
        while(true){if(cursor in freezes){start=cursor;cursor=cursor.minusDays(1);continue};if((values[cursor]?:0.0)<threshold)break;current++;start=cursor;cursor=cursor.minusDays(1)}
        var run=0;var best=0
        values.toSortedMap().forEach{(day,v)->if(day !in freezes){run=if(v>=threshold)run+1 else 0;best=maxOf(best,run)}}
        val hit=(0L until 800).asSequence().map(today::minusDays).firstOrNull{(values[it]?:0.0)>=threshold}
        val miss=start?.let{s->(1L..800).asSequence().map(s::minusDays).firstOrNull{it !in freezes&&(values[it]?:0.0)<threshold}}
        return Streak(metric,threshold,current=current,best=maxOf(best,current),start=start,lastHit=hit,lastMissed=miss,completed=met||today in freezes,progress=if(today in freezes)1.0 else minOf(value/threshold,10.0),value=value)
    }
    fun grace(streak: Streak,p: Preservation?,today: LocalDate,rate: Double,lookback: Int): Streak {
        val base=streak.copy(rate=rate,lookback=lookback)
        if(p==null)return base
        val bridge=maxOf(0L,ChronoUnit.DAYS.between(p.missed,today))<=1 || streak.start?.let{it<=p.missed.plusDays(1)}==true
        if(!bridge)return base
        val length=maxOf(streak.current,p.length+streak.current)
        return base.copy(current=length,best=maxOf(streak.best,length),start=if(length>0)today.minusDays(length-1L)else streak.start)
    }
    private fun rounded(v: Double,key: String)=when(key){"steps"->floor(v/100)*100;"activeEnergy"->floor(v/10)*10;"distanceMiles"->floor(v*10)/10;else->floor(v)}
    fun discover(history: List<ActivityDay>,today: LocalDate=LocalDate.now(),intensity: Int=1,lookback: Int=30,hidden: Set<String> = emptySet(),committed: Map<String,Double> = emptyMap(),custom: List<CustomStreak> = emptyList(),preservations: Map<String,Preservation> = emptyMap(),freezes: Set<LocalDate> = emptySet(),hourly: Map<LocalDate,Map<Int,Double>> = emptyMap()): List<Streak> {
        if(history.isEmpty())return emptyList()
        val recent=history.takeLast(maxOf(1,lookback));val target=listOf(.8,.65,.5)[intensity.coerceIn(0,2)]
        val found=mutableListOf<Streak>()
        Catalog.metrics.filter{it.key !in hidden&&it.key!="earlySteps"}.forEach{m->
            val values=history.associate{it.date to it.value(m.key)};val window=recent.map{it.value(m.key)};val key="${m.key}-daily"
            fun compute(threshold: Double): Streak {val rate=window.count{it>=threshold}.toDouble()/window.size;return grace(daily(m.key,threshold,values,today,freezes),preservations[key],today,rate,lookback)}
            val locked=committed[key]
            if(locked!=null){found+=compute(locked);return@forEach}
            val candidates=when(m.key){"workouts","mindfulMinutes"->m.thresholds;"steps"->window.map{floor(it/100)*100}.filter{it>0}.distinct().sorted();else->window.filter{it>0}.distinct().sorted()}
            var best: Streak?=null;var distance=Double.MAX_VALUE
            candidates.forEach{v->val s=compute(rounded(v,m.key));val d=abs(s.rate-target);if(s.current>=2&&d<distance){best=s;distance=d}}
            if(best!=null&&distance<=.10){found+=best!!;return@forEach}
            if(window.count{it>0}.toDouble()/window.size>=.3)m.thresholds.sortedDescending().asSequence().map(::compute).firstOrNull{it.current>=3}?.let(found::add)
        }
        custom.filter{it.metric !in hidden}.forEach{c->
            val values=when{c.metric=="workouts"&&c.workoutType!=null->history.associate{it.date to (it.workouts[c.workoutType]?:WorkoutStat()).value(c.measure?:"count")};c.hour!=null->hourly.mapValues{it.value[c.hour]?:0.0};else->history.associate{it.date to it.value(c.metric)}}
            val recentValues=if(c.hour!=null)values.values.toList()else values.toSortedMap().values.toList().takeLast(maxOf(1,lookback))
            val rate=if(recentValues.isEmpty())0.0 else recentValues.count{it>=c.threshold}.toDouble()/recentValues.size
            val base=daily(c.metric,c.threshold,values,today,freezes).copy(customID=c.id,cadence=c.cadence,hour=c.hour,workoutType=c.workoutType,measure=c.measure)
            found+=grace(base,preservations[c.key],today,rate,lookback)
        }
        return found.sortedByDescending{it.score}
    }
    fun history(streak: Streak,history: List<ActivityDay>): List<Triple<LocalDate,Double,Boolean>> {
        val values=history.map{a->val v=if(streak.metric=="workouts"&&streak.workoutType!=null&&streak.measure!=null)(a.workouts[streak.workoutType]?:WorkoutStat()).value(streak.measure)else a.value(streak.metric);Triple(a.date,v,v>=streak.threshold)}
        if(streak.cadence!="weekly")return values
        fun monday(day: LocalDate)=day.minusDays(day.dayOfWeek.value-1L)
        val totals=values.groupBy{monday(it.first)}.mapValues{it.value.sumOf{v->v.second}}
        return values.map{it.copy(third=(totals[monday(it.first)]?:0.0)>=streak.threshold)}
    }
}
