package com.jackwallner.streaks

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.*
import org.junit.Test
import com.jackwallner.streaks.data.*
import com.jackwallner.streaks.model.*

class MemoryValues: Values {private val data=mutableMapOf<String,String>();override fun string(key: String)=data[key];override fun put(key: String,value: String){data[key]=value};override fun entries()=data.toMap()}
class BehaviorTest {
    private val today=LocalDate.of(2026,3,9)
    @Test fun catalogHasTwelveMetricsAnd34Workouts(){assertEquals(12,Catalog.metrics.size);assertEquals(34,Catalog.workouts.size);assertEquals(34,Catalog.workouts.map{it.key}.toSet().size)}
    @Test fun todayDoesNotBreakYesterdayRun(){val s=Engine.daily("steps",5000.0,(1L..5).associate{today.minusDays(it)to 5000.0},today);assertEquals(5,s.current);assertFalse(s.completed)}
    @Test fun thresholdZeroTerminates(){assertEquals(0,Engine.daily("steps",0.0,emptyMap(),today).current)}
    @Test fun freezeBridgesWithoutAddingDay(){val s=Engine.daily("steps",1.0,mapOf(today.minusDays(2)to 2.0,today.minusDays(3)to 2.0),today,setOf(today.minusDays(1)));assertEquals(2,s.current)}
    @Test fun expiredPreservationDoesNotBridgeSecondMiss(){val s=Engine.daily("steps",1.0,mapOf(today to 2.0),today);assertEquals(1,Engine.grace(s,Preservation("steps-daily",today.minusDays(4),20,"steps",1.0),today,.5,30).current)}
    @Test fun preservationPersistsContinuousRun(){val values=(0L..3).associate{today.minusDays(it)to 2.0};val s=Engine.daily("steps",1.0,values,today);assertEquals(24,Engine.grace(s,Preservation("steps-daily",today.minusDays(4),20,"steps",1.0),today,.5,30).current)}
    @Test fun weeklyHistoryUsesMondaySum(){val days=(0L..6).map{ActivityDay(today.plusDays(it),mapOf("workouts" to 1.0))};assertTrue(Engine.history(Streak("workouts",3.0,cadence="weekly"),days).all{it.third})}
    @Test fun customHourlyUsesHourlyRatherThanDailySteps(){val h=(0L..5).map{ActivityDay(today.minusDays(it),mapOf("steps" to 9000.0))};val hourly=h.associate{it.date to mapOf(17 to 500.0)};val result=Engine.discover(h,today,custom=listOf(CustomStreak("hour","steps",500.0,hour=17)),hourly=hourly);assertEquals(6,result.first{it.key=="custom-hour"}.current)}
    @Test fun customWorkoutDoesNotCountOtherType(){val h=(0L..5).map{ActivityDay(today.minusDays(it),mapOf("workouts" to 1.0),mapOf("running" to WorkoutStat(1.0,40.0,4.0)))};assertEquals(0,Engine.discover(h,today,custom=listOf(CustomStreak("yoga","workouts",1.0,workoutType="yoga",measure="count"))).first{it.customID=="yoga"}.current)}
    @Test fun trackingFreeCapIsThree(){val s=Settings(MemoryValues());assertTrue(s.track(setOf("a","b","c"),false));assertFalse(s.track(setOf("a","b","c","d"),false));assertEquals(3,s.tracked.size)}
    @Test fun paidUnlimitedAndExpiryCanKeepSelection(){val s=Settings(MemoryValues());assertTrue(s.track((1..10).map{it.toString()}.toSet(),true));assertEquals(10,s.tracked.size)}
    @Test fun customFreeCapIsThree(){val s=Settings(MemoryValues());repeat(3){assertTrue(s.custom(CustomStreak("$it","steps",3000.0),false))};assertFalse(s.custom(CustomStreak("4","steps",3000.0),false));assertTrue(s.custom(CustomStreak("0","steps",4000.0),false))}
    @Test fun invalidFreeFreezeDoesNotMutate(){val s=Settings(MemoryValues());assertFalse(s.freeze(today,false));assertTrue(s.freezes.isEmpty());assertTrue(s.freeze(today,true));assertTrue(today in s.freezes)}
    @Test fun upgradeRestoresFullOnboardingIntent(){val values=MemoryValues();val s=Settings(values);s.finish(listOf("a","b","c","d","e"),false);assertEquals(3,s.tracked.size);s.upgrade();assertEquals(5,s.tracked.size);assertEquals(5,Settings(values).tracked.size);assertEquals(listOf("a","b","c","d","e"),Settings(values).order)}
    @Test fun commitsOnlyNewDiscoveryGoals(){val s=Settings(MemoryValues());s.commit(listOf(Streak("steps",5000.0)));s.commit(listOf(Streak("steps",10000.0)));assertEquals(5000.0,s.committed["steps-daily"]!!,0.0);s.recalibrate("steps-daily");assertTrue(s.committed.isEmpty())}
    @Test fun settingsRoundTrip(){val v=MemoryValues();val s=Settings(v);s.appearance(1);s.intensity(2);s.lookback(90);s.primary("steps-daily");s.custom(CustomStreak("abc","workouts",20.0,workoutType="running",measure="minutes"),true);val restored=Settings(v);assertEquals(1,restored.appearance);assertEquals(2,restored.intensity);assertEquals(90,restored.lookback);assertEquals("running",restored.custom.single().workoutType);assertEquals(listOf("steps-daily"),restored.order)}
    @Test fun preservationAndBrokenPersistence(){val v=MemoryValues();val s=Settings(v);val d=LocalDate.now();s.broken(BrokenStreak("steps-daily","steps",5000.0,20,d));assertEquals(1,Settings(v).broken.size);s.preserve(Preservation("steps-daily",d,20,"steps",5000.0));assertTrue(Settings(v).broken.isEmpty());assertEquals(20,Settings(v).preservations["steps-daily"]!!.length)}
    @Test fun cacheRoundTrip(){val d=ActivityDay(today,mapOf("steps" to 8500.0,"exerciseMinutes" to 40.0,"activeEnergy" to 400.0),mapOf("running" to WorkoutStat(1.0,40.0,4.0)));assertEquals(listOf(d),Codec.days(Codec.days(listOf(d)).toString()));assertEquals(10.0,d.value("intensityRatio"),0.0)}
    @Test fun overlappingIntervalsCountOnce(){val zero=Instant.EPOCH;assertEquals(15000,HealthMath.unionMillis(listOf(zero to zero.plusSeconds(10),zero.plusSeconds(5)to zero.plusSeconds(15))))}
    @Test fun sparseCardioCapsGaps(){assertEquals(65.0/60,HealthMath.cardioMinutes(listOf(Instant.EPOCH,Instant.EPOCH.plusSeconds(100),Instant.EPOCH.plusSeconds(200))),1e-9)}
    @Test fun calendarHandlesSpringAndFallDst(){val zone=ZoneId.of("America/Los_Angeles");assertEquals(23,java.time.Duration.between(LocalDate.of(2026,3,8).atStartOfDay(zone),LocalDate.of(2026,3,9).atStartOfDay(zone)).toHours());assertEquals(25,java.time.Duration.between(LocalDate.of(2026,11,1).atStartOfDay(zone),LocalDate.of(2026,11,2).atStartOfDay(zone)).toHours())}
    @Test fun liveValuesNeverRoundToGoal(){assertEquals("4999",Catalog.metric("steps").format(4999.9,true));assertEquals("7.9",Catalog.metric("sleepHours").format(7.99,true))}
    @Test fun reviewsWaitForPositiveSecondLaunch(){val r=ReviewTracker(MemoryValues());r.launch();r.positive();assertFalse(r.eligible(true,false));r.launch();assertTrue(r.eligible(true,false));assertFalse(r.eligible(true,true))}
    @Test fun feedbackDoesNotEndReviewAsks(){val v=MemoryValues();val r=ReviewTracker(v);r.launch();r.launch();r.positive();r.feedback();assertTrue(r.eligible(true,false));r.openedReview();r.positive();assertFalse(r.eligible(true,false))}
    @Test fun reviewCooldownIsThirtyDays(){var now=0L;val r=ReviewTracker(MemoryValues()){now};r.launch();r.launch();r.positive();r.shown();r.positive();now=29*86400000L;assertFalse(r.eligible(true,false));now=30*86400000L;assertTrue(r.eligible(true,false))}
    @Test fun automatedRunsNeverAskForReview(){val r=ReviewTracker(MemoryValues());r.launch();r.launch();r.positive();r.automation=true;assertFalse(r.eligible(true,false))}
    @Test fun corruptedCacheIsEmpty(){assertTrue(Codec.days("broken").isEmpty())}
    @Test fun suspiciousEmptyRefreshDoesNotKillCachedStreaks(){val cached=listOf(ActivityDay(today.minusDays(1),mapOf("steps" to 5000.0)));val fresh=listOf(ActivityDay(today.minusDays(1)));assertTrue(HealthMath.likelyDataLoss(fresh,cached,today));assertFalse(HealthMath.likelyDataLoss(fresh,emptyList(),today))}
    @Test fun narrowPastGapUsesCacheButTodayStaysLive(){val yesterday=today.minusDays(1);val cached=listOf(ActivityDay(yesterday,mapOf("steps" to 7000.0)),ActivityDay(today,mapOf("steps" to 8000.0)));val fresh=listOf(ActivityDay(yesterday),ActivityDay(today));val merged=HealthMath.mergeMissing(fresh,cached,today);assertEquals(7000.0,merged.first().value("steps"),0.0);assertEquals(0.0,merged.last().value("steps"),0.0)}

    @Test fun reminderFindsSecondaryLongestAtRiskAndIgnoresNewRun(){val complete=Streak("steps",5000.0,current=20,completed=true);val secondary=Streak("workouts",1.0,current=6);assertEquals(secondary,Engine.reminder(listOf(complete,Streak("sleepHours",7.0,current=1),secondary)));assertNull(Engine.reminder(listOf(Streak("steps",5000.0,current=1))))}
    @Test fun midnightHoursAreAdjacent(){assertEquals(1,Engine.circularHourDistance(23,0));assertEquals(3,Engine.circularHourDistance(22,1))}

}
