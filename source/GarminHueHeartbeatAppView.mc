using Toybox.WatchUi;
using Toybox.System;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;
using Toybox.Sensor;

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
    private var _hrLabel as WatchUi.Text?;
    private var _rooms as Lang.Array?;
    private var _currentColor as Lang.Number?;

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
        _hrLabel = findDrawableById("HeartRateLabel") as WatchUi.Text;
    }

    function onShow() as Void {
        // Force re-evaluation of the state every time the app is shown
        _currentState = STATE_INITIALIZING;
        System.println("View: onShow triggered. Resetting state to INITIALIZING.");
        runLogic();
    }

    function onHide() as Void {
        System.println("View onHide");
        Sensor.setEnabledSensors([]);
    }

    // Update the view
    function onUpdate(dc as Graphics.Dc) as Void {
        if (_textLabel != null) {
            _textLabel.setText(_message);
        }
        View.onUpdate(dc);

        if (_currentState == STATE_RUNNING && _currentColor != null) {
            dc.setColor(_currentColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(dc.getWidth() / 2, dc.getHeight() / 2 + 40, 20);
        }
    }

    function onSensorData(sensorInfo as Sensor.Info) as Void {
        var hr = 0;
        if (sensorInfo.heartRate != null) {
            hr = sensorInfo.heartRate;
        }
        _controller.setHeartRate(hr);
    }

    public function updateHeartRateDisplay(hr as Lang.Number, color as Lang.Number) as Void {
        _currentColor = color;
        if (_hrLabel != null) {
            _hrLabel.setText("HR: " + hr.toString());
        } else {
            // Fallback if the label isn't found
            _message = "HR: " + hr.toString();
        }
        WatchUi.requestUpdate();
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
            if (_hrLabel != null) {
                _hrLabel.setText("open settings\nfor login");
            }
        } else if (state == STATE_FETCHING_DATA) {
            _message = "Fetching rooms...";
            _controller.getRooms();
        } else if (state == STATE_SELECT_ROOM) {
            if (_rooms != null && _rooms.size() > 0) {
                var menu = new WatchUi.Menu2({:title=>"Select a Room"});
                for (var i = 0; i < _rooms.size(); i++) {
                    var room = _rooms[i] as Lang.Dictionary;
                    menu.addItem(new WatchUi.MenuItem(room["name"], null, i, {}));
                }
                var delegate = new GarminHueHeartbeatAppMenuDelegate(_controller, self);
                WatchUi.pushView(menu, delegate, WatchUi.SLIDE_UP);
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
                 Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
                 Sensor.enableSensorEvents(method(:onSensorData));
            } else {
                _message = "No room selected.\nPress Menu.";
            }
        } else if (state == STATE_REGISTERING) {
            _message = "Registering app...";
            _controller.startRegistration(); 
        }
        System.println("runLogic: "+_message);
        WatchUi.requestUpdate();
    }
}