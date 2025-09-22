import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application.Storage;
import Toybox.System;
import Toybox.Communications;
import Toybox.Authentication; // Added import

class GarminHueHeartbeatAppApp extends Application.AppBase {

    var _hueController;
    var _view;
    var _delegate;

    function initialize() {
        AppBase.initialize();
        _hueController = new HueController();
        _view = new GarminHueHeartbeatAppView(_hueController);
        _delegate = new GarminHueHeartbeatAppDelegate(_hueController, _view);
        // Register the global OAuth message handler as per the example
        Authentication.registerForOAuthMessages(method(:onOAuthMessage));
    }

    function onStart(state as Dictionary?) as Void {
        // Re-enabling token deletion to ensure we test the login flow and confirm the crash is fixed.
        // You can comment these out again later to stay logged in.
        Storage.deleteValue("accessToken");
        Storage.deleteValue("refreshToken");
        Storage.deleteValue("selectedGroupId");
    }

    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your application here
    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [ _view, _delegate ];
    }

    function getHueController() as HueController {
        return _hueController;
    }

    // --- CORRECT Implementation: This is the system callback for OAuth ---
    function onOAuthMessage(message as Authentication.OAuthMessage) as Void {
        System.println("App: onOAuthMessage triggered. Response Code: " + message.responseCode);
        
        if (message.responseCode == 200) {
            // The message.data dictionary will now contain the authorization code
            // that we need to exchange for an access token.
            _hueController.onOAuthResponse(message.data);
        } else {
            _view.setMessage("OAuth Failed\nCode: " + message.responseCode);
            _view.setState(4);
            System.println("App: onOAuthMessage failed.");
        }
    }
}

function getApp() as GarminHueHeartbeatAppApp {
    return Application.getApp() as GarminHueHeartbeatAppApp;
}
