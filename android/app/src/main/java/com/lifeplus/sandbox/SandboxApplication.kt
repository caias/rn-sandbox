package com.lifeplus.sandbox

import android.app.Application
import android.content.Context
import android.util.Log
import com.facebook.react.PackageList
import com.facebook.react.ReactApplication
import com.facebook.react.ReactHost
import com.facebook.react.ReactNativeApplicationEntryPoint.loadReactNative
import com.facebook.react.defaults.DefaultReactHost.getDefaultReactHost

class SandboxApplication : Application(), ReactApplication {

    // 앱 시작 시점에 한 번 읽음 — 이후 IP가 바뀌어도 재시작 전엔 반영 안 됨
    private val metroIp: String by lazy {
        getSharedPreferences("sandbox", Context.MODE_PRIVATE)
            .getString(DevToolFragment.KEY_METRO_IP, "")
            ?.trim().orEmpty()
    }

    private val useMetro: Boolean get() = metroIp.isNotEmpty()

    // MainActivity 가 Metro 모드(단일 번들) vs 정적 모드(멀티 번들) 분기에 사용.
    val isMetroMode: Boolean get() = useMetro

    // RN 0.83+: ReactHost (single model, New Architecture)
    // - Metro 모드: jsBundleFilePath=null → Metro에서 fetch (단일 번들), useDevSupport=true
    // - 정적 모드 (멀티 번들):
    //     1. 부팅 시 shared.bundle.js 한 번 평가 → globalThis.__SHARED__ 채워짐
    //     2. URI 진입 시 MainActivity 가 pages/{appName}.bundle.js 동적 평가
    //     → AppRegistry.registerComponent('{appName}', ...) 호출됨
    //     → ReactFragment 가 그 appName 으로 surface mount
    override val reactHost: ReactHost by lazy {
        getDefaultReactHost(
            context = applicationContext,
            packageList = PackageList(this).packages,
            jsMainModulePath = "index",
            jsBundleFilePath = if (useMetro) null else "assets://shared.bundle.js",
            useDevSupport = useMetro,
        )
    }

    override fun onCreate() {
        super.onCreate()

        // Metro 모드: RN의 DevInternalSettings가 보는 debug_http_host에 사용자 IP를 주입
        if (useMetro) {
            getSharedPreferences("react-native-dev-preferences", Context.MODE_PRIVATE)
                .edit()
                .putString("debug_http_host", metroIp)
                .apply()
        }

        Log.i(
            "sandbox-poc",
            if (useMetro) "RN mode: Metro http://$metroIp/" else "RN mode: static multi-bundle (shared + pages/*)"
        )

        loadReactNative(this)
    }
}
