package com.threatmetrix.cordova.plugin;
// The native Toast API
import android.widget.Toast;
import android.util.Log;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

// Cordova-required packages
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import com.lexisnexisrisk.threatmetrix.TMXConfig;
import com.lexisnexisrisk.threatmetrix.TMXEndNotifier;
import com.lexisnexisrisk.threatmetrix.TMXProfiling;
import com.lexisnexisrisk.threatmetrix.tmxprofilingconnections.TMXProfilingConnections;
import com.lexisnexisrisk.threatmetrix.TMXProfilingConnectionsInterface;
import com.lexisnexisrisk.threatmetrix.TMXProfilingHandle;
import com.lexisnexisrisk.threatmetrix.TMXProfilingOptions;
import com.lexisnexisrisk.threatmetrix.TMXScanEndNotifier;
import com.lexisnexisrisk.threatmetrix.TMXStatusCode;


public class TMXProfilingPlugin extends CordovaPlugin {
    
    private static final String DURATION_LONG = "long";

    /**
     * This is tied to a specific account, and needs to be modified. Using the default value
     * here will not work.
     */
    final static String ORG_ID             = "bkycs9pf";
    /**
     * This is tied to a specific account, and needs to be modified.
     */
    final static String FP_SERVER          = "fms-dev.citysavings.net.ph";

    /**
     * The session id used in profiling, this can be created by ThreatMetrix SDK or passed to
     * profiling request. NOTE: session id must be unique otherwise the result of API call will
     * be unexpected.
     */

     private String      m_sessionID;
    @Override
    public boolean execute(String action, JSONArray args,
        final CallbackContext callbackContext) {
        if (!action.equals("show") && !action.equals("profile")) {
            callbackContext.error("\"" + action + "\" is not a recognized action.");
            return false;
        }
        if (action.equals("show")) {
            String message;
            String duration;
            try {
                JSONObject options = args.getJSONObject(0);
                message = options.getString("message");
                duration = options.getString("duration");
            } catch (JSONException e) {
                callbackContext.error("Error encountered: " + e.getMessage());
                return false;
            }
            // Create the toast
            Toast toast = Toast.makeText(cordova.getActivity(), message,
                    DURATION_LONG.equals(duration) ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT);
            // Display toast
            toast.show();
            // Send a positive result to the callbackContext
            PluginResult pluginResult = new PluginResult(PluginResult.Status.OK);
            callbackContext.sendPluginResult(pluginResult);
            return true;
        }
        else if (action.equals("profile")) {
                TMXProfilingConnections tmxConn = new TMXProfilingConnections();
                TMXConfig config = new TMXConfig().setOrgId(ORG_ID)                           // (REQUIRED) Organisation ID
                .setFPServer(FP_SERVER)                     // (REQUIRED) Enhanced fingerprint server
                .setContext(this.cordova.getActivity().getApplicationContext())        // (REQUIRED) Application Context
                .setDisableInitPackageScan(false)
                .setDisableProfilePackageScan(false)
                .setProfilingConnections(tmxConn);
          try
          {
              TMXProfiling.getInstance().init(config);
              //Init was successful or there is a valid instance to be used for further calls. Fire a profile request
              
              doProfile();
          }
          catch(IllegalArgumentException exception)
          {
              
              /*
               * An unsuccessful init() is an indication of programming error in our code. Therefore we
               * should disable the UI to prevent login.
               * */
          }
          return true;
        }
      return false;
        }
    void doProfile()
    {
        List<String> list = new ArrayList<String>();
        list.add("attribute 1");
        list.add("attribute 2");
        TMXProfilingOptions options = new TMXProfilingOptions().setCustomAttributes(list);
        // Fire off the profiling request. We could use a more complex request,
        // but the minimum works fine for our purposes.
        TMXProfilingHandle profilingHandle = TMXProfiling.getInstance().profile(options,
                new CompletionNotifier());
    }

    private class CompletionNotifier implements TMXEndNotifier
    {
        /**
         * This gets called when the profiling has finished.
         * We have to be careful here because we are not going to be called on the UI thread, and
         * if we want to update UI elements we can only do it from the UI thread.
         */
        @Override
        public void complete(TMXProfilingHandle.Result result)
        {
            //Get the session id to use in API call (AKA session query)
            m_sessionID = result.getSessionID();

            

            /*
             * Profiling is complete, so login can proceed when the Login button is clicked.
             */
            // setProfileFinished(true);

            /*
             * Fire off a package scan. This will run in the background and process any newly installed apps
             *
             * We pass a value of 0 to disable the timeout, it will run until either all packages are scanned.
             * PackageScan runs on a different thread and doesn't interfere with LemonBank app or profiling request
             */
            TMXProfiling.getInstance().scanPackages(new TMXScanEndNotifier() {
                @Override
                public void complete() {
                    Log.i("TMXProfilingManager", " Scan is completed");
                }
            });

            /*
             * The Login button is clicked before the profiling is finished, therefore we should login
             * */
//            if(isLoginClicked())
//            {
//                login();
//            }
            // Toast toast = Toast.makeText(cordova.getActivity(), "profile finished", Toast.LENGTH_LONG);
            // Display toast
            // toast.show();
        }
    }
}