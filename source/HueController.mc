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

    function initialize() {
        _clientId = WatchUi.loadResource(Rez.Strings.clientId) as Lang.String;
        _clientSecret = WatchUi.loadResource(Rez.Strings.clientSecret) as Lang.String;
        _redirectUrl = "https://localhost";
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
            "code" => authCode
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
            "state" => "garmin-hue"
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
                    if (roomData.hasKey("type") && "room".equals(roomData["type"])) {
                        var metadata = roomData["metadata"] as Lang.Dictionary;
                        rooms.add({
                            "id" => roomData["id"],
                            "name" => metadata["name"]
                        });
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

    function setHeartRate(hr as Lang.Number) as Void {
    }

    function setSelectedRoomId(roomId as Lang.String) as Void {
        Application.Storage.setValue("selectedRoomId", roomId);
        System.println("Selected room ID stored: " + roomId);
    }
}