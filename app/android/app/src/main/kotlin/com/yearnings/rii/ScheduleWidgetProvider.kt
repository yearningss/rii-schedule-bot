package com.yearnings.rii

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
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
        scheduleNextTick(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            AppWidgetManager.ACTION_APPWIDGET_UPDATE,
            ACTION_SCHEDULE_TICK,
            Intent.ACTION_TIME_TICK,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED -> {
                updateAllWidgets(context)
            }
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        updateAllWidgets(context)
    }

    companion object {
        const val ACTION_SCHEDULE_TICK = "com.yearnings.rii.ACTION_SCHEDULE_TICK"

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val widgetComponent = ComponentName(context, ScheduleWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(widgetComponent)
            if (widgetIds == null || widgetIds.isEmpty()) return

            val provider = ScheduleWidgetProvider()
            for (widgetId in widgetIds) {
                provider.updateWidget(context, appWidgetManager, widgetId)
            }
            scheduleNextTick(context)
        }

        fun scheduleNextTick(context: Context) {
            try {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
                val intent = Intent(context, ScheduleWidgetProvider::class.java).apply {
                    action = ACTION_SCHEDULE_TICK
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    2026,
                    intent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                )
                // Следующая минута ровно в :00 секунд (+100 мс для уверенного перехода минут)
                val nextMinuteMillis = ((System.currentTimeMillis() / 60000) + 1) * 60000 + 100
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC, nextMinuteMillis, pendingIntent)
                } else {
                    alarmManager.setExact(AlarmManager.RTC, nextMinuteMillis, pendingIntent)
                }
            } catch (_: Exception) {}
        }
    }

    data class ParaParsed(
        val num: Int,
        val startMin: Int,
        val endMin: Int,
        val timeStr: String,
        val subject: String,
        val details: String
    )

    private val defaultTimes = mapOf(
        1 to Pair(510, 600),   // 08:30 - 10:00
        2 to Pair(610, 700),   // 10:10 - 11:40
        3 to Pair(730, 820),   // 12:10 - 13:40
        4 to Pair(830, 920),   // 13:50 - 15:20
        5 to Pair(930, 1020),  // 15:30 - 17:00
        6 to Pair(1030, 1120)  // 17:10 - 18:40
    )

    private val timeStrings = mapOf(
        1 to "08:30 - 10:00",
        2 to "10:10 - 11:40",
        3 to "12:10 - 13:40",
        4 to "13:50 - 15:20",
        5 to "15:30 - 17:00",
        6 to "17:10 - 18:40"
    )

    private fun parseDayParas(dayObj: JSONObject?, subgroup: Int): List<ParaParsed> {
        if (dayObj == null) return emptyList()
        val list = mutableListOf<ParaParsed>()

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
                if (aud.isNotEmpty()) detailsStr += "Ауд. " + aud
                if (teacher.isNotEmpty()) {
                    if (detailsStr.isNotEmpty()) detailsStr += " • "
                    detailsStr += teacher
                }
                if (pType.isNotEmpty()) {
                    if (detailsStr.isNotEmpty()) detailsStr += " (" + pType + ")"
                }

                list.add(
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
        return list
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
                scheduleJsonStr = prefs.getString("flutter.schedule_cache_" + groupId, null)
            }

            views.setTextViewText(R.id.widget_group_name, groupName)

            // Время по Рубцовску (UTC+7, Asia/Barnaul)
            val tz = TimeZone.getTimeZone("Asia/Barnaul")
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
                Calendar.SUNDAY -> 7
                else -> 1
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
            val scheduleData = json.optJSONObject("scheduleData")

            // 1. Обработка воскресенья (rDay == 7)
            if (rDay == 7) {
                val nextWeek = if (weekNumber == 1) 2 else 1
                val mondayObj = scheduleData?.optJSONObject(nextWeek.toString())?.optJSONObject("1")
                val mondayParas = parseDayParas(mondayObj, subgroup)
                val nextWeekRoman = if (nextWeek == 2) "II" else "I"

                views.setTextViewText(
                    R.id.widget_date_week,
                    "$curDayStr, $dateFormatted • Пн: $nextWeekRoman нед"
                )

                if (mondayParas.isNotEmpty()) {
                    val first = mondayParas[0]
                    views.setTextViewText(R.id.widget_status_text, "Воскресенье • Завтра понедельник")
                    views.setTextViewText(R.id.widget_subject_text, "${first.num} пара: ${first.subject}")
                    views.setTextViewText(R.id.widget_details_text, "${first.timeStr} • ${first.details}")
                    views.setTextViewText(R.id.widget_next_text, "Всего в понедельник: ${mondayParas.size} пар")
                } else {
                    views.setTextViewText(R.id.widget_status_text, "Воскресенье • Выходной день")
                    views.setTextViewText(R.id.widget_subject_text, "В понедельник пар нет")
                    views.setTextViewText(R.id.widget_details_text, "Подготовка к следующей учебной неделе")
                    views.setTextViewText(R.id.widget_next_text, "Новая неделя ($nextWeekRoman нед)")
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            // 2. Обработка учебных дней (Пн-Сб)
            val weekRoman = if (weekNumber == 2) "II нед" else "I нед"
            views.setTextViewText(R.id.widget_date_week, "$curDayStr, $dateFormatted • $weekRoman")

            val weekObj = scheduleData?.optJSONObject(weekNumber.toString())
            val dayObj = weekObj?.optJSONObject(rDay.toString())
            val dayParas = parseDayParas(dayObj, subgroup)

            // Если на сегодня пар нет (например, суббота без занятий)
            if (dayParas.isEmpty()) {
                val nextWeek = if (rDay == 6) (if (weekNumber == 1) 2 else 1) else weekNumber
                val nextDayTarget = if (rDay == 6) 1 else (rDay + 1)
                val targetObj = scheduleData?.optJSONObject(nextWeek.toString())?.optJSONObject(nextDayTarget.toString())
                val targetParas = parseDayParas(targetObj, subgroup)
                val nextWeekRoman = if (nextWeek == 2) "II" else "I"

                val dayTitle = if (rDay == 6) "Суббота • Выходной день" else "Сегодня пар нет"
                views.setTextViewText(R.id.widget_status_text, dayTitle)

                if (targetParas.isNotEmpty()) {
                    val targetFirst = targetParas[0]
                    val nextLabel = if (rDay == 6) "В понедельник" else "Завтра"
                    views.setTextViewText(R.id.widget_subject_text, "$nextLabel: ${targetFirst.num} пара (${targetFirst.subject})")
                    views.setTextViewText(R.id.widget_details_text, "${targetFirst.timeStr} • ${targetFirst.details}")
                    views.setTextViewText(R.id.widget_next_text, "Всего занятий: ${targetParas.size} пар ($nextWeekRoman нед)")
                } else {
                    views.setTextViewText(R.id.widget_subject_text, "Занятия по расписанию отсутствуют")
                    views.setTextViewText(R.id.widget_details_text, "День самостоятельной работы")
                    views.setTextViewText(R.id.widget_next_text, "Далее: отдых")
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            // Поиск текущей и следующей пары
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
                // Все пары на сегодня завершены -> смотрим расписание на следующий день
                val nextDayTarget = rDay + 1
                val tomorrowObj = if (nextDayTarget <= 6) weekObj?.optJSONObject(nextDayTarget.toString()) else null
                val tomorrowParas = parseDayParas(tomorrowObj, subgroup)

                views.setTextViewText(R.id.widget_status_text, "Все пары на сегодня завершены")
                if (tomorrowParas.isNotEmpty()) {
                    val tFirst = tomorrowParas[0]
                    views.setTextViewText(R.id.widget_subject_text, "Завтра: ${tFirst.num} пара (${tFirst.subject})")
                    views.setTextViewText(R.id.widget_details_text, "${tFirst.timeStr} • ${tFirst.details}")
                    views.setTextViewText(R.id.widget_next_text, "Всего завтра: ${tomorrowParas.size} пар")
                } else {
                    views.setTextViewText(R.id.widget_subject_text, "Учебный день окончен")
                    views.setTextViewText(R.id.widget_details_text, "Все запланированные занятия прошли")
                    views.setTextViewText(R.id.widget_next_text, "Далее: отдых")
                }
            }

        } catch (e: Exception) {
            views.setTextViewText(R.id.widget_status_text, "РИИ Расписание")
            views.setTextViewText(R.id.widget_subject_text, "Нажмите для открытия")
            views.setTextViewText(R.id.widget_details_text, "")
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
