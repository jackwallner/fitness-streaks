package com.jackwallner.streaks;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;

import android.app.Activity;
import android.content.Intent;
import android.health.connect.HealthConnectException;
import android.health.connect.HealthConnectManager;
import android.health.connect.InsertRecordsResponse;
import android.health.connect.RecordIdFilter;
import android.health.connect.datatypes.ExerciseSegment;
import android.health.connect.datatypes.ExerciseSegmentType;
import android.health.connect.datatypes.ExerciseSessionRecord;
import android.health.connect.datatypes.ExerciseSessionType;
import android.health.connect.datatypes.HeartRateRecord;
import android.health.connect.datatypes.Metadata;
import android.health.connect.datatypes.StepsRecord;
import android.health.connect.datatypes.Record;
import android.os.Bundle;
import android.os.OutcomeReceiver;

/** Standalone test APK process, using only framework APIs and its own write grants. */
public final class FixtureWriterActivity extends Activity {
    public static final String RESULT_ACTION = "com.jackwallner.streaks.FIXTURE_READY";

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        if ("androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE".equals(getIntent().getAction())) {
            android.widget.TextView text = new android.widget.TextView(this);
            text.setText("Temporary Health Connect test fixture writer. Writes only synthetic records on the owned test AVD.");
            setContentView(text);
            return;
        }
        if ("authorize".equals(getIntent().getStringExtra("operation"))) {
            requestPermissions(new String[]{"android.permission.health.WRITE_STEPS", "android.permission.health.WRITE_EXERCISE", "android.permission.health.WRITE_HEART_RATE"}, 51);
            return;
        }
        try {
            HealthConnectManager manager = getSystemService(HealthConnectManager.class);
            if ("clear".equals(getIntent().getStringExtra("operation"))) {
                manager.deleteRecords(List.of(
                    RecordIdFilter.fromClientRecordId(ExerciseSessionRecord.class, "sol-streaks-run"),
                    RecordIdFilter.fromClientRecordId(HeartRateRecord.class, "sol-streaks-heart"),
                    RecordIdFilter.fromClientRecordId(StepsRecord.class, "sol-streaks-steps")
                ), getMainExecutor(), new OutcomeReceiver<Void, HealthConnectException>() {
                    @Override public void onResult(Void result) { complete(null); }
                    @Override public void onError(HealthConnectException error) { complete(error); }
                });
                return;
            }
            Instant end = java.time.LocalDate.now().minusDays(1).atTime(13, 0).atZone(java.time.ZoneId.systemDefault()).toInstant();
            Instant start = end.minusSeconds(3600);
            ExerciseSessionRecord workout = new ExerciseSessionRecord.Builder(
                metadata("sol-streaks-run"), start, end, ExerciseSessionType.EXERCISE_SESSION_TYPE_RUNNING
            ).setStartZoneOffset(ZoneOffset.UTC).setEndZoneOffset(ZoneOffset.UTC)
                .setSegments(List.of(new ExerciseSegment.Builder(
                    start.plusSeconds(1800), start.plusSeconds(2400), ExerciseSegmentType.EXERCISE_SEGMENT_TYPE_PAUSE
                ).build())).build();
            List<HeartRateRecord.HeartRateSample> samples = new ArrayList<>();
            for (int index = 0; index < 60; index++) {
                samples.add(new HeartRateRecord.HeartRateSample(155L, start.plusSeconds(index * 60L)));
            }
            HeartRateRecord heart = new HeartRateRecord.Builder(metadata("sol-streaks-heart"), start, end, samples)
                .setStartZoneOffset(ZoneOffset.UTC).setEndZoneOffset(ZoneOffset.UTC).build();
            StepsRecord steps = new StepsRecord.Builder(metadata("sol-streaks-steps"), start, end, 5000L).build();
            manager.insertRecords(List.<Record>of(workout, heart, steps), getMainExecutor(),
                new OutcomeReceiver<InsertRecordsResponse, HealthConnectException>() {
                    @Override public void onResult(InsertRecordsResponse result) { complete(null); }
                    @Override public void onError(HealthConnectException error) { complete(error); }
                });
        } catch (Exception error) { complete(error); }
    }
    @Override public void onRequestPermissionsResult(int code, String[] permissions, int[] results) {
        super.onRequestPermissionsResult(code, permissions, results);
        if (code != 51) return;
        boolean granted = results.length == 3;
        for (int result : results) granted &= result == android.content.pm.PackageManager.PERMISSION_GRANTED;
        complete(granted ? null : new IllegalStateException("Fixture write access was not granted"));
    }
    private Metadata metadata(String id) {
        return new Metadata.Builder().setClientRecordId(id).setClientRecordVersion(System.currentTimeMillis())
            .setRecordingMethod(Metadata.RECORDING_METHOD_AUTOMATICALLY_RECORDED).build();
    }
    private void complete(Exception error) {
        Intent response = new Intent(RESULT_ACTION).setPackage(getPackageName().replaceFirst("\\.test$", ""))
            .putExtra("request", getIntent().getStringExtra("request"));
        if (error != null) response.putExtra("error", error.getClass().getSimpleName() + ": " + error.getMessage());
        sendBroadcast(response);
        finish();
    }
}
