package com.lifeplus.sandbox

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.commit
import com.facebook.react.ReactFragment
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

    private fun showDevTool() {
        supportFragmentManager.commit {
            replace(R.id.container, DevToolFragment())
        }
    }

    private fun showRN(appName: String, path: String, params: HashMap<String, String>) {
        // RN 0.83+ New Architecture: 공식 ReactFragment 사용.
        // ReactSurface 생성/attach/start, ReactHost lifecycle 모두 RN이 알아서 처리.
        val initialProps = Bundle().apply {
            putString("initialPath", path)
            putString("platform", "android")
        }
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
    }
}
