package com.example.adavvu

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        FlutterLocalNotificationsPlugin.registerWith(
            flutterEngine.plugins.get(FlutterLocalNotificationsPlugin::class.java)
        )
    }
}
