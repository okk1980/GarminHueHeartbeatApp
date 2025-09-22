using Toybox.WatchUi;
using Toybox.System;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;
using Toybox.Timer;

class GarminHueHeartbeatAppView extends WatchUi.View {
    // Define constants for the states
    public const STATE_INITIALIZING = 0;
    public const STATE_LOGGED_OUT = 1;
    public const STATE_FETCHING_DATA = 2;
    public const STATE_SELECT_ROOM = 3;
    public const STATE_ERROR = 4;
    public const STATE_RUNNING = 5;
    public const STATE_REGISTERING = 6;

    private var _currentState as Lang.Number = STATE_INITIALIZING;
    private var _controller as HueController;
    private var _message as Lang.String = "Initializing...";
    private var _textLabel as WatchUi.Text?;
    private var _rooms as Lang.Array?;

    function initialize(hueController as HueController) {
        View.initialize();
        _controller = hueController;
        _controller.setView(self);
    }

    function setRooms(rooms as Lang.Array) as Void {
        _rooms = rooms;
    }

    function getRooms() as Lang.Array? {
        return _rooms;
    }

    // Load your resources here
    function onLayout(dc as Graphics.Dc) as Void {
        setLayout(Rez.Layouts.MainLayout(dc));
        _textLabel = findDrawableById("text_label") as WatchUi.Text;
    }

    function onShow() as Void {
        System.println("View: onShow triggered. Current state: " + _currentState);
        runLogic();
    }

    function onHide() as Void {
        System.println("View onHide");
    }

    // Update the view
    function onUpdate(dc as Graphics.Dc) as Void {
        if (_textLabel != null) {
            _textLabel.setText(_message);
        }
        View.onUpdate(dc);
    }

    function setMessage(message as Lang.String) as Void {
        _message = message;
        WatchUi.requestUpdate();
    }

    function setState(state as Lang.Number) as Void {
        if (_currentState != state) {
            _currentState = state;
            System.println("View setState to: " + _currentState);
            runLogic();
        }
    }

    function runLogic() as Void {
        var state = _currentState;
        System.println("View runLogic, state: " + state);

        if (state == STATE_INITIALIZING) {
            if (_controller.hasTokens()) {
                var appKey = Application.Storage.getValue("hueApplicationKey");
                if (appKey == null) {
                    // If we have OAuth tokens but no app key, we need to register.
                    setState(STATE_REGISTERING);
                } else {
                    var selectedRoomId = Application.Storage.getValue("selectedRoomId");
                    if (selectedRoomId != null) {
                        setState(STATE_RUNNING);
                    } else {
                        setState(STATE_FETCHING_DATA);
                    }
                }
            } else {
                setState(STATE_LOGGED_OUT);
            }
        } else if (state == STATE_LOGGED_OUT) {
             _message = "Logged Out.\nPress Menu";
        } else if (state == STATE_FETCHING_DATA) {
            _message = "Fetching rooms...";
            _controller.getRooms();
        } else if (state == STATE_SELECT_ROOM) {
            if (_rooms != null && _rooms.size() > 0) {
                var menu = new WatchUi.Menu2({:title=>"Select a Room"});
                for (var i = 0; i < _rooms.size(); i++) {
                    var room = _rooms[i] as Lang.Dictionary;
                    var roomName = room["name"] as Lang.String;
                    menu.addItem(new WatchUi.MenuItem(roomName, null, i, {}));
                }
                var delegate = new GarminHueHeartbeatAppMenuDelegate(_controller, self);
                WatchUi.pushView(menu, delegate, WatchUi.SLIDE_UP);
                _currentState = STATE_RUNNING; 
            } else {
                _message = "No rooms found.";
                setState(STATE_ERROR);
            }
        } else if (state == STATE_ERROR) {
            // Message is set by the controller
        } else if (state == STATE_RUNNING) {
            var selectedRoomId = Application.Storage.getValue("selectedRoomId");
            if (selectedRoomId != null) {
                 _message = "Monitoring HR...";
            } else {
                _message = "No room selected.\nPress Menu.";
            }
        } else if (state == STATE_REGISTERING) {
            _message = "Registering app...";
            // This will trigger the chained registration process in the controller
            _controller.startRegistration(); 
        }
        System.println("runLogic: "+_message);
        WatchUi.requestUpdate();
    }
}
