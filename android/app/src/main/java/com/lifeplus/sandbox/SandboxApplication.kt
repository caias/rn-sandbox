package com.lifeplus.sandbox

import android.app.Application
import android.content.Context
import android.util.Log
import com.facebook.react.PackageList
import com.facebook.react.ReactApplication
import com.facebook.react.ReactHost
import com.facebook.react.ReactNativeHost
import com.facebook.react.ReactPackage
import com.facebook.react.defaults.DefaultNewArchitectureEntryPoint.load
import com.facebook.react.defaults.DefaultReactHost.getDefaultReactHost
import com.facebook.react.defaults.DefaultReactNativeHost
import com.facebook.soloader.SoLoader

class SandboxApplication : Application(), ReactApplication {

    // 앱 시작 시점에 한 번 읽음 — 이후 IP가 바뀌어도 재시작 전엔 반영 안 됨
    private val metroIp: String by lazy {
        getSharedPreferences("sandbox", Context.MODE_PRIVATE)
            .getString(DevToolFragment.KEY_METRO_IP, "")
            ?.trim().orEmpty()
    }

    private val useMetro: Boolean get() = metroIp.isNotEmpty()

    override val reactNativeHost: ReactNativeHost =
        object : DefaultReactNativeHost(this) {
            override fun getPackages(): List<ReactPackage> =
                PackageList(this).packages

            override fun getJSMainModuleName(): String = "index"

            // Metro 모드: dev 지원 ON (hot reload, devmenu, redbox)
            override fun getUseDeveloperSupport(): Boolean = useMetro

            // Metro 모드: null 반환 → ReactInstanceManager가 getJSMainModuleName + dev server로 fetch
            // 정적 모드: assets://main.jsbundle
            override fun getJSBundleFile(): String? =
                if (useMetro) null else "assets://main.jsbundle"

            override val isNewArchEnabled: Boolean = BuildConfig.IS_NEW_ARCHITECTURE_ENABLED
            override val isHermesEnabled: Boolean = BuildConfig.IS_HERMES_ENABLED
        }

    override val reactHost: ReactHost
        get() = getDefaultReactHost(applicationContext, reactNativeHost)

    override fun onCreate() {
        super.onCreate()
        SoLoader.init(this, false)

        // Metro 모드: RN의 DevInternalSettings가 보는 debug_http_host에 사용자가 입력한 IP를 주입
        if (useMetro) {
            getSharedPreferences("react-native-dev-preferences", Context.MODE_PRIVATE)
                .edit()
                .putString("debug_http_host", metroIp)
                .apply()
        }

        Log.i(
            "sandbox-poc",
            if (useMetro) "RN mode: Metro http://$metroIp/" else "RN mode: static assets://main.jsbundle"
        )
        if (BuildConfig.IS_NEW_ARCHITECTURE_ENABLED) {
            load()
        }
    }
}
