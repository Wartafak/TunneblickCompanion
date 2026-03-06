# Tunnelblick Companion

Tunnelblick Companion is a small macOS menu bar app that watches Tunnelblick logs, detects authorization URLs, opens them in your browser, and then confirms the Tunnelblick dialog automatically.

## Requirements

- macOS
- Tunnelblick installed and running
- Permission to access Tunnelblick logs in:
  - `/Library/Application Support/Tunnelblick/Logs`

## Install (from GitHub Releases)

1. Open this repository's **Releases** page.
2. Download `Tunneblick.Companion.zip` from the latest release.
3. Open your Downloads folder and extract the zip.
4. Drag **Tunnelblick Companion.app** into your **Applications** folder.
5. Launch the app from Applications.

If Gatekeeper blocks first launch, right-click the app, choose **Open**, then confirm.

## Build in Xcode (from source)

1. Open `Tunnelblick Companion.xcodeproj` in Xcode.
2. Select the `Tunnelblick Companion` scheme.
3. Choose **My Mac** as the run destination.
4. Build and run the app (`Cmd+B` / `Cmd+R`).
5. In Xcode, under **Product** choose **Show build folder in finder**.
6. Under the folder Products/Debug Drag **Tunnelblick Companion.app** into your **Applications** folder.

## Required macOS Permissions

Tunnelblick Companion needs **Accessibility** and **Automation** permissions to interact with Tunnelblick's UI.

### 1) Accessibility Permission

The app requests this on first launch.

To enable manually:

1. Open **System Settings**.
2. Go to **Privacy & Security** -> **Accessibility**.
3. Find **Tunnelblick Companion** in the list and turn it **On**.
4. Quit and reopen Tunnelblick Companion.

### 2) Automation Permission

The app also requests Automation access on first launch (for **System Events** control).

To enable manually:

1. Open **System Settings**.
2. Go to **Privacy & Security** -> **Automation**.
3. Select **Tunnelblick Companion**.
4. Enable access for **System Events**.
5. Quit and reopen Tunnelblick Companion.

## First Run Checklist

- Start Tunnelblick and trigger a VPN connection that requires authorization.
- Keep Tunnelblick Companion running in the menu bar.
- Confirm both permissions are enabled if the app shows a permissions warning.

## How It Works

- Monitors latest Tunnelblick log files.
- Detects lines containing `Please authorize at`.
- Opens the authorization URL in your browser.
- Polls the URL until auth is complete.
- Returns to Tunnelblick and clicks **OK** automatically.

## Troubleshooting

- **No menu bar icon appears**: Relaunch the app from `/Applications`.
- **Permission alert keeps showing**: Re-check both permission panels and ensure toggles are enabled.
- **App does not click OK**: Verify Automation access to **System Events** is enabled.
- **No auth URL detected**: Confirm Tunnelblick is writing logs under `/Library/Application Support/Tunnelblick/Logs`.
