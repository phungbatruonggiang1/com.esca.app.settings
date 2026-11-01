# ESCA Settings — the application

Connect the board to a network and pair Bluetooth devices: Wi-Fi, Ethernet
and Bluetooth for now, more sections later.

A Flutter application, talking to `esca-settingsd` (`vn.sparc.esca.Settings1`)
over the system bus. It holds no state of its own: every page is the service's
answer, refreshed when the service signals a change.

## Sections

- **Wi-Fi** — on/off, scan, join (password, hidden networks), forget, and
  DHCP or static IP for the wireless link.
- **Ethernet** — link state, speed, addresses, and DHCP or static IP.
- **Bluetooth** — power, visibility, discovery, pair/connect/remove. When a
  device asks to confirm a code or enter a PIN, the service relays the
  question and the app shows it as a dialog.

## Develop

    flutter test                 # controller and widget tests, on a fake service
    flutter test test_screenshots/settings_shot_test.dart --update-goldens

The screenshot run renders each page at 1920×1200 for review; it is not part
of the repository.
