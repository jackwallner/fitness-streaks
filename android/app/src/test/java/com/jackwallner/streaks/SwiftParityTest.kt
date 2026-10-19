package com.jackwallner.streaks

import java.time.LocalDate
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.Parameterized
import com.jackwallner.streaks.model.*

@RunWith(Parameterized::class)
class SwiftParityTest(private val name: String,private val kind: String,private val fixture: JSONObject) {
    companion object {
        @JvmStatic @Parameterized.Parameters(name="{0}") fun cases(): List<Array<Any>> {val data=JSONObject(SwiftParityTest::class.java.getResourceAsStream("/swift-parity.json")!!.bufferedReader().use{it.readText()});return listOf("daily","discoveries").flatMap{k->val a=data.getJSONArray(k);(0 until a.length()).map{arrayOf<Any>("$k-$it",k,a.getJSONObject(it))}}}
    }
    private fun strings(a: JSONArray)=(0 until a.length()).map(a::getString)
    private fun dates(a: JSONArray)=strings(a).map(LocalDate::parse).toSet()
    private fun nullable(o: JSONObject,key: String)=if(o.isNull(key))null else o.getString(key)
    private fun check(s: Streak,o: JSONObject){
        assertEquals(o.getString("key"),s.key);assertEquals(o.getString("id"),s.id);assertEquals(o.getString("cadence"),s.cadence);assertEquals(o.getDouble("threshold"),s.threshold,1e-9)
        assertEquals(o.getInt("current"),s.current);assertEquals(o.getInt("best"),s.best);assertEquals(o.getBoolean("completed"),s.completed)
        assertEquals(nullable(o,"start"),s.start?.toString());assertEquals(nullable(o,"lastHit"),s.lastHit?.toString());assertEquals(nullable(o,"lastMissed"),s.lastMissed?.toString())
        assertEquals(o.getDouble("progress"),s.progress,1e-9);assertEquals(o.getDouble("value"),s.value,1e-9);assertEquals(o.getDouble("rate"),s.rate,1e-9);assertEquals(o.getDouble("score"),s.score,1e-9);assertEquals(o.getInt("lookback"),s.lookback)
        assertEquals(nullable(o,"customID"),s.customID);assertEquals(nullable(o,"workoutType"),s.workoutType);assertEquals(nullable(o,"measure"),s.measure)
    }
    @Test fun matchesOriginalSwiftEngine(){val f=fixture;val today=LocalDate.parse(f.getString("today"))
        if(kind=="daily") {val a=f.getJSONArray("values");val values=(0 until a.length()).associate{i->a.getJSONObject(i).let{LocalDate.parse(it.getString("date"))to it.getDouble("value")}};check(Engine.daily(f.getString("metric"),f.getDouble("threshold"),values,today,dates(f.getJSONArray("freezes"))),f.getJSONObject("expected"));return}
        val h=f.getJSONArray("history");val history=(0 until h.length()).map{i->val d=h.getJSONObject(i);val v=d.getJSONArray("values");val w=d.getJSONArray("running");ActivityDay(LocalDate.parse(d.getString("date")),Catalog.metrics.mapIndexed{index,m->m.key to v.getDouble(index)}.toMap(),mapOf("running" to WorkoutStat(w.getDouble(0),w.getDouble(1),w.getDouble(2))))}
        val c=f.getJSONObject("custom");val custom=CustomStreak(c.getString("id"),c.getString("metric"),c.getDouble("threshold"),c.getString("cadence"),workoutType=c.getString("workoutType"),measure=c.getString("measure"))
        val committed=f.getJSONObject("committed").let{o->o.keys().asSequence().associateWith(o::getDouble)}
        val grace=nullable(f,"graceMissed")?.let{mapOf("steps-daily" to Preservation("steps-daily",LocalDate.parse(it),10,"steps",5000.0))}.orEmpty()
        val result=Engine.discover(history,today,f.getInt("intensity"),f.getInt("lookback"),strings(f.getJSONArray("hidden")).toSet(),committed,listOf(custom),grace,dates(f.getJSONArray("freezes")))
        val expected=f.getJSONArray("expected");assertEquals(expected.length(),result.size);result.forEachIndexed{i,s->check(s,expected.getJSONObject(i))}
    }
}
