package com.quickmail.apply.quickmailapply

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val emailChannelName = "com.quickmail.apply/email"
    private val incomingChannelName = "com.quickmail.apply/incoming"
    private val mailtoEventChannelName = "com.quickmail.apply/incoming_mailto"

    private var pendingMailtoEmail: String? = null
    private var mailtoEventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleIncomingIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, emailChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openMailCompose" -> {
                        val email = call.argument<String>("email") ?: ""
                        val subject = call.argument<String>("subject") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        val attachmentPath = call.argument<String>("attachmentPath")

                        try {
                            openGmailCompose(email, subject, body, attachmentPath)
                            result.success(true)
                        } catch (e: ActivityNotFoundException) {
                            result.error("NO_GMAIL", "Gmail is not installed on this device.", null)
                        } catch (e: Exception) {
                            result.error("INTENT_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, incomingChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialMailto" -> {
                        val email = pendingMailtoEmail
                        pendingMailtoEmail = null
                        result.success(email)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, mailtoEventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    mailtoEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    mailtoEventSink = null
                }
            })
    }

    private fun handleIncomingIntent(intent: Intent?) {
        if (intent == null) return
        val email = extractEmailFromIntent(intent) ?: return

        val sink = mailtoEventSink
        if (sink != null) {
            sink.success(email)
        } else {
            pendingMailtoEmail = email
        }
    }

    private fun extractEmailFromIntent(intent: Intent): String? {
        when (intent.action) {
            Intent.ACTION_VIEW, Intent.ACTION_SENDTO -> {
                val data: Uri = intent.data ?: return null
                if (data.scheme != "mailto") return null

                val raw = data.schemeSpecificPart ?: return null
                val address = raw.split("?", limit = 2).first().trim()
                if (address.isNotEmpty()) return address

                // Some apps put the address in the path segment only.
                return data.path?.removePrefix("/")?.trim()?.takeIf { it.isNotEmpty() }
            }
        }
        return null
    }

    private fun openGmailCompose(
        email: String,
        subject: String,
        body: String,
        attachmentPath: String?,
    ) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "message/rfc822"
            putExtra(Intent.EXTRA_EMAIL, arrayOf(email))
            putExtra(Intent.EXTRA_SUBJECT, subject)
            putExtra(Intent.EXTRA_TEXT, body)

            if (!attachmentPath.isNullOrBlank()) {
                val file = File(attachmentPath)
                if (file.exists()) {
                    val uri = getShareableUri(file)
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    clipData = android.content.ClipData.newUri(contentResolver, "resume", uri)
                }
            }

            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            setPackage("com.google.android.gm")
        }

        try {
            startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            intent.setPackage(null)
            startActivity(Intent.createChooser(intent, "Send email"))
        }
    }

    private fun getShareableUri(file: File): Uri {
        val authority = "${applicationContext.packageName}.fileprovider"
        return try {
            FileProvider.getUriForFile(this, authority, file)
        } catch (e: IllegalArgumentException) {
            val shareDir = File(cacheDir, "share").apply { mkdirs() }
            val cached = File(shareDir, file.name)
            file.copyTo(cached, overwrite = true)
            FileProvider.getUriForFile(this, authority, cached)
        }
    }
}
