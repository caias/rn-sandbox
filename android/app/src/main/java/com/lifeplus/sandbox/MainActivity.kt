package com.lifeplus.sandbox

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.commit
import com.facebook.react.ReactFragment
import com.facebook.react.ReactInstanceEventListener
import com.facebook.react.bridge.JSBundleLoader
import com.facebook.react.bridge.ReactContext
import com.facebook.react.modules.core.DefaultHardwareBackBtnHandler

class MainActivity : AppCompatActivity(), DefaultHardwareBackBtnHandler {

    // JS 측 BackHandler.exitApp() 호출 시 invoke. 표준 백 버튼 동작에 위임.
    override fun invokeDefaultOnBackPressed() {
        onBackPressedDispatcher.onBackPressed()
    }


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        if (savedInstanceState == null) {
            handleIntent(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val uri: Uri? = intent.data
        if (uri == null) {
            showDevTool()
            return
        }
        val appName = uri.host.orEmpty().ifEmpty { "HelloRN" }
        val path = uri.path?.takeIf { it.isNotEmpty() } ?: "/"
        val params = HashMap<String, String>()
        uri.queryParameterNames.forEach { name ->
            params[name] = uri.getQueryParameter(name).orEmpty()
        }
        Log.i(TAG, "open url=$uri appName=$appName path=$path params=$params")
        showRN(appName, path, params)
    }

    // DevTool 을 backStack 없이 root 로 commit. URI 진입 케이스에서도 호출되어
    // RN fragment 의 popBackStack 후 DevTool 이 자연스럽게 노출되게 한다.
    // 이미 DevTool 이 container 에 떠 있으면 idempotent (replace 가 같은 클래스로 재 commit 만).
    private fun showDevTool() {
        val existing = supportFragmentManager.findFragmentById(R.id.container)
        if (existing is DevToolFragment) return
        supportFragmentManager.commit {
            replace(R.id.container, DevToolFragment())
        }
    }

    private fun showRN(appName: String, path: String, params: HashMap<String, String>) {
        val initialProps = buildInitialProps(path, params)

        // RN fragment 의 popBackStack 시 DevTool 이 자연스럽게 노출되도록 root 보장.
        // commit 은 idempotent — 이미 DevTool 이 root 면 no-op.
        showDevTool()

        // Metro 모드는 단일 번들 → page bundle 로드 불필요. shared 만 있는 정적 모드에서만 추가 로드.
        val app = application as SandboxApplication
        if (app.isMetroMode) {
            commitReactFragment(appName, initialProps)
            return
        }

        loadPageBundle(appName) { ok ->
            if (!ok) {
                Log.e(TAG, "page bundle load failed: $appName")
                return@loadPageBundle
            }
            commitReactFragment(appName, initialProps)
        }
    }

    private fun buildInitialProps(path: String, params: HashMap<String, String>): Bundle =
        Bundle().apply {
            putString("initialPath", path)
            putString("platform", "android")
            putString("appVersion", BuildConfig.VERSION_NAME)
            // URI query params 를 평탄화해서 putString. 모두 string 으로 들어감.
            // RESERVED 키와 충돌하는 query 는 무시 (시스템 키 보호).
            params.forEach { (k, v) ->
                if (k in RESERVED_KEYS) {
                    Log.w(TAG, "ignored reserved query key: $k")
                } else {
                    putString(k, v)
                }
            }
        }

    // pages/{appName}.bundle.js 를 ReactHostImpl.loadBundle 로 동적 평가.
    // page bundle 의 IIFE 가 평가되면 AppRegistry.registerComponent({appName}, ...) 가 호출되어
    // 이후 ReactFragment 가 그 이름으로 surface 를 mount 할 수 있게 된다.
    //
    // 같은 appName 을 두 번 진입하면 다시 evaluate 되지만 registerComponent 가 idempotent 라 무해.
    // 캐싱이 가치 있으려면 별도 set 으로 추적 가능 — 현재 미니앱 2개 라 미적용.
    //
    // ReactHostImpl.loadBundle 은 internal API + Task 는 internal.bolts.Task 라 직접 호출이
    // Kotlin 에서 막혀있다. RN 0.83 Bridgeless 가 multi-bundle 을 위한 public API 를
    // 아직 안 노출해서 reflection 으로 우회. 표준 API 가 나오면 교체.
    private fun loadPageBundle(appName: String, onComplete: (Boolean) -> Unit) {
        val app = application as SandboxApplication
        val host = app.reactHost

        // ReactInstance 가 살아있어야 loadBundle 호출 가능. 첫 진입 (cold) 에선 미준비 →
        // ReactInstanceEventListener 로 콜백 받아 evaluate. 두번째 진입부터는 같은
        // ReactHost 가 instance 를 재사용해서 currentReactContext != null → 즉시 evaluate.
        if (host.currentReactContext != null) {
            invokeLoadBundle(host, appName, onComplete)
            return
        }

        Log.i(TAG, "ReactInstance not ready — waiting for init before loadBundle")
        val listener = object : ReactInstanceEventListener {
            override fun onReactContextInitialized(context: ReactContext) {
                host.removeReactInstanceEventListener(this)
                invokeLoadBundle(host, appName, onComplete)
            }
        }
        host.addReactInstanceEventListener(listener)
        // host.start() 는 idempotent. shared bundle 평가가 시작되고, 끝나면 listener 호출됨.
        host.start()
    }

    private fun invokeLoadBundle(
        host: com.facebook.react.ReactHost,
        appName: String,
        onComplete: (Boolean) -> Unit,
    ) {
        val assetUrl = "assets://pages/$appName.bundle.js"
        Log.i(TAG, "loading page bundle: $assetUrl")
        val loader: JSBundleLoader = JSBundleLoader.createAssetLoader(
            applicationContext,
            assetUrl,
            /* loadSynchronously = */ false,
        )

        try {
            // ReactHostImpl.loadBundle(loader): Task<Boolean>
            //
            // Kotlin `internal fun loadBundle` 이 JVM bytecode 에선 visibility mangling 으로
            // `loadBundle$ReactAndroid_debug` / `loadBundle$ReactAndroid_release` 로 노출됨.
            // RN 변경에 좀 더 견고하게 모든 declared method 를 훑어 첫 매칭을 사용.
            val loadBundle = host.javaClass.declaredMethods.firstOrNull { m ->
                m.name.startsWith("loadBundle") &&
                    m.parameterTypes.size == 1 &&
                    m.parameterTypes[0] == JSBundleLoader::class.java
            } ?: error("ReactHostImpl.loadBundle(JSBundleLoader) not found")
            loadBundle.isAccessible = true
            val task = loadBundle.invoke(host, loader)
                ?: error("loadBundle returned null")

            pollTaskCompletion(task, onComplete)
        } catch (t: Throwable) {
            Log.e(TAG, "loadPageBundle reflection failed", t)
            onComplete(false)
        }
    }

    // Bolts Task 의 결과를 폴링. isCompleted=true 가 되면 isFaulted/result 확인.
    // pages bundle 은 ~5KB 라 evaluate 가 빠름. polling 간격 16ms (1 frame).
    private fun pollTaskCompletion(task: Any, onComplete: (Boolean) -> Unit) {
        val cls = task.javaClass
        val isCompleted = cls.getDeclaredMethod("isCompleted").apply { isAccessible = true }
        val isFaulted = cls.getDeclaredMethod("isFaulted").apply { isAccessible = true }
        val getResult = cls.getDeclaredMethod("getResult").apply { isAccessible = true }
        val getError = cls.getDeclaredMethod("getError").apply { isAccessible = true }

        fun check(): Boolean {
            if (isCompleted.invoke(task) != true) return false
            val faulted = isFaulted.invoke(task) == true
            if (faulted) {
                val err = getError.invoke(task) as? Throwable
                Log.e(TAG, "loadBundle faulted: ${err?.message}", err)
                onComplete(false)
            } else {
                val ok = getResult.invoke(task) == true
                onComplete(ok)
            }
            return true
        }

        if (check()) return
        val handler = window.decorView.handler
        val tick = object : Runnable {
            override fun run() {
                if (!check()) handler.postDelayed(this, 16)
            }
        }
        handler.postDelayed(tick, 16)
    }

    private fun commitReactFragment(appName: String, initialProps: Bundle) {
        // RN 0.83+ New Architecture: 공식 ReactFragment 사용.
        // ReactSurface 생성/attach/start, ReactHost lifecycle 모두 RN이 알아서 처리.
        val fragment = ReactFragment.Builder()
            .setComponentName(appName)
            .setLaunchOptions(initialProps)
            .setFabricEnabled(true)
            .build()
        supportFragmentManager.commit {
            replace(R.id.container, fragment)
            addToBackStack(appName)
        }
    }

    companion object {
        private const val TAG = "sandbox-poc"
        // initialProps Bundle 에서 시스템이 박는 키들. 같은 이름의 query 는 무시.
        private val RESERVED_KEYS = setOf("initialPath", "platform", "appVersion")
    }
}
