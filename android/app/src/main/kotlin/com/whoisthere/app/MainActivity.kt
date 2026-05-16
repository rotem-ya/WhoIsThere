package com.whoisthere.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
  private val CHANNEL = "com.whoisthere.app/app"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "getInstallerPackageName" -> {
          try {
            val installerPackage = packageManager.getInstallerPackageName(packageName)
            result.success(installerPackage ?: "unknown")
          } catch (e: Exception) {
            result.error("ERROR", e.message, null)
          }
        }
        else -> result.notImplemented()
      }
    }
  }
}
