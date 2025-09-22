using Toybox.WatchUi;
using Toybox.System;
using Toybox.Application;
using Toybox.Lang;

class GarminHueHeartbeatAppMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _controller as HueController;
    private var _view as GarminHueHeartbeatAppView;

    function initialize(controller as HueController, view as GarminHueHeartbeatAppView) {
        Menu2InputDelegate.initialize();
        _controller = controller;
        _view = view;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id.equals("login")) {
            System.println("Menu: Login selected.");
            _controller.authorize();
        } else if (id.equals("logout")) {
            System.println("Menu: Logout selected.");
            // Clear stored tokens
            Application.Storage.clearValues();
            _view.setState(_view.STATE_LOGGED_OUT);
        } else if (id instanceof Lang.Number) {
            // It's a room selection
            var rooms = _view.getRooms();
            if (rooms != null) {
                var selectedRoom = rooms[id as Lang.Number] as Lang.Dictionary;
                var selectedRoomId = selectedRoom["id"] as Lang.String;
                _controller.setSelectedRoomId(selectedRoomId);
                _view.setState((_view as GarminHueHeartbeatAppView).STATE_RUNNING);
            }
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}