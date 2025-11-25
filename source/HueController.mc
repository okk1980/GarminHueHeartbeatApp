using Toybox.Application;
using Toybox.Authentication;
using Toybox.Communications;
using Toybox.System;
using Toybox.WatchUi;
using Toybox.Lang;
using Toybox.StringUtil;
using Toybox.PersistedContent;

class HueController {
    private var _view as GarminHueHeartbeatAppView?;

    // OAuth Details
    private var _clientId as Lang.String;
    private var _clientSecret as Lang.String;
    private var _redirectUrl as Lang.String;

    // Token Storage
    private var _token as Lang.String?;
    private var _refreshToken as Lang.String?;
    private var _tokenExpires as Lang.Number?;
    private var _lastColor as Lang.Number?;

    function initialize() {
        _clientId = WatchUi.loadResource(Rez.Strings.clientId) as Lang.String;
        _clientSecret = WatchUi.loadResource(Rez.Strings.clientSecret) as Lang.String;
        _redirectUrl = "https://connect.garmin.com/modern/oauth-callback";
    }

    function setView(view as GarminHueHeartbeatAppView) as Void {
        _view = view;
    }

    public function onOAuthResponse(data as Null or Lang.Dictionary) as Void {
        System.println("Controller: onOAuthResponse triggered with auth code.");
        if (data != null && data.hasKey("code")) {
            var authCode = data["code"];
            exchangeCodeForToken(authCode);
        } else {
            System.println("OAuth failed: No authorization code in response.");
            if (_view != null) {
                _view.setMessage("Login Failed\nNo Auth Code");
                _view.setState((_view as GarminHueHeartbeatAppView).STATE_ERROR);
            }
        }
    }

    function exchangeCodeForToken(authCode as Lang.String) as Void {
        System.println("Exchanging authorization code for token.");
        var url = "https://api.meethue.com/v2/oauth2/token";
        var params = {
            "grant_type" => "authorization_code",
            "code" => authCode,
            "redirect_uri" => _redirectUrl
        };

        // The Hue API requires Basic authentication for this step.
        // We'll create a Base64 encoded string of "clientId:clientSecret".
        var basicAuth = "Basic " + StringUtil.encodeBase64(_clientId + ":" + _clientSecret);

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Authorization" => basicAuth,
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Communications.makeWebRequest(url, params, options, method(:onTokenResponse));
    }

    function authorize() as Void {
        var params = {
            "scope" => "basic.clip",
            "response_type" => "code",
            "client_id" => _clientId,
            "state" => "garmin-hue",
            "redirect_uri" => _redirectUrl
        };

        // This request will open a webview on the user's phone.
        // After login, the webview will redirect to _redirectUrl with a `code` parameter.
        // The `resultKeys` map tells the Garmin OS to extract the `code` parameter
        // from the redirect URL and put it in the OAuthMessage data with the key "code".
        Authentication.makeOAuthRequest(
            "https://api.meethue.com/v2/oauth2/authorize",
            params,
            _redirectUrl,
            Authentication.OAUTH_RESULT_TYPE_URL,
            { "code" => "code" } // Extract the 'code' parameter from the redirect URL
        );
    }

    function hasTokens() as Lang.Boolean {
        var accessToken = Application.Storage.getValue("accessToken");
        var refreshToken = Application.Storage.getValue("refreshToken");
        return accessToken != null && refreshToken != null;
    }

    public function onTokenResponse(responseCode as Lang.Number, data as Null or Lang.Dictionary or Lang.String) as Void {
        System.println("onTokenResponse triggered. Code: " + responseCode);
        if (responseCode == 200 && data instanceof Lang.Dictionary) {
            System.println("Token exchange successful.");
            var tokenData = data as Lang.Dictionary;
            _token = tokenData["access_token"] as Lang.String;
            _refreshToken = tokenData["refresh_token"] as Lang.String;
            var expiresIn = tokenData["expires_in"] as Lang.Number;

            Application.Storage.setValue("accessToken", _token);
            Application.Storage.setValue("refreshToken", _refreshToken);
            _tokenExpires = System.getClockTime().sec + expiresIn;
            Application.Storage.setValue("tokenExpires", _tokenExpires);

            System.println("Access token stored. Checking for app key...");
            var appKey = Application.Storage.getValue("hueApplicationKey");
            if (appKey == null) {
                System.println("No app key found, starting registration process.");
                startRegistration();
            } else {
                System.println("App key found, proceeding to fetch data.");
                if (_view != null) {
                    _view.setState((_view as GarminHueHeartbeatAppView).STATE_FETCHING_DATA);
                }
            }
        } else {
            System.println("Token exchange failed with code: " + responseCode);
            if (_view != null) {
                _view.setMessage("Login Failed\nCode: " + responseCode);
                _view.setState((_view as GarminHueHeartbeatAppView).STATE_ERROR);
            }
        }
    }

    function startRegistration() as Void {
        System.println("Controller: startRegistration called.");
        enableLinkButton();
    }

    function enableLinkButton() as Void {
        var accessToken = Application.Storage.getValue("accessToken");
        var url = "https://api.meethue.com/route/api/0/config";
        var params = {
            "linkbutton" => true
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_PUT,
            :headers => {
                "Authorization" => "Bearer " + accessToken,
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        System.println("Making enable link button request to: " + url);
        Communications.makeWebRequest(url, params, options, method(:onEnableLinkButtonResponse));
    }

    function onEnableLinkButtonResponse(responseCode as Lang.Number, data as Null or Lang.Dictionary or Lang.String or PersistedContent.Iterator) as Void {
        System.println("onEnableLinkButtonResponse triggered. Code: " + responseCode);
        if (responseCode == 200) {
            System.println("Enable link button successful. Now registering application.");
            registerApplication();
        } else {
            System.println("Enable link button failed with code: " + responseCode);
            if (_view != null) {
                _view.setMessage("Link Fail\nCode: " + responseCode);
                _view.setState((_view as GarminHueHeartbeatAppView).STATE_ERROR);
            }
        }
    }

    function registerApplication() as Void {
        var accessToken = Application.Storage.getValue("accessToken");
        var url = "https://api.meethue.com/route/api";
        var params = {
            "devicetype" => "garmin_hue_app#fenix"
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Authorization" => "Bearer " + accessToken,
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        System.println("Making app registration request to: " + url);
        Communications.makeWebRequest(url, params, options, method(:onRegisterApplicationResponse));
    }

    public function onRegisterApplicationResponse(responseCode as Lang.Number, data as Null or Lang.Dictionary or Lang.String or PersistedContent.Iterator) as Void {
        System.println("onRegisterApplicationResponse triggered. Code: " + responseCode);

        if (responseCode == 200) {
            // Directly cast to Array, bypassing the problematic instanceof check
            var dataArray = data as Lang.Array;
            if (dataArray != null && dataArray.size() > 0) {
                var responseDict = dataArray[0] as Lang.Dictionary;
                if (responseDict.hasKey("success")) {
                    var successData = responseDict["success"] as Lang.Dictionary;
                    var appKey = successData["username"] as Lang.String;
                    Application.Storage.setValue("hueApplicationKey", appKey);
                    System.println("Successfully registered app and stored key: " + appKey);
                    if (_view != null) {
                        _view.setState((_view as GarminHueHeartbeatAppView).STATE_FETCHING_DATA);
                    }
                } else if (responseDict.hasKey("error")) {
                    var errorData = responseDict["error"] as Lang.Dictionary;
                    var errorDescription = errorData["description"] as Lang.String;
                    if (_view != null) {
                        _view.setMessage("Reg Error:\n" + errorDescription);
                        _view.setState((_view as GarminHueHeartbeatAppView).STATE_ERROR);
                    }
                }
            } else {
                 if (_view != null) {
                    _view.setMessage("Reg Failed\nEmpty Resp");
                    _view.setState((_view as GarminHueHeartbeatAppView).STATE_ERROR);
                }
            }
        } else {
            if (_view != null) {
                _view.setMessage("Reg Failed\nCode: " + responseCode);
                _view.setState((_view as GarminHueHeartbeatAppView).STATE_ERROR);
            }
        }
    }

    public function getRooms() as Void {
        var accessToken = Application.Storage.getValue("accessToken");
        var appKey = Application.Storage.getValue("hueApplicationKey");
        if (accessToken == null || appKey == null) {
            System.println("Cannot get rooms, missing tokens or app key.");
            if (_view != null) {
                _view.setMessage("Auth Error");
                _view.setState((_view as GarminHueHeartbeatAppView).STATE_ERROR);
            }
            return;
        }

        var url = "https://api.meethue.com/route/clip/v2/resource/room";
        var params = {};
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => {
                "Authorization" => "Bearer " + accessToken,
                "hue-application-key" => appKey
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        System.println("Making get rooms request to: " + url);
        Communications.makeWebRequest(url, params, options, method(:onGetRoomsResponse));
    }

    public function onGetRoomsResponse(responseCode as Lang.Number, data as Null or Lang.Dictionary or Lang.String or PersistedContent.Iterator) as Void {
        System.println("onGetRoomsResponse triggered. Code: " + responseCode);
        if (responseCode == 200 && data instanceof Lang.Dictionary) {
            var rooms = [] as Lang.Array<Lang.Dictionary>;
            var dataDict = data as Lang.Dictionary;
            if (dataDict.hasKey("data")) {
                var roomsData = dataDict["data"] as Lang.Array<Lang.Dictionary>;
                for (var i = 0; i < roomsData.size(); i++) {
                    var roomData = roomsData[i];
                    if (roomData.hasKey("type") && "room".equals(roomData["type"]) && roomData.hasKey("services")) {
                        var services = roomData["services"] as Lang.Array<Lang.Dictionary>;
                        for (var j = 0; j < services.size(); j++) {
                            var service = services[j];
                            if (service.hasKey("rtype") && "grouped_light".equals(service["rtype"])) {
                                var metadata = roomData["metadata"] as Lang.Dictionary;
                                rooms.add({
                                    "id" => service["rid"], // Use the grouped_light resource ID
                                    "name" => metadata["name"]
                                });
                                break; // Found the grouped_light, move to the next room
                            }
                        }
                    }
                }
            }
            if (_view != null) {
                _view.setRooms(rooms);
                _view.setState((_view as GarminHueHeartbeatAppView).STATE_SELECT_ROOM);
            }
        } else {
            System.println("Get rooms failed with code: " + responseCode);
            if (_view != null) {
                _view.setMessage("Get Rooms Fail\nCode: " + responseCode);
                _view.setState((_view as GarminHueHeartbeatAppView).STATE_ERROR);
            }
        }
    }

    public function setRoomColor(roomId as Lang.String, color as Lang.Number) as Void {
        var accessToken = Application.Storage.getValue("accessToken");
        var appKey = Application.Storage.getValue("hueApplicationKey");

        if (accessToken == null || appKey == null) {
            System.println("Cannot set room color, missing tokens or app key.");
            return;
        }

        // Convert Graphics color to Hue XY color space
        var xy = convertColorToHueXY(color);

        var url = "https://api.meethue.com/route/clip/v2/resource/grouped_light/" + roomId;
        var params = {
            "color" => {
                "xy" => {
                    "x" => xy[0],
                    "y" => xy[1]
                }
            }
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_PUT,
            :headers => {
                "Authorization" => "Bearer " + accessToken,
                "hue-application-key" => appKey,
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        System.println("Setting room color. URL: " + url);
        Communications.makeWebRequest(url, params, options, method(:onSetRoomColorResponse));
    }

    public function onSetRoomColorResponse(responseCode as Lang.Number, data as Null or Lang.Dictionary) as Void {
        System.println("onSetRoomColorResponse triggered. Code: " + responseCode);
        if (responseCode != 200) {
            System.println("Failed to set room color. Response: " + data);
        }
    }

    // This is a simplified conversion. For accurate colors, a more complex RGB -> CIE 1931 conversion is needed.
    private function convertColorToHueXY(color as Lang.Number) as Lang.Array<Lang.Float> {
        var red = (color >> 16) & 0xFF;
        var green = (color >> 8) & 0xFF;
        var blue = color & 0xFF;

        if (red == 0xAA && green == 0xAA && blue == 0xAA) { // Approx Gray
            return [0.3227f, 0.329f];
        }

        // Normalize to 0-1
        var r = red / 255.0f;
        var g = green / 255.0f;
        var b = blue / 255.0f;

        // Apply gamma correction
        r = (r > 0.04045) ? Math.pow((r + 0.055) / (1.0 + 0.055), 2.4).toFloat() : (r / 12.92);
        g = (g > 0.04045) ? Math.pow((g + 0.055) / (1.0 + 0.055), 2.4).toFloat() : (g / 12.92);
        b = (b > 0.04045) ? Math.pow((b + 0.055) / (1.0 + 0.055), 2.4).toFloat() : (b / 12.92);

        // Convert to CIE XYZ
        var X = r * 0.664511 + g * 0.154324 + b * 0.162028;
        var Y = r * 0.283881 + g * 0.668433 + b * 0.047685;
        var Z = r * 0.000088 + g * 0.072310 + b * 0.986039;

        var sum = X + Y + Z;
        if (sum == 0) {
            return [0.0f, 0.0f]; // Should not happen with colors
        }

        var x = X / sum;
        var y = Y / sum;

        return [x, y];
    }

 
 // Helper function to interpolate between two colors
private function interpolateColor(startColor as Lang.Number, endColor as Lang.Number, startVal as Lang.Number, endVal as Lang.Number, currentVal as Lang.Number) as Lang.Number {
    var factor = (currentVal - startVal).toFloat() / (endVal - startVal).toFloat();

    var startR = (startColor >> 16) & 0xFF;
    var startG = (startColor >> 8) & 0xFF;
    var startB = startColor & 0xFF;

    var endR = (endColor >> 16) & 0xFF;
    var endG = (endColor >> 8) & 0xFF;
    var endB = endColor & 0xFF;

    var newR = (startR + factor * (endR - startR)).toNumber();
    var newG = (startG + factor * (endG - startG)).toNumber();
    var newB = (startB + factor * (endB - startB)).toNumber();

    return Graphics.createColor(255, newR, newG, newB);
}

    private function calculateColorForHr(hr as Lang.Number) as Lang.Number {
        // Define HR zones and colors
        var COLOR_GRAY = Graphics.COLOR_LT_GRAY; // 0xAAAAAA
        var COLOR_BLUE = 0x0000FF;
        var COLOR_GREEN = 0x00FF00;
        var COLOR_ORANGE = 0xFFAA00;
        var COLOR_RED = Graphics.COLOR_RED; // 0xFF0000

        if (hr <= 60) {
            return COLOR_GRAY;
        } else if (hr <= 80) { // Gray to Blue
            return interpolateColor(COLOR_GRAY, COLOR_BLUE, 61, 80, hr);
        } else if (hr <= 110) { // Blue to Green
            return interpolateColor(COLOR_BLUE, COLOR_GREEN, 81, 110, hr);
        } else if (hr <= 140) { // Green to Orange
            return interpolateColor(COLOR_GREEN, COLOR_ORANGE, 111, 140, hr);
        } else if (hr <= 170) { // Orange to Red
            return interpolateColor(COLOR_ORANGE, COLOR_RED, 141, 170, hr);
        } else { // Above 170
            return COLOR_RED;
        }
    }

    function setHeartRate(hr as Lang.Number) as Void {
        var newColor = calculateColorForHr(hr);

        // Only send API request if the color has changed
        if (_lastColor == null || _lastColor != newColor) {
            _lastColor = newColor;
            var selectedRoomId = Application.Storage.getValue("selectedRoomId");
            if (selectedRoomId != null) {
                setRoomColor(selectedRoomId, newColor);
            }
        }

        // Tell the view to update its display
        if (_view != null) {
            _view.updateHeartRateDisplay(hr, newColor);
        }
    }

    function setSelectedRoomId(roomId as Lang.String) as Void {
        Application.Storage.setValue("selectedRoomId", roomId);
        System.println("Selected room ID stored: " + roomId);
    }
}