package com.lifeplus.sandbox

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.fragment.app.Fragment

class DevToolFragment : Fragment() {

    private lateinit var metroIpField: EditText
    private lateinit var saveMetroButton: Button
    private lateinit var clearMetroButton: Button
    private lateinit var metroStatus: TextView

    private lateinit var schemeField: EditText
    private lateinit var runButton: Button
    private lateinit var recentLabel: TextView

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        val v = inflater.inflate(R.layout.fragment_devtool, container, false)
        metroIpField = v.findViewById(R.id.metroIpField)
        saveMetroButton = v.findViewById(R.id.saveMetroButton)
        clearMetroButton = v.findViewById(R.id.clearMetroButton)
        metroStatus = v.findViewById(R.id.metroStatus)
        schemeField = v.findViewById(R.id.schemeField)
        runButton = v.findViewById(R.id.runButton)
        recentLabel = v.findViewById(R.id.recentLabel)

        schemeField.setText(DEFAULT_SCHEME)
        runButton.setOnClickListener { runScheme() }

        saveMetroButton.setOnClickListener { saveMetroIp() }
        clearMetroButton.setOnClickListener { clearMetroIp() }

        prefs()?.getString(KEY_METRO_IP, "")?.let { metroIpField.setText(it) }

        refreshMetroStatus()
        refreshRecent()
        return v
    }

    private fun saveMetroIp() {
        val ip = metroIpField.text?.toString()?.trim().orEmpty()
        prefs()?.edit()?.putString(KEY_METRO_IP, ip)?.apply()
        Toast.makeText(
            requireContext(),
            if (ip.isEmpty()) "정적 번들 모드" else "Metro: $ip (앱 재시작 필요)",
            Toast.LENGTH_SHORT
        ).show()
        refreshMetroStatus()
    }

    private fun clearMetroIp() {
        metroIpField.setText("")
        prefs()?.edit()?.remove(KEY_METRO_IP)?.apply()
        Toast.makeText(requireContext(), "정적 번들 모드 (앱 재시작 필요)", Toast.LENGTH_SHORT).show()
        refreshMetroStatus()
    }

    private fun refreshMetroStatus() {
        val ip = prefs()?.getString(KEY_METRO_IP, "")?.trim().orEmpty()
        metroStatus.text = if (ip.isEmpty()) {
            "현재: 정적 번들 (assets://main.jsbundle)"
        } else {
            "현재: Metro http://$ip/index.bundle?platform=android&dev=true"
        }
    }

    private fun runScheme() {
        val raw = schemeField.text?.toString()?.trim().orEmpty()
        if (raw.isEmpty()) return
        val uri = try {
            Uri.parse(raw)
        } catch (e: Exception) {
            Log.w(TAG, "invalid URI: $raw", e)
            return
        }
        saveRecent(raw)
        refreshRecent()
        startActivity(Intent(Intent.ACTION_VIEW, uri))
    }

    private fun saveRecent(scheme: String) {
        val prefs = prefs() ?: return
        val current = prefs.getString(KEY_RECENT, "")!!
            .split("\n")
            .filter { it.isNotEmpty() && it != scheme }
        val updated = (listOf(scheme) + current).take(10).joinToString("\n")
        prefs.edit().putString(KEY_RECENT, updated).apply()
    }

    private fun refreshRecent() {
        val arr = prefs()?.getString(KEY_RECENT, "")
            ?.split("\n")
            ?.filter { it.isNotEmpty() }
            ?: emptyList()
        recentLabel.text = if (arr.isEmpty()) {
            "최근 실행 기록 없음"
        } else {
            "최근:\n" + arr.joinToString("\n") { "• $it" }
        }
    }

    private fun prefs(): SharedPreferences? =
        context?.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    companion object {
        private const val TAG = "sandbox-poc"
        private const val PREFS = "sandbox"
        private const val KEY_RECENT = "recentSchemes"
        const val KEY_METRO_IP = "metroIp"
        private const val DEFAULT_SCHEME = "lifeplus-tribes://promotion"
    }
}
