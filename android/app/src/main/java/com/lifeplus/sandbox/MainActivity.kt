package com.lifeplus.sandbox

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.fragment.app.commit

class MainActivity : AppCompatActivity() {

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
        showRNContainer(appName, path, params)
    }

    private fun showDevTool() {
        supportFragmentManager.commit {
            replace(R.id.container, DevToolFragment())
        }
    }

    private fun showRNContainer(appName: String, path: String, params: HashMap<String, String>) {
        val fragment = RNContainerFragment.newInstance(appName, path, params)
        supportFragmentManager.commit {
            replace(R.id.container, fragment)
            addToBackStack(appName)
        }
    }

    companion object {
        private const val TAG = "sandbox-poc"
    }
}
