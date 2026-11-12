# Spike S1 — global hotkey + tray + PRIMARY selection (X11)

Throwaway prototype used in Phase 0 to answer one question: **can a global
hot key be registered and its events received on this machine (X11 + Cinnamon +
Mesa)?**

## What it does
`lib/main.dart` registers `Ctrl+Alt+J` system-wide and, on every trigger,
prints the latency, the PRIMARY selection (`xclip`) and the active window
title (`xdotool`) in one line:

```
S1HIT t0=… t1=… latency=…ms primary="…" title="…"
```

## Outcome
- Tray, PRIMARY selection and window title: **work**.
- `hotkey_manager` / `XGrabKey` event delivery: **does not work** on this
  system → superseded by the `xinput test-xi2 --root` listener implemented in
  the app (`secondbrain/lib/platform/desktop/x11_hotkey.dart`).

## How to run
```bash
flutter run -d linux          # needs the Linux desktop build deps
```
Then press `Ctrl+Alt+J` in any window and watch the log.

> This spike is kept for reference only. The default counter widget test that
> came with `flutter create` was removed — it referenced a widget that never
> existed in this prototype.
