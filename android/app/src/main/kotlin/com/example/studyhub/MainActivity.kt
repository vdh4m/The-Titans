package com.example.studyhub

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaRecorder
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val RECORDER_CHANNEL = "com.studyhub/recorder"
    private val FOCUS_CHANNEL    = "studyhub/focus"
    private val PERM_REQUEST_CODE = 101

    private var mediaRecorder: MediaRecorder? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Recorder channel ──────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORDER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startRecording" -> {
                        val path = call.argument<String>("path") ?: run {
                            result.error("NO_PATH", "No path provided", null)
                            return@setMethodCallHandler
                        }
                        if (ContextCompat.checkSelfPermission(
                                this, Manifest.permission.RECORD_AUDIO
                            ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            pendingResult = result
                            pendingPath   = path
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.RECORD_AUDIO),
                                PERM_REQUEST_CODE
                            )
                        } else {
                            startRecorder(path, result)
                        }
                    }
                    "stopRecording" -> {
                        stopRecorder()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // ── Focus Mode channel ────────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOCUS_CHANNEL)
            .setMethodCallHandler { call, result ->
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                when (call.method) {
                    "enableFocus" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            if (!nm.isNotificationPolicyAccessGranted) {
                                val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                                startActivity(intent)
                                result.error("PERMISSION_REQUIRED",
                                    "Grant Do Not Disturb access and try again", null)
                            } else {
                                nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                                result.success(true)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    "disableFocus" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                            nm.isNotificationPolicyAccessGranted) {
                            nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                        }
                        result.success(true)
                    }
                    "hasPermission" -> {
                        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                            nm.isNotificationPolicyAccessGranted else true
                        result.success(granted)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startRecorder(path: String, result: MethodChannel.Result) {
        try {
            stopRecorder()
            mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            mediaRecorder!!.apply {
                setAudioSource(MediaRecorder.AudioSource.MIC)
                setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
                setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                setAudioSamplingRate(16000)
                setAudioEncodingBitRate(64000)
                setAudioChannels(1)
                setOutputFile(path)
                prepare()
                start()
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("RECORD_ERROR", e.message, null)
        }
    }

    private fun stopRecorder() {
        try {
            mediaRecorder?.apply { stop(); release() }
        } catch (_: Exception) {}
        mediaRecorder = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERM_REQUEST_CODE) {
            val res = pendingResult ?: return
            val path = pendingPath ?: return
            pendingResult = null
            pendingPath   = null
            if (grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startRecorder(path, res)
            } else {
                res.error("PERMISSION_DENIED", "Microphone permission denied", null)
            }
        }
    }

    override fun onDestroy() {
        stopRecorder()
        super.onDestroy()
    }
}