# Garmin Hue Heartbeat App

This Garmin Connect IQ app connects to your Philips Hue lights and changes the color of a selected zone based on your current heart rate.

## Features

*   Displays your current heart rate on your Garmin device.
*   Connects to your Philips Hue account using OAuth 2.0.
*   Allows you to select a Hue zone (group of lights) to control.
*   Changes the color of the selected zone based on your heart rate:
    *   **Blue**: Low heart rate (< 100 bpm)
    *   **Green**: Moderate heart rate (100-140 bpm)
    *   **Red**: High heart rate (> 140 bpm)

## Setup

1.  **Philips Hue Developer Account**:
    *   Go to the [Philips Hue Developer Portal](https://developers.meethue.com/) and create an account.
    *   Create a new Remote API App.
    *   Set the "Redirect URI" for your app to `https://localhost`.
    *   Note your **Client ID** and **Client Secret**.

2.  **Update `HueController.mc`**:
    *   Open the `source/HueController.mc` file.
    *   Replace `"YOUR_CLIENT_ID"` and `"YOUR_CLIENT_SECRET"` with the credentials from your Hue app.

3.  **Build and Install**:
    *   Use the Garmin Connect IQ extension in Visual Studio Code to build the app and run it in the simulator or on your device.

## How to Use

1.  **Authorization**:
    *   The first time you launch the app, it will prompt you to authorize with your Philips Hue account. Follow the on-screen instructions. This will involve logging in to your Hue account in a web browser.

2.  **Select a Zone**:
    *   After authorization, the app will display a list of your available Hue zones.
    *   Select the zone you want to control.

3.  **Heart Rate Monitoring**:
    *   The app will now display your heart rate and change the color of the selected Hue zone accordingly.

## Customization

You can customize the heart rate ranges and corresponding colors by editing the `updateHueColor` method in `source/GarminHueHeartbeatAppView.mc`.
