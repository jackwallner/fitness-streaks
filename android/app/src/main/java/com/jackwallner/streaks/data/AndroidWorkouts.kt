package com.jackwallner.streaks.data

import androidx.health.connect.client.records.ExerciseSessionRecord as Exercise

object AndroidWorkouts {
    private val mapping: Map<Int,String> = mapOf(
        Exercise.EXERCISE_TYPE_RUNNING to "running",Exercise.EXERCISE_TYPE_RUNNING_TREADMILL to "running",
        Exercise.EXERCISE_TYPE_WALKING to "walking",Exercise.EXERCISE_TYPE_HIKING to "hiking",
        Exercise.EXERCISE_TYPE_BIKING to "cycling",Exercise.EXERCISE_TYPE_BIKING_STATIONARY to "cycling",
        Exercise.EXERCISE_TYPE_SWIMMING_POOL to "swimming",Exercise.EXERCISE_TYPE_SWIMMING_OPEN_WATER to "swimming",
        Exercise.EXERCISE_TYPE_ROWING to "rowing",Exercise.EXERCISE_TYPE_ROWING_MACHINE to "rowing",
        Exercise.EXERCISE_TYPE_ELLIPTICAL to "elliptical",Exercise.EXERCISE_TYPE_STAIR_CLIMBING to "stairClimbing",Exercise.EXERCISE_TYPE_STAIR_CLIMBING_MACHINE to "stairClimbing",
        Exercise.EXERCISE_TYPE_YOGA to "yoga",Exercise.EXERCISE_TYPE_PILATES to "pilates",Exercise.EXERCISE_TYPE_CALISTHENICS to "functionalStrength",
        Exercise.EXERCISE_TYPE_STRENGTH_TRAINING to "traditionalStrength",Exercise.EXERCISE_TYPE_WEIGHTLIFTING to "traditionalStrength",
        Exercise.EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING to "hiit",Exercise.EXERCISE_TYPE_DANCING to "cardioDance",
        Exercise.EXERCISE_TYPE_BOXING to "boxing",Exercise.EXERCISE_TYPE_MARTIAL_ARTS to "martialArts",Exercise.EXERCISE_TYPE_ROCK_CLIMBING to "climbing",
        Exercise.EXERCISE_TYPE_TENNIS to "tennis",Exercise.EXERCISE_TYPE_BASKETBALL to "basketball",Exercise.EXERCISE_TYPE_SOCCER to "soccer",
        Exercise.EXERCISE_TYPE_GOLF to "golf",Exercise.EXERCISE_TYPE_ICE_SKATING to "skating",Exercise.EXERCISE_TYPE_SKATING to "skating",
        Exercise.EXERCISE_TYPE_SKIING to "downhillSkiing",Exercise.EXERCISE_TYPE_SNOWBOARDING to "snowboarding",Exercise.EXERCISE_TYPE_SURFING to "surfing",
        Exercise.EXERCISE_TYPE_PADDLING to "paddleSports",Exercise.EXERCISE_TYPE_GUIDED_BREATHING to "mindAndBody"
    )
    fun key(type: Int)=mapping[type]
    val available get()=mapping.values.toSet()
}
