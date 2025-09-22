using Toybox.Application;
using Toybox.WatchUi;
using Toybox.System;
using Toybox.Lang;

class GarminHueHeartbeatAppDelegate extends WatchUi.BehaviorDelegate {
    var _hueController;
    var _view;

    function initialize(hueController, view) {
        BehaviorDelegate.initialize();
        _hueController = hueController;
        _view = view;
    }

    function onMenu() as Lang.Boolean {
        var menu = new WatchUi.Menu2({:title=>"Hue Menu"});
        
        if (_hueController.hasTokens()) {
            menu.addItem(new WatchUi.MenuItem("Logout", null, "logout", null));
        } else {
            menu.addItem(new WatchUi.MenuItem("Login", null, "login", null));
        }
        
        // Pass both the controller and the view to the menu delegate
        WatchUi.pushView(menu, new GarminHueHeartbeatAppMenuDelegate(_hueController, _view), WatchUi.SLIDE_UP);
        return true;
    }
}