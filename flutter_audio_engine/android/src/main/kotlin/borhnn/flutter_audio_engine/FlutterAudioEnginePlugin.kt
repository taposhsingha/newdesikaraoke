/*package borhnn.flutter_audio_engine

import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result



class FlutterAudioEnginePlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_audio_engine")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}*/

package borhnn.flutter_audio_engine

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.view.Choreographer
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import io.flutter.embedding.engine.plugins.PluginRegistry
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import kotlin.math.pow

class FlutterAudioEnginePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
  private lateinit var methodChannel: MethodChannel
  private lateinit var playerStatusChannel: EventChannel
  private lateinit var playerPositionChannel: EventChannel
  private var playerStatusEventSink: EventChannel.EventSink? = null
  private var playerPositionEventSink: EventChannel.EventSink? = null
  private var choreographer: Choreographer? = null
  private var audioPlayer: MediaPlayer? = null

  /*
  here instead of companion object block of code that has registrar this blocks  of codes will be
  used. cant give specific because too many changes.
   */

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_audio_engine")
    playerStatusChannel = EventChannel(flutterPluginBinding.binaryMessenger, "borhnn/playerStatus")
    playerPositionChannel = EventChannel(flutterPluginBinding.binaryMessenger, "borhnn/playerPosition")
    playerStatusChannel.setStreamHandler(this)
    playerPositionChannel.setStreamHandler(this)
    methodChannel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    playerStatusChannel.setStreamHandler(null)
    playerPositionChannel.setStreamHandler(null)
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    when (arguments.toString()) {
      "forStatus" -> {
        playerStatusEventSink = events
        playerStatusEventSink?.success(PlayerStatus.NOT_INITIALIZED.value)
      }
      "forPosition" -> {
        playerPositionEventSink = events
        choreographer = Choreographer.getInstance()
      }
    }
  }

  override fun onCancel(arguments: Any?) {
    choreographer = null
    playerStatusEventSink = null
    playerPositionEventSink = null
  }

  private fun playerPositionDeclaration() {
    playerPositionEventSink?.success(audioPlayer?.currentPosition)
    choreographer?.postFrameCallback { playerPositionDeclaration() }
  }

  enum class PlayerStatus(val value: Int) {
    NOT_INITIALIZED(-4),
    INITIALIZED(-3),
    READY(-2),
    STOPPED(-1),
    PAUSED(0),
    RESUMED(1),
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "initPlayer"     -> {
        audioPlayer = audioPlayer ?: MediaPlayer()
        playerStatusEventSink?.success(PlayerStatus.NOT_INITIALIZED.value)
        audioPlayer?.setOnPreparedListener {
          playerStatusEventSink?.success(PlayerStatus.READY.value)
        }
        audioPlayer?.apply {
          setAudioAttributes(
            AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()
          )
          setDataSource(call.argument<String>("fileURL"))
          prepareAsync()
        }
      }
      "play"           -> {
        audioPlayer?.start()
        audioPlayer?.setOnCompletionListener { playerStatusEventSink?.success(PlayerStatus.STOPPED.value) }
        choreographer?.postFrameCallback { playerPositionDeclaration() }
        playerStatusEventSink?.success(PlayerStatus.RESUMED.value)
      }
      "pause"          -> {
        audioPlayer?.pause()
        playerStatusEventSink?.success(PlayerStatus.PAUSED.value)
      }
      "stop"           -> {
        audioPlayer?.stop()
        playerStatusEventSink?.success(PlayerStatus.STOPPED.value)
        audioPlayer?.release()
        choreographer?.removeFrameCallback { }
        audioPlayer = null
      }
      "setPlayerSpeed" -> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
          if (audioPlayer != null) {
            val wasPlaying = audioPlayer?.isPlaying ?: false
            audioPlayer?.playbackParams = audioPlayer?.playbackParams.apply {
              this?.speed = call.argument<Double>("playbackRate")?.toFloat() ?: 0.0f
            }!!
            if (!wasPlaying) audioPlayer?.pause()
          }
        }
      }
      "setPlayerPitch" -> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
          if (audioPlayer != null) {
            val wasPlaying = audioPlayer?.isPlaying ?: false
            audioPlayer?.playbackParams = audioPlayer?.playbackParams.apply {
              val hsDelta = call.argument<Int>("halfstepDelta") ?: 0
              val pitch = 2f.pow(hsDelta.toFloat() / 12)
              this?.pitch = pitch
            }!!
            if (!wasPlaying) audioPlayer?.pause()
          }
        }
      }
      "setVolume"      -> {
        val newVolume = call.argument<Double>("volume")?.toFloat() ?: 1.0f
        audioPlayer?.setVolume(newVolume, newVolume)
      }
      else             -> result.notImplemented()
    }
  }
}