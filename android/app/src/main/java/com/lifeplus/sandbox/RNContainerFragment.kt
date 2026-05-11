package com.lifeplus.sandbox

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import com.facebook.react.ReactApplication
import com.facebook.react.ReactRootView

class RNContainerFragment : Fragment() {

    private var reactRootView: ReactRootView? = null

    override fun onCreateView(
        inflater: LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        val args = requireArguments()
        val appName = args.getString(ARG_APP_NAME) ?: "HelloRN"
        val initialPath = args.getString(ARG_INITIAL_PATH) ?: "/"

        val initialProps = Bundle().apply {
            putString("initialPath", initialPath)
            putString("platform", "android")
        }

        val app = requireActivity().application as ReactApplication
        val view = ReactRootView(requireContext())
        view.startReactApplication(
            app.reactNativeHost.reactInstanceManager,
            appName,
            initialProps
        )
        reactRootView = view
        return view
    }

    override fun onDestroyView() {
        reactRootView?.unmountReactApplication()
        reactRootView = null
        super.onDestroyView()
    }

    companion object {
        private const val ARG_APP_NAME = "appName"
        private const val ARG_INITIAL_PATH = "initialPath"
        private const val ARG_PARAMS = "params"

        fun newInstance(
            appName: String,
            initialPath: String,
            params: HashMap<String, String>
        ): RNContainerFragment = RNContainerFragment().apply {
            arguments = Bundle().apply {
                putString(ARG_APP_NAME, appName)
                putString(ARG_INITIAL_PATH, initialPath)
                putSerializable(ARG_PARAMS, params)
            }
        }
    }
}
