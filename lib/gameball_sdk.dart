library gameball_sdk;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:gameball_sdk/network/request_calls/get_bot_settings_request.dart';
import 'package:gameball_sdk/utils/gameball_utils.dart';
import 'package:gameball_sdk/utils/language_utils.dart';
import 'package:gameball_sdk/utils/platform_utils.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'models/requests/event.dart';
import 'models/requests/player_attributes.dart';
import 'models/requests/player_register_request.dart';
import 'network/models/callbacks.dart';
import 'network/request_calls/create_player_request.dart';
import 'network/request_calls/send_event_request.dart';

import 'network/utils/constants.dart';

class GameballApp extends StatelessWidget {
  static GameballApp? _instance;
  static String _apiKey = "";
  static String _playerUniqueId = "";
  static String _deviceToken = "";
  static String _lang = "";
  static String? _platform;
  static String? _shop;
  static String? _playerPreferredLanguage;
  static String? _playerEmail;
  static String? _playerMobile;
  static String? _referralCode;
  static String? _openDetail;
  static bool? _hideNavigation;
  static bool _showCloseButton = true;
  static String? _mainColor = null;

  /// Retrieves the singleton instance of the GameballApp class.
  ///
  /// Creates a new instance if it doesn't exist and returns it.
  static GameballApp getInstance() {
    _instance ??= GameballApp();
    return _instance!;
  }

  /// Initializes the Gameball SDK with required parameters.
  ///
  /// Sets the API key, language, platform, and shop information for subsequent SDK operations.
  void init(String apiKey, String lang, String? platform, String? shop) {
    _lang = lang;
    _platform = platform;
    _shop = shop;
    _apiKey = apiKey;

    //_getBotSettings();

  }

  Future<void> _getBotSettings() async {
    try {
      String language = handleLanguage(_lang, _playerPreferredLanguage);
      getBotSettingsRequest(_apiKey, language)
          .then((response) {
        if (response != null) {
          _mainColor = response.botMainColor.replaceAll("#", "");
        } else {
          _mainColor = null;
        }
      });
    } catch (e) {
      _mainColor = null;
    }
  }

  /// Initializes Firebase Messaging and retrieves the device token.
  ///
  /// This method fetches the device token from Firebase Messaging and stores it
  /// in the `_deviceToken` property for later use.
  _initializeFirebase() {
    FirebaseMessaging.instance.getToken().then((token) {
      if (token != null) {
        _deviceToken = token;
      }
    });
  }

  /// Handles incoming Firebase Dynamic Links containing potential referral codes.
  ///
  /// This method retrieves any pending dynamic link upon app launch and checks
  /// if it contains a `GBReferral` query parameter. If a referral code is found,
  /// it invokes the provided callback function with the extracted code. Otherwise,
  /// the callback is called with `null` for both the referral code and any error.
  ///
  /// This method is typically used in conjunction with registering a listener
  /// for dynamic links to handle referrals throughout the app's lifecycle.
  Future<void> _handleDynamicLink(ReferralCodeCallback callback) async {
    final PendingDynamicLinkData? data =
        await FirebaseDynamicLinks.instance.getInitialLink();

    if (data != null) {
      final Uri deepLink = data.link;
      final referralCode = deepLink.queryParameters['GBReferral'];
      callback(referralCode, null);
    } else {
      callback(null, null);
    }
  }

  /// Registers a player with Gameball.
  ///
  /// This method initiates the player registration process, including fetching the device token, handling referral codes, and sending the registration request.
  ///
  /// Arguments:
  ///   - `playerUniqueId`: The unique identifier for the player.
  ///   - `playerEmail`: The player's email address (optional).
  ///   - `playerMobile`: The player's mobile number (optional).
  ///   - `playerAttributes`: Additional player attributes.
  ///   - `responseCallback`: A callback function to handle the registration response.
  Future<void> registerPlayer(
    String playerUniqueId,
    String? playerEmail,
    String? playerMobile,
    PlayerAttributes? playerAttributes,
    RegisterCallback? responseCallback,
  ) async {
    _playerUniqueId = playerUniqueId.trim();

    if (isNullOrEmpty(_playerUniqueId) || isNullOrEmpty(_apiKey)) {
      responseCallback!(null, null);
      return;
    }

    // _initializeFirebase();

    referralCodeRegistrationCallback(response, error) {
      if (error == null && response != null) {
        _referralCode = response;
      }
    }

    // await _handleDynamicLink(referralCodeRegistrationCallback)
    //     .then((response) {});

    final email = playerEmail?.trim();
    final mobile = playerMobile?.trim();

    if (!isNullOrEmpty(email)) {
      _playerEmail = email;
    }

    if (!isNullOrEmpty(mobile)) {
      _playerMobile = mobile;
    }

    if (playerAttributes?.preferredLanguage != null &&
        playerAttributes?.preferredLanguage?.length == 2) {
      _playerPreferredLanguage = playerAttributes?.preferredLanguage;
    }

    _registerDevice(playerAttributes, responseCallback);
  }

  /// Registers the device with Gameball using the provided player attributes.
  ///
  /// This method constructs a `PlayerRegisterRequest` object and sends it to the Gameball API.
  /// The callback is invoked with the response or any encountered error.
  ///
  /// Arguments:
  ///   - `playerAttributes`: Optional player attributes to include in the request.
  ///   - `callback`: The callback function to handle the registration result.
  void _registerDevice(
      PlayerAttributes? playerAttributes, RegisterCallback? callback) {
    PlayerRegisterRequest playerRegisterRequest = PlayerRegisterRequest(
        playerUniqueID: _playerUniqueId,
        deviceToken: _deviceToken,
        email: _playerEmail,
        mobileNumber: _playerMobile,
        playerAttributes: playerAttributes,
        referrerCode: _referralCode);

    try {
      String language = handleLanguage(_lang, _playerPreferredLanguage);
      createPlayerRequest(playerRegisterRequest, _apiKey, language)
          .then((response) {
        if (response != null) {
          callback!(response, null);
        } else {
          callback!(null, null);
        }
      });
    } catch (e) {
      callback!(null, e as Exception);
    }
  }

  /// Sends an event to Gameball.
  ///
  /// This method constructs an event request and sends it to the Gameball API.
  /// The callback is invoked with a success/failure indicator and any encountered error.
  ///
  /// Arguments:
  ///   - `eventBody`: The event data to be sent.
  ///   - `callback`: The callback function to handle the event sending result.s
  void sendEvent(Event eventBody, SendEventCallback? callback) {
    try {
      String language = handleLanguage(_lang, _playerPreferredLanguage);
      sendEventRequest(eventBody, _apiKey, language).then((response) {
        if (response.statusCode == 200) {
          callback!(true, null);
        } else {
          callback!(false, null);
        }
      });
    } catch (e) {
      callback!(null, e as Exception);
    }
  }

  /// Displays the Gameball profile in a bottom sheet.
  ///
  /// This method initiates the process of showing the Gameball profile within a bottom sheet.
  ///
  /// Arguments:
  ///   - `context`: The build context for creating the bottom sheet.
  ///   - `playerUniqueId`: The unique ID of the player.
  ///   - `openDetail`: An optional URL to open within the profile.
  ///   - `hideNavigation`: An optional flag to indicate if the navigation bar should be hidden.
  void showProfile(BuildContext context, String playerUniqueId,
      String? openDetail, bool? hideNavigation, bool? showCloseButton) {
    _playerUniqueId = playerUniqueId;
    _openDetail = openDetail;
    _hideNavigation = hideNavigation;
    if(showCloseButton != null){
      _showCloseButton = showCloseButton;
    }
    _openBottomSheet(context);
  }

  /// Opens a bottom sheet to display the Gameball profile.
  ///
  /// Creates a bottom sheet with a WebView displaying the Gameball profile based on the provided parameters.
  ///
  /// Arguments:
  ///   - `context`: The build context for creating the bottom sheet.
  void _openBottomSheet(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      isDismissible: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20.0),
        ),
      ),
      builder: (BuildContext context) {
        return GestureDetector(
          onVerticalDragUpdate: (details) {
            // Detecting the swipe down gesture
            if (details.delta.dy > 15) {
              // Navigator.of(context).pop(); // Close the bottom sheet on swipe down
            }
          },
          child: NotificationListener<OverscrollIndicatorNotification>(
            onNotification: (notification) {
              notification.disallowIndicator(); // Disallow overscroll indicator
              return true;
            },
            child: Container(
              height: MediaQuery.of(context).size.height * 0.93,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20.0),
                ),
                color: Colors.transparent,
              ),
              child: Stack(
                children: [
                  // WebView
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20.0),
                    ),
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(_buildWidgetUrl())),
                      // onWebViewCreated: (InAppWebViewController controller) {
                      // },
                      // onLoadStart: (controller, url) {
                      // },
                      // onLoadStop: (controller, url) async {
                      // },
                      onScrollChanged: (controller, x, y) {
                        if (y < 0) {
                          // User has scrolled to the top of the page
                          print("Scrolled to the top of the page");
                          Navigator.of(context).pop(); // Close the bottom sheet on swipe down
                        }
                      },
                      gestureRecognizers: {
                        Factory<VerticalDragGestureRecognizer>(
                              () => VerticalDragGestureRecognizer(),
                        ),
                      },
                    ),
                  ),
                  // Close button positioned at the top right corner
                  if(_showCloseButton)
                    Positioned(
                      top: 10.0,
                      right: 10.0,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the URL for the Gameball profile widget.
  ///
  /// Constructs the URL based on the provided parameters and returns it.
  String _buildWidgetUrl() {
    String language = handleLanguage(_lang, _playerPreferredLanguage);

    String widgetUrl = widgetBaseUrl;

    widgetUrl += '&playerid=$_playerUniqueId';

    widgetUrl += '&lang=$language';

    widgetUrl += '&apiKey=$_apiKey';

    if (!isNullOrEmpty(_platform)) {
      widgetUrl += '&platform=$_platform';
    }

    if (!isNullOrEmpty(_shop)) {
      widgetUrl += '&platform=$_shop';
    }

    widgetUrl += '&os=${getDevicePlatform()}';

    widgetUrl += '&sdk=Flutter-${getSdkVersion()}';

    if (!isNullOrEmpty(_openDetail)) {
      widgetUrl += '&openDetail=$_openDetail';
    }

    if (_hideNavigation != null) {
      widgetUrl += '&hideNavigation=$_hideNavigation';
    }

    if(_mainColor != null){
      widgetUrl += 'main=$_mainColor';
    }

    print(widgetUrl);

    return widgetUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
