package com.yearnings.rii

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val widgetChannel = "com.yearnings.rii/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannel).setMethodCallHandler { call, result ->
            if (call.method == "updateWidget") {
                ScheduleWidgetProvider.updateAllWidgets(applicationContext)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
}
