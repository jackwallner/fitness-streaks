package com.jackwallner.streaks

import java.time.LocalDate
import android.content.Intent
import androidx.activity.ComponentActivity
import com.jackwallner.streaks.model.*

object DebugLaunchOptions {
    fun apply(activity: ComponentActivity,graph: AppGraph,intent: Intent?) {
        if(intent==null)return
        if(intent.getBooleanExtra("uiTest",false))graph.review.automation=true
        if(intent.getBooleanExtra("forcePro",false))graph.store.forceProForDebug()
        intent.getStringExtra("appearance")?.let{graph.settings.appearance(when(it){"light"->0;"dark"->1;else->2})}
        if(intent.getBooleanExtra("seedScreenshotData",false)){
            val today=LocalDate.now();val history=(0..89).map{offset->val hit=offset<12||offset%7!=0;val scale=if(hit)1.0 else 0.0;ActivityDay(today.minusDays(offset.toLong()),mapOf("steps" to if(offset==0)7215.0 else scale*(8500+offset%3*800),"exerciseMinutes" to scale*42,"activeEnergy" to scale*410,"sleepHours" to if(offset==0)7.6 else scale*8.1,"workouts" to scale,"distanceMiles" to scale*4.2,"flightsClimbed" to scale*14,"mindfulMinutes" to scale*10,"heartRateMinutes" to scale*24),mapOf("running" to WorkoutStat(scale,scale*42,scale*4.2)))}.sortedBy{it.date}
            graph.settings.recalibrate("steps-daily");graph.settings.commit(listOf(Streak("steps",7500.0)));graph.health.seed(history);graph.settings.finish(listOf("steps-daily","sleepHours-daily","exerciseMinutes-daily","workouts-daily","distanceMiles-daily"),graph.store.current.isPro);graph.settings.commit(graph.candidates);graph.settings.primary("steps-daily");graph.recompute()
        }else if(intent.getBooleanExtra("skipOnboarding",false))graph.finish(emptyList())
        intent.getStringExtra("route")?.let{graph.pendingRoute=it}
    }
}
