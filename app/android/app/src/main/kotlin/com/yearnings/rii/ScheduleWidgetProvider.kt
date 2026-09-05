package com.yearnings.rii

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

class ScheduleWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val widgetComponent = ComponentName(context, ScheduleWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(widgetComponent)
            val provider = ScheduleWidgetProvider()
            for (widgetId in widgetIds) {
                provider.updateWidget(context, appWidgetManager, widgetId)
            }
        }
    }

    private fun getIntOrLong(prefs: android.content.SharedPreferences, key: String, defaultVal: Int = 0): Int {
        return try {
            prefs.getInt(key, defaultVal)
        } catch (e: ClassCastException) {
            try {
                prefs.getLong(key, defaultVal.toLong()).toInt()
            } catch (e2: Exception) {
                defaultVal
            }
        } catch (e: Exception) {
            defaultVal
        }
    }

    private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val views = RemoteViews(context.packageName, R.layout.schedule_widget)

        // Клик по виджету открывает главное приложение
        val intent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val groupName = prefs.getString("flutter.group_name", null) ?: "РИИ"
            val subgroup = getIntOrLong(prefs, "flutter.subgroup", 0)
            val groupId = getIntOrLong(prefs, "flutter.group_id", 0)

            // Пытаемся взять JSON расписания
            var scheduleJsonStr = prefs.getString("flutter.widget_schedule_json", null)
            if (scheduleJsonStr.isNullOrEmpty() && groupId > 0) {
                scheduleJsonStr = prefs.getString("flutter.schedule_cache_$groupId", null)
            }

            views.setTextViewText(R.id.widget_group_name, groupName)

            // Время по Рубцовску (UTC+7)
            val tz = TimeZone.getTimeZone("GMT+7")
            val cal = Calendar.getInstance(tz)
            val dayOfWeekCalendar = cal.get(Calendar.DAY_OF_WEEK) // 1=Sun, 2=Mon...
            val curHour = cal.get(Calendar.HOUR_OF_DAY)
            val curMin = cal.get(Calendar.MINUTE)
            val curMins = curHour * 60 + curMin

            // Переводим в систему Пн=1 .. Сб=6, Вс=7
            val rDay = when (dayOfWeekCalendar) {
                Calendar.MONDAY -> 1
                Calendar.TUESDAY -> 2
                Calendar.WEDNESDAY -> 3
                Calendar.THURSDAY -> 4
                Calendar.FRIDAY -> 5
                Calendar.SATURDAY -> 6
                else -> 7 // Воскресенье
            }

            val dayNames = arrayOf("Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс")
            val curDayStr = dayNames.getOrElse(rDay - 1) { "Пн" }
            val dateFormat = SimpleDateFormat("d MMM", Locale("ru"))
            dateFormat.timeZone = tz
            val dateFormatted = dateFormat.format(cal.time)

            if (scheduleJsonStr.isNullOrEmpty()) {
                views.setTextViewText(R.id.widget_date_week, "$curDayStr, $dateFormatted")
                views.setTextViewText(R.id.widget_status_text, "Данные расписания")
                views.setTextViewText(R.id.widget_subject_text, "Откройте приложение для загрузки")
                views.setTextViewText(R.id.widget_details_text, "Нажмите на виджет для входа")
                views.setTextViewText(R.id.widget_next_text, "Расписание сохраняется для работы офлайн")
                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            val json = JSONObject(scheduleJsonStr)
            val weekNumber = json.optInt("weekNumber", 1)
            val weekRoman = if (weekNumber == 2) "II нед" else "I нед"
            views.setTextViewText(R.id.widget_date_week, "$curDayStr, $dateFormatted • $weekRoman")

            if (rDay == 7) {
                // Воскресенье
                views.setTextViewText(R.id.widget_status_text, "Выходной день")
                views.setTextViewText(R.id.widget_subject_text, "Занятий нет")
                views.setTextViewText(R.id.widget_details_text, "Подготовка к следующей учебной неделе")
                views.setTextViewText(R.id.widget_next_text, "В понедельник новая учебная неделя")
                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            val scheduleData = json.optJSONObject("scheduleData")
            val weekObj = scheduleData?.optJSONObject(weekNumber.toString())
            val dayObj = weekObj?.optJSONObject(rDay.toString())

            if (dayObj == null || dayObj.length() == 0) {
                views.setTextViewText(R.id.widget_status_text, "Сегодня пар нет")
                views.setTextViewText(R.id.widget_subject_text, "Свободный день")
                views.setTextViewText(R.id.widget_details_text, "Занятия по расписанию отсутствуют")
                views.setTextViewText(R.id.widget_next_text, "Далее: отдых")
                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            // Стандартное расписание звонков РИИ
            val defaultTimes = mapOf(
                1 to Pair(510, 600),   // 08:30 - 10:00
                2 to Pair(610, 700),   // 10:10 - 11:40
                3 to Pair(730, 820),   // 12:10 - 13:40
                4 to Pair(830, 920),   // 13:50 - 15:20
                5 to Pair(930, 1020),  // 15:30 - 17:00
                6 to Pair(1030, 1120)  // 17:10 - 18:40
            )

            val timeStrings = mapOf(
                1 to "08:30 - 10:00",
                2 to "10:10 - 11:40",
                3 to "12:10 - 13:40",
                4 to "13:50 - 15:20",
                5 to "15:30 - 17:00",
                6 to "17:10 - 18:40"
            )

            data class ParaParsed(
                val num: Int,
                val startMin: Int,
                val endMin: Int,
                val timeStr: String,
                val subject: String,
                val details: String
            )

            val dayParas = mutableListOf<ParaParsed>()

            for (pNum in 1..6) {
                val pObj = dayObj.optJSONObject(pNum.toString()) ?: continue
                val times = defaultTimes[pNum] ?: Pair(0, 0)

                val isDouble = pObj.optBoolean("isDouble", false)
                var subj = ""
                var aud = ""
                var teacher = ""
                var pType = ""

                if (!isDouble) {
                    subj = pObj.optString("subj1", "")
                    aud = pObj.optString("aud1", "")
                    teacher = pObj.optString("teacher1", "")
                    pType = pObj.optString("type1", "")
                } else {
                    // Подгрупповая пара
                    if (subgroup == 2) {
                        subj = pObj.optString("subj2", "").ifEmpty { pObj.optString("subj1", "") }
                        aud = pObj.optString("aud2", "").ifEmpty { pObj.optString("aud1", "") }
                        teacher = pObj.optString("teacher2", "").ifEmpty { pObj.optString("teacher1", "") }
                        pType = pObj.optString("type2", "").ifEmpty { pObj.optString("type1", "") }
                    } else {
                        subj = pObj.optString("subj1", "")
                        aud = pObj.optString("aud1", "")
                        teacher = pObj.optString("teacher1", "")
                        pType = pObj.optString("type1", "")
                    }
                }

                if (subj.isNotEmpty()) {
                    var detailsStr = ""
                    if (aud.isNotEmpty()) detailsStr += "Ауд. $aud"
                    if (teacher.isNotEmpty()) {
                        if (detailsStr.isNotEmpty()) detailsStr += " • "
                        detailsStr += teacher
                    }
                    if (pType.isNotEmpty()) {
                        if (detailsStr.isNotEmpty()) detailsStr += " ($pType)"
                    }

                    dayParas.add(
                        ParaParsed(
                            num = pNum,
                            startMin = times.first,
                            endMin = times.second,
                            timeStr = timeStrings[pNum] ?: "",
                            subject = subj,
                            details = detailsStr
                        )
                    )
                }
            }

            if (dayParas.isEmpty()) {
                views.setTextViewText(R.id.widget_status_text, "Пар на сегодня нет")
                views.setTextViewText(R.id.widget_subject_text, "Занятия отсутствуют")
                views.setTextViewText(R.id.widget_details_text, "День самостоятельной работы")
                views.setTextViewText(R.id.widget_next_text, "Далее: отдых")
                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            var ongoing: ParaParsed? = null
            var nextPara: ParaParsed? = null

            for (p in dayParas) {
                if (curMins in p.startMin..p.endMin) {
                    ongoing = p
                } else if (curMins < p.startMin && nextPara == null) {
                    nextPara = p
                }
            }

            if (ongoing != null) {
                val rem = ongoing.endMin - curMins
                views.setTextViewText(R.id.widget_status_text, "Идет ${ongoing.num} пара (осталось $rem мин)")
                views.setTextViewText(R.id.widget_subject_text, ongoing.subject)
                views.setTextViewText(R.id.widget_details_text, ongoing.details)

                if (nextPara != null) {
                    views.setTextViewText(R.id.widget_next_text, "Далее: ${nextPara.num} пара (${nextPara.timeStr}) - ${nextPara.subject}")
                } else {
                    views.setTextViewText(R.id.widget_next_text, "Далее: последняя пара на сегодня")
                }
            } else if (nextPara != null) {
                val first = dayParas.first()
                if (curMins < first.startMin) {
                    val rem = first.startMin - curMins
                    views.setTextViewText(R.id.widget_status_text, "Занятия не начались (до 1-й пары $rem мин)")
                } else {
                    val rem = nextPara.startMin - curMins
                    views.setTextViewText(R.id.widget_status_text, "Перемена (до ${nextPara.num} пары $rem мин)")
                }
                views.setTextViewText(R.id.widget_subject_text, "${nextPara.num} пара: ${nextPara.subject}")
                views.setTextViewText(R.id.widget_details_text, "${nextPara.timeStr} • ${nextPara.details}")

                val afterNext = dayParas.firstOrNull { it.startMin > nextPara.startMin }
                if (afterNext != null) {
                    views.setTextViewText(R.id.widget_next_text, "Далее: ${afterNext.num} пара - ${afterNext.subject}")
                } else {
                    views.setTextViewText(R.id.widget_next_text, "Далее: пар больше нет")
                }
            } else {
                views.setTextViewText(R.id.widget_status_text, "Все пары завершены")
                views.setTextViewText(R.id.widget_subject_text, "Учебный день окончен")
                views.setTextViewText(R.id.widget_details_text, "Все запланированные занятия прошли")
                views.setTextViewText(R.id.widget_next_text, "Далее: отдых")
            }

        } catch (e: Exception) {
            views.setTextViewText(R.id.widget_status_text, "РИИ Расписание")
            views.setTextViewText(R.id.widget_subject_text, "Нажмите для открытия")
            views.setTextViewText(R.id.widget_details_text, "")
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
