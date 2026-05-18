package com.lifeplus.sandbox

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

/**
 * `LifePlusAppModule` 만 노출하는 ReactPackage. `SandboxApplication` 의 packageList 에
 * 수동 추가된다 (RN autolink 의 외부 라이브러리가 아니라 sandbox 내부 모듈이므로).
 */
class LifePlusAppPackage : ReactPackage {
    override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> =
        listOf(LifePlusAppModule(reactContext))

    override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> =
        emptyList()
}
