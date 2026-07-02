package com.outline.outline_mobileproxy

import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import mobileproxy.Mobileproxy
import mobileproxy.Proxy as MobileproxyInstance

/**
 * Flutter plugin bridging to the Outline SDK's Mobileproxy Go Mobile library
 * (golang.getoutline.org/sdk/x/mobileproxy), bundled as `libs/mobileproxy.aar`.
 *
 * All state mutations (starting/stopping the proxy) are serialized through
 * [mutex] so that concurrent method calls from Dart can't race each other.
 */
class OutlineMobileproxyPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private val pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
  private val mutex = Mutex()

  @Volatile private var runningProxy: MobileproxyInstance? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "outline_mobileproxy")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")
      "start" -> handleStart(call, result)
      "startSmart" -> handleStartSmart(call, result)
      "stop" -> handleStop(call, result)
      "isRunning" -> result.success(runningProxy != null)
      "currentProxy" -> result.success(runningProxy?.address())
      else -> result.notImplemented()
    }
  }

  private fun handleStart(call: MethodCall, result: Result) {
    val transportConfig = call.argument<String>("transportConfig")
    val localAddress = call.argument<String>("localAddress") ?: "127.0.0.1:0"
    if (transportConfig.isNullOrEmpty()) {
      result.error("INVALID_CONFIG", "transportConfig must not be empty", null)
      return
    }

    pluginScope.launch {
      try {
        val address = withContext(Dispatchers.IO) {
          mutex.withLock {
            stopLocked(timeoutSeconds = 0)
            val dialer =
                try {
                  Mobileproxy.newStreamDialerFromConfig(transportConfig)
                } catch (e: Exception) {
                  throw StartError("INVALID_CONFIG", e.message ?: "Invalid transport config")
                }
            startLocked(localAddress, dialer)
          }
        }
        result.success(address)
      } catch (e: StartError) {
        result.error(e.code, e.message, null)
      } catch (e: Exception) {
        result.error("START_FAILED", e.message ?: "Failed to start proxy", null)
      }
    }
  }

  private fun handleStartSmart(call: MethodCall, result: Result) {
    @Suppress("UNCHECKED_CAST")
    val testDomains = call.argument<List<String>>("testDomains") ?: emptyList()
    val strategiesConfig = call.argument<String>("strategiesConfig")
    val enableLogging = call.argument<Boolean>("enableLogging") ?: false
    val localAddress = call.argument<String>("localAddress") ?: "127.0.0.1:0"
    if (testDomains.isEmpty() || strategiesConfig.isNullOrEmpty()) {
      result.error(
          "INVALID_CONFIG", "testDomains and strategiesConfig must not be empty", null)
      return
    }

    pluginScope.launch {
      try {
        val address = withContext(Dispatchers.IO) {
          mutex.withLock {
            stopLocked(timeoutSeconds = 0)

            val domainList = Mobileproxy.newListFromLines(testDomains.joinToString("\n"))
            val options = Mobileproxy.newSmartDialerOptions(domainList, strategiesConfig)
            if (enableLogging) {
              options.setLogWriter(Mobileproxy.newStderrLogWriter())
            }
            val dialer =
                try {
                  options.newStreamDialer()
                } catch (e: Exception) {
                  throw StartError(
                      "INVALID_CONFIG",
                      e.message ?: "No working strategy found for the given configuration")
                }
            startLocked(localAddress, dialer)
          }
        }
        result.success(address)
      } catch (e: StartError) {
        result.error(e.code, e.message, null)
      } catch (e: Exception) {
        result.error("START_FAILED", e.message ?: "Failed to start proxy", null)
      }
    }
  }

  private fun handleStop(call: MethodCall, result: Result) {
    val timeoutSeconds = call.argument<Int>("timeoutSeconds") ?: 5
    pluginScope.launch {
      try {
        withContext(Dispatchers.IO) { mutex.withLock { stopLocked(timeoutSeconds) } }
        result.success(null)
      } catch (e: Exception) {
        result.error("STOP_FAILED", e.message ?: "Failed to stop proxy", null)
      }
    }
  }

  /** Must be called while holding [mutex]. Starts a new proxy; assumes none is running. */
  private fun startLocked(localAddress: String, dialer: mobileproxy.StreamDialer): String {
    val proxy =
        try {
          Mobileproxy.runProxy(localAddress, dialer)
        } catch (e: Exception) {
          throw StartError("START_FAILED", e.message ?: "Failed to start local proxy")
        }
    runningProxy = proxy
    return proxy.address()
  }

  /** Must be called while holding [mutex]. No-op if no proxy is running. */
  private fun stopLocked(timeoutSeconds: Int) {
    runningProxy?.stop(timeoutSeconds.toLong())
    runningProxy = null
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    runningProxy?.stop(0)
    runningProxy = null
  }

  private class StartError(val code: String, message: String) : Exception(message)
}
