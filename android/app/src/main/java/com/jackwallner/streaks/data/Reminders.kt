package com.jackwallner.streaks.data

import java.time.Duration
import java.time.ZonedDateTime
import java.util.concurrent.TimeUnit
import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.*
import com.jackwallner.streaks.MainActivity
import com.jackwallner.streaks.R
import com.jackwallner.streaks.StreaksApplication

object Reminders {
    fun schedule(context: Context,settings: Settings,pro: Boolean){
        val manager=WorkManager.getInstance(context)
        if(!pro){manager.cancelUniqueWork("streak-refresh");manager.cancelUniqueWork("streak-reminder");NotificationManagerCompat.from(context).cancelAll();return}
        manager.enqueueUniquePeriodicWork("streak-refresh",ExistingPeriodicWorkPolicy.KEEP,PeriodicWorkRequestBuilder<StreakWorker>(1,TimeUnit.HOURS).build())
        if(settings.notifications)nextReminder(context,settings)else manager.cancelUniqueWork("streak-reminder")
    }
    fun nextReminder(context: Context,settings: Settings){
        val now=ZonedDateTime.now();var next=now.withHour(settings.notificationHour).withMinute(settings.notificationMinute).withSecond(0).withNano(0)
        if(!next.isAfter(now))next=next.plusDays(1)
        val work=OneTimeWorkRequestBuilder<RiskWorker>().setInitialDelay(Duration.between(now,next).toMillis(),TimeUnit.MILLISECONDS).build()
        WorkManager.getInstance(context).enqueueUniqueWork("streak-reminder",ExistingWorkPolicy.REPLACE,work)
    }
}
class StreakWorker(context: Context,params: WorkerParameters): CoroutineWorker(context,params) {
    override suspend fun doWork(): Result {
        val g=(applicationContext as StreaksApplication).graph
        if(g.store.current.isPro&&g.health.backgroundAllowed())g.health.refresh()
        return Result.success()
    }
}
class RiskWorker(context: Context,params: WorkerParameters): CoroutineWorker(context,params) {
    override suspend fun doWork(): Result {
        val g=(applicationContext as StreaksApplication).graph;val s=g.settings
        if(!g.store.current.isPro||!s.notifications)return Result.success()
        if(g.health.backgroundAllowed())g.health.refresh()
        val atRisk=com.jackwallner.streaks.model.Engine.reminder(g.streaks)
        val permitted=android.os.Build.VERSION.SDK_INT<33||ContextCompat.checkSelfPermission(applicationContext,Manifest.permission.POST_NOTIFICATIONS)==PackageManager.PERMISSION_GRANTED
        if(atRisk!=null&&permitted){
            val manager=applicationContext.getSystemService(NotificationManager::class.java);manager.createNotificationChannel(NotificationChannel("at-risk","At-risk streaks",NotificationManager.IMPORTANCE_DEFAULT))
            val intent=PendingIntent.getActivity(applicationContext,0,Intent(applicationContext,MainActivity::class.java),PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            NotificationManagerCompat.from(applicationContext).notify(1,NotificationCompat.Builder(applicationContext,"at-risk").setSmallIcon(R.drawable.ic_stat).setContentTitle("Keep the streak alive").setContentText("${atRisk.name}: today's goal is still waiting.").setContentIntent(intent).setAutoCancel(true).build())
        }
        Reminders.nextReminder(applicationContext,s);return Result.success()
    }
}
