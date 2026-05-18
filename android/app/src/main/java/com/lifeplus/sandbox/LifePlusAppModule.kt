package com.lifeplus.sandbox

import android.content.Intent
import android.util.Log
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap

/**
 * native-bridge `@lifeplus/native-bridge/native` 의 `NativeModules.LifePlusApp` Android 구현.
 *
 * RN 0.83 Bridgeless 호환. 모든 @ReactMethod 는 Promise 를 받아 sdk-native.ts 의
 * `Promise.reject(...) on missing implementation` 패턴과 짝.
 *
 * 지원 커맨드 (sandbox first cut):
 *   - back()                : MainActivity 의 fragment backStack pop, 비어있으면 finish()
 *   - share({ url, text? }) : Intent(ACTION_SEND) chooser
 */
class LifePlusAppModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    override fun getName(): String = MODULE_NAME

    /**
     * JS: `back()` (params 없음, Promise<void>)
     *
     * sandbox 의 ReactFragment 가 push 된 상태(backStack 에 entry 가 1 이상)면 pop.
     * backStack 이 비어 RNContainerFragment 가 root 인 경우 = URI 진입으로 바로 들어온 케이스 →
     * MainActivity.finish() 로 task 종료해서 launcher 또는 직전 앱으로 복귀.
     */
    /**
     * native-bridge `sdk-native.ts` 의 `call(command, params?)` 는 params 가 없어도
     * 항상 `fn(undefined)` 로 호출한다. Android TurboModule 검증이 사용자 arg 수와
     * `@ReactMethod` 시그니처의 arg 수를 비교하므로, void 커맨드도 `params: ReadableMap?`
     * 자리를 비워 둬야 호출 mismatch crash 가 안 난다.
     */
    @ReactMethod
    fun back(@Suppress("UNUSED_PARAMETER") params: ReadableMap?, promise: Promise) {
        val activity = getCurrentActivity()
        if (activity == null) {
            promise.reject("E_NO_ACTIVITY", "currentActivity is null")
            return
        }
        if (activity !is MainActivity) {
            promise.reject(
                "E_WRONG_ACTIVITY",
                "currentActivity is not MainActivity: ${activity::class.java.name}",
            )
            return
        }

        val mainActivity: MainActivity = activity
        mainActivity.runOnUiThread {
            val fm = mainActivity.supportFragmentManager
            val before = fm.backStackEntryCount
            if (before > 0) {
                // RN fragment(들) 가 stack 에 쌓여있는 상태. 마지막 entry 를 pop 하면
                // 이전 fragment 가 다시 mount. URI 진입 시 `showRN` 가 항상 DevTool 을
                // root 로 깔아두므로 마지막 RN pop 도 자연스럽게 DevTool 노출로 이어짐.
                fm.popBackStack()
                Log.i(TAG, "back: popped fragment backStack (remaining=${before - 1})")
            } else {
                // backStack 이 비어있다 = DevTool 만 root 로 떠 있는 상태. native back 의
                // 의미가 모호하니 activity 자체 종료 (host shell 책임 종결).
                Log.i(TAG, "back: backStack empty, finishing activity")
                mainActivity.finish()
            }
            promise.resolve(null)
        }
    }

    /**
     * JS: `share({ url, text? })` (params 있음, Promise<void>)
     *
     * Intent.ACTION_SEND + EXTRA_TEXT 로 시스템 share sheet (createChooser) 트리거.
     * url 과 text 가 모두 있으면 "text\nurl" 형태로 합쳐 보냄.
     */
    @ReactMethod
    fun share(params: ReadableMap?, promise: Promise) {
        if (params == null) {
            promise.reject("E_EMPTY", "share requires { url, text? }")
            return
        }
        val url = if (params.hasKey("url")) params.getString("url") else null
        val text = if (params.hasKey("text")) params.getString("text") else null
        if (url.isNullOrEmpty() && text.isNullOrEmpty()) {
            promise.reject("E_EMPTY", "share requires url or text")
            return
        }

        val activity = getCurrentActivity()
        if (activity == null) {
            promise.reject("E_NO_ACTIVITY", "currentActivity is null")
            return
        }

        val body = listOfNotNull(text, url).joinToString("\n")
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, body)
            text?.let { putExtra(Intent.EXTRA_SUBJECT, it) }
        }
        val chooser = Intent.createChooser(send, "Share").apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        activity.runOnUiThread {
            try {
                activity.startActivity(chooser)
                Log.i(TAG, "share: launched chooser body=$body")
                promise.resolve(null)
            } catch (t: Throwable) {
                Log.e(TAG, "share: failed", t)
                promise.reject("E_LAUNCH", t.message ?: "share launch failed", t)
            }
        }
    }

    companion object {
        // sdk-native.ts 가 NativeModules.LifePlusApp[command] 로 조회. 키 정확히 일치 필요.
        const val MODULE_NAME = "LifePlusApp"
        private const val TAG = "LifePlusApp"
    }
}
