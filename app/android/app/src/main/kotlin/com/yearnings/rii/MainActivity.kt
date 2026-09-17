package com.yearnings.rii

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.yandex.authsdk.YandexAuthLoginOptions
import com.yandex.authsdk.YandexAuthOptions
import com.yandex.authsdk.YandexAuthSdk
import com.yandex.authsdk.YandexAuthToken
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val widgetChannel = "com.yearnings.rii/widget"
    private val notificationChannel = "com.yearnings.rii/notifications"
    private val launcherIconChannel = "com.yearnings.rii/launcher_icon"
    private val yandexAuthChannel = "com.yearnings.rii/yandex_auth"
    private val scheduleChannelId = "rii_schedule_alerts_v2"
    private val liveScheduleChannelId = "rii_live_lesson_v1"
    private val LIVE_NOTIFICATION_ID = 9999
    private val REQUEST_LOGIN_YANDEX = 1002

    private var yandexAuthSdk: YandexAuthSdk? = null
    private var yandexLoginResultCallback: MethodChannel.Result? = null

    // Все возможные alias'ы (должны совпадать с AndroidManifest.xml)
    private val allAliases = listOf(
        ".MainActivityDefault",
        ".MainActivityNewYear",
        ".MainActivityStudentDay",
        ".MainActivityDefenderDay",
        ".MainActivityWomenDay",
        ".MainActivitySpring",
        ".MainActivityVictoryDay",
        ".MainActivityGraduation",
        ".MainActivitySummer",
        ".MainActivityCityDay",
        ".MainActivityMachinistDay",
        ".MainActivityAutumn",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Инициализируем системный канал уведомлений высокой важности сразу при запуске
        setupNotificationChannels()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannel).setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                ScheduleWidgetProvider.updateAllWidgets(applicationContext)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, launcherIconChannel).setMethodCallHandler { call, result ->
            if (call.method == "setIcon") {
                val targetAlias = call.argument<String>("androidAlias") ?: ".MainActivityDefault"
                try {
                    val pm = packageManager
                    val pkg = packageName
                    // Включаем нужный alias, отключаем все остальные
                    for (alias in allAliases) {
                        val componentName = android.content.ComponentName(pkg, "$pkg$alias")
                        val newState = if (alias == targetAlias) {
                            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                        } else {
                            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                        }
                        pm.setComponentEnabledSetting(
                            componentName,
                            newState,
                            PackageManager.DONT_KILL_APP
                        )
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    } else {
                        result.success(true)
                    }
                }
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                        if (!granted) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                1001
                            )
                        }
                        result.success(granted)
                    } else {
                        result.success(true)
                    }
                }
                "showNotification" -> {
                    val title = call.argument<String>("title") ?: "РИИ Расписание"
                    val message = call.argument<String>("message") ?: ""
                    showLocalNotification(title, message)
                    result.success(true)
                }
                "scheduleNotification" -> {
                    val id = call.argument<Int>("id") ?: (System.currentTimeMillis() % 100000).toInt()
                    val title = call.argument<String>("title") ?: "РИИ Расписание"
                    val message = call.argument<String>("message") ?: ""
                    val epochMillis = call.argument<Long>("epochMillis") ?: 0L
                    scheduleExactNotification(id, title, message, epochMillis)
                    result.success(true)
                }
                "startOrUpdateLiveNotification" -> {
                    val title = call.argument<String>("title") ?: "РИИ Расписание"
                    val message = call.argument<String>("message") ?: ""
                    val epochEndMillis = call.argument<Long>("epochEndMillis") ?: 0L
                    val isBreak = call.argument<Boolean>("isBreak") ?: false
                    val nextParaText = call.argument<String>("nextParaText") ?: ""
                    showLiveNotification(title, message, epochEndMillis, isBreak, nextParaText)
                    result.success(true)
                }
                "stopLiveNotification" -> {
                    stopLiveNotification()
                    result.success(true)
                }
                "openNotificationSettings" -> {
                    try {
                        val intent = Intent().apply {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            } else {
                                action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                                data = Uri.fromParts("package", packageName, null)
                            }
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Канал авторизации через нативный Яндекс Login SDK
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, yandexAuthChannel).setMethodCallHandler { call, result ->
            if (call.method == "login") {
                try {
                    if (yandexAuthSdk == null) {
                        val options = YandexAuthOptions(applicationContext, true)
                        yandexAuthSdk = YandexAuthSdk.create(options)
                    }
                    yandexLoginResultCallback = result
                    val intent = yandexAuthSdk!!.createLoginIntent(YandexAuthLoginOptions())
                    startActivityForResult(intent, REQUEST_LOGIN_YANDEX)
                } catch (e: Exception) {
                    result.error("YANDEX_INIT_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_LOGIN_YANDEX) {
            val callback = yandexLoginResultCallback
            yandexLoginResultCallback = null
            if (callback == null) return
            try {
                val yandexSdk = yandexAuthSdk ?: YandexAuthSdk.create(YandexAuthOptions(applicationContext, true))
                val yandexToken = yandexSdk.extractToken(resultCode, data)
                if (yandexToken != null) {
                    callback.success(mapOf(
                        "status" to "success",
                        "token" to yandexToken.value,
                        "expiresIn" to yandexToken.expiresIn
                    ))
                } else {
                    callback.success(mapOf(
                        "status" to "cancelled"
                    ))
                }
            } catch (e: Exception) {
                callback.error("YANDEX_AUTH_FAILED", e.message, null)
            }
        }
    }

    // Создание каналов уведомлений с максимальным приоритетом и всплывающими баннерами
    private fun setupNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val channel = NotificationChannel(
                scheduleChannelId,
                "Расписание и пары РИИ",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Уведомления о парах, переменах и обновлениях расписания"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 150, 250)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)

            val liveChannel = NotificationChannel(
                liveScheduleChannelId,
                "Текущая пара на экране блокировки",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Закрепленное уведомление с обратным отсчетом текущей пары и перемены"
                enableVibration(false)
                setShowBadge(false)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(liveChannel)
        }
    }

    // Отображение закрепленного уведомления текущей пары с живым хронометром
    private fun showLiveNotification(
        title: String,
        message: String,
        epochEndMillis: Long,
        isBreak: Boolean,
        nextParaText: String
    ) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        setupNotificationChannels()

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            1,
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        val fullBody = if (nextParaText.isNotEmpty()) "$message\n$nextParaText" else message

        val builder = NotificationCompat.Builder(this, liveScheduleChannelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setSubText(if (isBreak) "Перемена" else "Текущее занятие")
            .setStyle(NotificationCompat.BigTextStyle().bigText(fullBody))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setUsesChronometer(true)
            .setChronometerCountDown(true)
            .setWhen(epochEndMillis)
            .setShowWhen(true)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)

        notificationManager.notify(LIVE_NOTIFICATION_ID, builder.build())
    }

    private fun stopLiveNotification() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(LIVE_NOTIFICATION_ID)
    }

    // Отображение локального системного уведомления с гарантированным всплытием на экран
    private fun showLocalNotification(title: String, message: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        setupNotificationChannels()

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        val builder = NotificationCompat.Builder(this, scheduleChannelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            val notifId = (System.currentTimeMillis() % 100000).toInt() + 1000
            notificationManager.notify(notifId, builder.build())
        }
    }

    // Точное планирование уведомлений через AlarmManager с пробуждением процессора
    private fun scheduleExactNotification(id: Int, title: String, message: String, epochMillis: Long) {
        if (epochMillis <= System.currentTimeMillis()) {
            showLocalNotification(title, message)
            return
        }
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as? android.app.AlarmManager ?: return
            val intent = Intent(this, NotificationAlarmReceiver::class.java).apply {
                putExtra("id", id)
                putExtra("title", title)
                putExtra("message", message)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                id,
                intent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, epochMillis, pendingIntent)
            } else {
                alarmManager.setExact(android.app.AlarmManager.RTC_WAKEUP, epochMillis, pendingIntent)
            }
        } catch (_: Exception) {}
    }
}

class NotificationAlarmReceiver : android.content.BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "РИИ Расписание"
        val message = intent.getStringExtra("message") ?: ""
        val id = intent.getIntExtra("id", (System.currentTimeMillis() % 100000).toInt())
        showNotification(context, id, title, message)
    }

    companion object {
        fun showNotification(context: Context, id: Int, title: String, message: String) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val scheduleChannelId = "rii_schedule_alerts_v2"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    scheduleChannelId,
                    "Расписание и пары РИИ",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Уведомления о парах, переменах и обновлениях расписания"
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 250, 150, 250)
                    lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                }
                notificationManager.createNotificationChannel(channel)
            }

            val appIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                appIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            )

            val builder = NotificationCompat.Builder(context, scheduleChannelId)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)

            notificationManager.notify(id, builder.build())
        }
    }
}
