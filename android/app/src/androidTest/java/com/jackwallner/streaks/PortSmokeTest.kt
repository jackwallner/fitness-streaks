package com.jackwallner.streaks

import java.time.LocalDate
import android.content.ContentValues
import android.content.Intent
import android.graphics.Bitmap
import android.provider.MediaStore
import androidx.compose.ui.test.*
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.test.core.app.ActivityScenario
import androidx.test.core.app.ApplicationProvider
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import com.jackwallner.streaks.data.*
import com.jackwallner.streaks.model.*

class PortSmokeTest {
    @get:Rule val compose=createEmptyComposeRule()
    private var scenario: ActivityScenario<MainActivity>?=null
    private val app get()=ApplicationProvider.getApplicationContext<StreaksApplication>()
    private val instrumentation get()=InstrumentationRegistry.getInstrumentation()
    private fun launch(pro: Boolean=false,seed: Boolean=true,onboarding: Boolean=false,dark: Boolean=false,route: String?=null){
        val intent=Intent(app,MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK).putExtra("uiTest",true).putExtra("forcePro",pro).putExtra("seedScreenshotData",seed).putExtra("skipOnboarding",!onboarding).putExtra("appearance",if(dark)"dark"else"light")
        if(route!=null)intent.putExtra("route",route)
        scenario=ActivityScenario.launch(intent);compose.waitForIdle()
    }
    private fun click(text: String){val node=compose.onNodeWithText(text);if(!node.isDisplayed())node.performScrollTo();node.performClick();compose.waitForIdle()}
    private fun screenshot(name: String){val values=ContentValues().apply{put(MediaStore.Images.Media.DISPLAY_NAME,"$name.png");put(MediaStore.Images.Media.MIME_TYPE,"image/png");put(MediaStore.Images.Media.RELATIVE_PATH,"Pictures/sol-streaks")};val uri=app.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,values)!!;app.contentResolver.openOutputStream(uri)!!.use{instrumentation.uiAutomation.takeScreenshot().compress(Bitmap.CompressFormat.PNG,100,it)}}
    @After fun close(){scenario?.close()}
    @Test fun firstRunCanFinishWithoutHealthOrPurchase(){launch(seed=false,onboarding=true);compose.onNodeWithText("YOU'RE ALREADY\nON A STREAK.").assertIsDisplayed();click("▶ GET STARTED");click("CONTINUE WITHOUT HEALTH");click("▶ CONTINUE");compose.onNodeWithText("NO ACTIVE STREAKS").assertIsDisplayed();assertFalse(app.graph.store.current.isPro);assertTrue(app.graph.settings.setup);screenshot("01-empty")}
    @Test fun freeDashboardShowsThreeTrackedStreaks(){launch();assertEquals(3,app.graph.streaks.size);compose.onNodeWithText("YOUR HERO · STEPS").assertIsDisplayed();screenshot("02-streaks-light")}
    @Test fun subscriberDashboardCanTrackAllFive(){launch(pro=true,dark=true);assertEquals(5,app.graph.streaks.size);compose.onNodeWithText("YOUR HERO · STEPS").assertIsDisplayed();screenshot("03-streaks-dark")}
    @Test fun detailHistoryIsPaid(){launch(route="detail:steps-daily");click("UNLOCK WITH STREAKS+");compose.onNodeWithText("DON'T BREAK\nTHE STREAK.").assertIsDisplayed();assertFalse(app.graph.store.current.isPro)}
    @Test fun subscriberHistoryShowsActualHeatmap(){launch(pro=true,route="detail:steps-daily");compose.onNodeWithText("BY DAY OF WEEK").performScrollTo().assertIsDisplayed();compose.onNodeWithText("90D").performScrollTo().performClick();screenshot("04-history")}
    @Test fun untrackRemovesOnlyDashboardItem(){launch(route="detail:steps-daily");click("UNTRACK STREAK");click("CONFIRM");assertFalse("steps-daily" in app.graph.settings.tracked);assertTrue(app.graph.candidates.any{it.key=="steps-daily"});assertTrue(app.graph.health.history.isNotEmpty())}
    @Test fun makePrimaryPersistsManualOrder(){launch(route="detail:sleepHours-daily");click("MAKE PRIMARY");assertEquals("sleepHours-daily",app.graph.streaks.first().key);assertEquals("sleepHours-daily",Settings(app.graph.values).order.first())}
    @Test fun freeSavesOffersUpgrade(){launch();click("SAVES");compose.onNodeWithText("AUTO-SAVE LOCKED").assertIsDisplayed();click("UNLOCK STREAKS+");compose.onNodeWithText("DON'T BREAK\nTHE STREAK.").assertIsDisplayed()}
    @Test fun paidFreezeAddsAndRemovesWithoutIncrementingRun(){launch(pro=true,route="freeze");click("SAVE FREEZE DAY");assertTrue(LocalDate.now().plusDays(1) in app.graph.settings.freezes);click("SAVES");click("${LocalDate.now().plusDays(1)} · REMOVE");assertFalse(LocalDate.now().plusDays(1) in app.graph.settings.freezes)}
    @Test fun statsReflectTrackedStreaks(){launch();click("STATS");compose.onNodeWithText("3 ACTIVE STREAKS").assertIsDisplayed();screenshot("05-stats")}
    @Test fun freeFourthSelectionOpensPaywall(){launch(route="picker");val candidate=app.graph.candidates.first{it.key !in app.graph.settings.tracked};click("□ ${candidate.name.uppercase()} · ${candidate.label}");compose.onNodeWithText("DON'T BREAK\nTHE STREAK.").assertIsDisplayed();assertEquals(3,app.graph.settings.tracked.size)}
    @Test fun customGoalValidationAndPersistence(){launch(pro=true,route="custom");compose.onNodeWithText("Daily goal").performScrollTo().performTextReplacement("0");click("CREATE STREAK");compose.onNodeWithText("Enter a goal greater than zero.").assertIsDisplayed();compose.onNodeWithText("Daily goal").performScrollTo().performTextReplacement("4500");click("CREATE STREAK");assertEquals(4500.0,app.graph.settings.custom.single().threshold,0.0);assertEquals(1,Settings(app.graph.values).custom.size)}
    @Test fun customTimedGoalCanBeCreated(){launch(pro=true,route="custom");click("TIME WINDOW OFF");click(hourLabel(10));click(hourLabel(17));click("CREATE STREAK");assertEquals(17,app.graph.settings.custom.single().hour)}
    @Test fun settingsHasSeparateFeedbackAndReview(){launch(route="settings");compose.onNodeWithText("RATE STREAKS").performScrollTo().assertIsDisplayed();compose.onNodeWithText("SEND FEEDBACK").performScrollTo().assertIsDisplayed();compose.onNodeWithText("READ-ONLY · HEALTH DATA LOCAL-ONLY",substring=true).performScrollTo().assertIsDisplayed()}
    @Test fun settingsAppearancePersists(){launch(route="settings");click("DARK");assertEquals(1,app.graph.settings.appearance);assertEquals(1,Settings(app.graph.values).appearance);screenshot("06-settings-dark")}
    @Test fun reviewerAccessRejectsWrongCodeAndPersistsValidGrant()=runBlocking {
        val code=checkNotNull(InstrumentationRegistry.getArguments().getString("reviewCode")){"Supply the private reviewer code through the local test harness."}
        launch(route="settings")
        compose.onNodeWithText("STREAK FINDER 1.3.1",substring=true).performScrollTo().performTouchInput{longClick()}
        compose.onNodeWithText("Reviewer code").performTextInput("wrong")
        click("UNLOCK")
        compose.onNodeWithText("That code isn't valid.").assertIsDisplayed()
        assertFalse(app.graph.store.current.isPro)
        compose.onNodeWithText("Reviewer code").performTextClearance()
        compose.onNodeWithText("Reviewer code").performTextInput(code)
        click("UNLOCK")
        assertTrue(app.graph.store.current.isPro)
        app.graph.store.start()
        assertTrue(app.graph.store.current.isPro)
        assertTrue(StoreService(app,app.graph.diagnostics).current.isPro)
    }
    @Test fun permissionsAndLocalDeletionClearHealthHistory(){launch(route="settings");click("DISCONNECT & DELETE LOCAL HEALTH DATA");click("CONFIRM");compose.waitUntil(15000){app.graph.health.history.isEmpty()};assertTrue(app.graph.streaks.isEmpty());assertTrue(Codec.days(app.graph.values.string("healthCache")?:"[]").isEmpty())}
    @Test fun backgroundAndProGatesNeverGrantFreezesForFree(){launch();assertFalse(app.graph.settings.freeze(LocalDate.now(),false));assertEquals(3,app.graph.streaks.size);assertFalse(app.graph.store.current.isPro)}
    @Test fun perTabBackStacksStayIndependent(){launch(route="detail:steps-daily");click("STATS");compose.onNodeWithText("3 ACTIVE STREAKS").assertIsDisplayed();click("STREAKS");compose.onNodeWithText("UNTRACK STREAK").performScrollTo().assertIsDisplayed()}
    @Test fun tutorialExplainsMetricDifferences(){launch(route="privacy");compose.onNodeWithText("Workout minutes come",substring=true).performScrollTo().assertIsDisplayed();compose.onNodeWithText("1. Connect Health Connect.",substring=true).performScrollTo().assertIsDisplayed()}
    private suspend fun writeFixture(operation: String) {
        val result=kotlinx.coroutines.CompletableDeferred<String?>();val request=java.util.UUID.randomUUID().toString()
        val receiver=object: android.content.BroadcastReceiver(){override fun onReceive(context: android.content.Context,intent: Intent){if(intent.getStringExtra("request")==request)result.complete(intent.getStringExtra("error"))}}
        app.registerReceiver(receiver,android.content.IntentFilter(FixtureWriterActivity.RESULT_ACTION),android.content.Context.RECEIVER_EXPORTED)
        try{app.startActivity(Intent().setComponent(android.content.ComponentName(instrumentation.context.packageName,FixtureWriterActivity::class.java.name)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK).putExtra("operation",operation).putExtra("request",request));val error=kotlinx.coroutines.withTimeout(90000){result.await()};assertNull(error,error)}finally{app.unregisterReceiver(receiver)}
    }
    @Test fun realHealthConnectImportReadsStepsPausedWorkoutAndHeartRate()=runBlocking {
        launch(seed=false)
        listOf("EXERCISE","HEART_RATE","STEPS").forEach {type->instrumentation.uiAutomation.revokeRuntimePermission(instrumentation.context.packageName,"android.permission.health.WRITE_$type");instrumentation.uiAutomation.grantRuntimePermission(app.packageName,"android.permission.health.READ_$type")}
        val authorizing=async(kotlinx.coroutines.Dispatchers.IO){writeFixture("authorize")}
        val device=androidx.test.uiautomator.UiDevice.getInstance(instrumentation)
        device.wait(androidx.test.uiautomator.Until.findObject(androidx.test.uiautomator.By.text("Get started")),10000)?.click()
        val all=device.wait(androidx.test.uiautomator.Until.findObject(androidx.test.uiautomator.By.text("Allow all")),30000) ?: throw AssertionError("Health Connect permission sheet")
        assertNotNull("Health Connect permission sheet",all);all.click()
        val allow=device.wait(androidx.test.uiautomator.Until.findObject(androidx.test.uiautomator.By.text("Allow")),10000) ?: throw AssertionError("Health Connect Allow action")
        assertNotNull("Health Connect Allow action",allow);allow.click();authorizing.await()
        try {
            writeFixture("write");instrumentation.waitForIdleSync();app.graph.health.refresh()
            val client=androidx.health.connect.client.HealthConnectClient.getOrCreate(app)
            val start=LocalDate.now().minusDays(1).atStartOfDay(java.time.ZoneId.systemDefault()).toInstant()
            val end=LocalDate.now().atStartOfDay(java.time.ZoneId.systemDefault()).toInstant()
            val raw=client.readRecords(androidx.health.connect.client.request.ReadRecordsRequest(androidx.health.connect.client.records.StepsRecord::class,androidx.health.connect.client.time.TimeRangeFilter.between(start,end))).records.sumOf{it.count}
            val direct=client.aggregate(androidx.health.connect.client.request.AggregateRequest(setOf(androidx.health.connect.client.records.StepsRecord.COUNT_TOTAL),androidx.health.connect.client.time.TimeRangeFilter.between(start,end)))[androidx.health.connect.client.records.StepsRecord.COUNT_TOTAL]
            println("Health fixture: raw steps=$raw, direct aggregate=$direct, message=${app.graph.health.message}")
            val day=app.graph.health.history.first{it.date==LocalDate.now().minusDays(1)}
            assertEquals("raw=$raw direct=$direct message=${app.graph.health.message}",5000.0,day.value("steps"),.01)
            assertEquals(5000.0,app.graph.health.hourly[day.date]?.get(12)?:0.0,.01)
            assertEquals(50.0,day.value("exerciseMinutes"),.01)
            assertEquals(1.0,day.value("workouts"),.01)
            assertEquals(50.0,day.workouts["running"]!!.minutes,.01)
            assertEquals((5+59*30)/60.0,day.value("heartRateMinutes"),.01)
            assertEquals(app.graph.health.history,Codec.days(app.graph.values.string("healthCache")!!))
        }finally{writeFixture("clear")}
    }
    @Test fun partialPermissionGrantClearsRevokedOptionalInputs()=runBlocking {
        instrumentation.uiAutomation.grantRuntimePermission(app.packageName,"android.permission.health.READ_STEPS")
        app.graph.values.put("healthGranted",org.json.JSONArray(listOf("android.permission.health.READ_STEPS","android.permission.health.READ_HEART_RATE")).toString())
        app.graph.values.put("healthCache",Codec.days(listOf(ActivityDay(LocalDate.now(),mapOf("steps" to 5000.0,"heartRateMinutes" to 30.0)))).toString())
        app.graph.health.refresh()
        assertFalse(app.graph.health.supportedMetrics().contains("heartRateMinutes"))
        assertTrue(app.graph.health.history.all{it.value("heartRateMinutes")==0.0})
    }

}
