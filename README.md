# 🔥 Ember

Keeps your Mac awake, even with the lid closed, toggled with one click from the menu bar.

### [⬇ Download Ember for Mac](https://github.com/AnonUser1035/ember/releases/latest/download/Ember.dmg)

Requires macOS 13+.

## Install

1. Open the DMG and drag **Ember** into **Applications**.
2. Launch it, click the flame in your menu bar, and click **Keep Awake**.
3. Enter your admin password when prompted. This happens on every toggle, since disabling sleep requires root and Ember deliberately doesn't install any background process to get around that.

If Gatekeeper blocks the first launch, right-click the app and choose **Open**.

## Safety & security

- Disabling sleep means your Mac won't sleep at all, even on battery, until turned back off. Ember restores normal sleep when you quit, includes a low-battery auto-off guard, and catches a lingering flag on next launch if something went wrong.
- Ember installs nothing privileged, runs no background processes, and makes no network connections. The only elevated action is the admin password prompt each time you toggle sleep, that's it.

## License

MIT, see [LICENSE](LICENSE).
