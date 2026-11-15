# Lights Bridge setup

Do these once. It takes about 20 minutes.

## (a) Hardware

- Use any "class-compliant" USB-MIDI cable (it works without installing drivers).
- **Roland UM-ONE:** set its small slide switch to **TAB**, not COMP. On COMP it needs Roland's driver
  and the Mac won't list it, so the Lights dot stays red. (If you change the switch, unplug and
  replug the cable.)
- Plug the USB end into the Mac.
- Plug the cable's **OUT** plug into the board's **MIDI IN** socket. (Out of the Mac goes into the board.)

## (b) Install the app

1. Download the app (no GitHub account needed). This link always gets the newest version:
   <https://github.com/sethburt6/lights-bridge/releases/latest/download/LightsBridge.dmg>
   Or have someone AirDrop the file to you.
2. Open the downloaded **LightsBridge.dmg**. A window appears with **Lights Bridge** and an
   **Applications** folder.
3. Drag **Lights Bridge** onto the **Applications** folder in that window.
4. Eject the "Lights Bridge" disk (click the eject button next to it in Finder).
5. Open **Lights Bridge** from your Applications folder.
6. macOS will block it the first time. Open **System Settings > Privacy & Security**, scroll down, and
   click **Open Anyway**. This is needed only once.
7. A colored dot and the word "Lights" appear next to the clock. Green means working, yellow means the
   board cable is found but nothing has come from ProPresenter yet, and red means the board cable isn't found. From now on the app starts by itself when you log in, and restarts itself if it ever quits.

## (c) Set up the board

These menu steps come from ETC's Express manual, which shares its MIDI features with the Expression.
Check them on your board.

1. On the board press **Setup > 6 > Enter > 1 > Enter**, then type the MIDI channel.
   It must match **MIDI channel** in Lights Bridge: click the Lights dot, choose **Settings...**, and
   pick the same channel under **Board** (default 1).
2. Record each look as a cue (Cue 1 Walk-in, Cue 2 Worship, and so on).
3. Bring the submasters down. The highest level wins, so a raised submaster can hide a cue.

## (d) ProPresenter

Every lighting look is a **ProPresenter macro**, so all of them are listed in the **Macros** tab and
slides never hold raw MIDI. To change what a look does, edit its macro once and every slide that uses
it follows. (Menu names below are from ProPresenter 7; newer versions may word them slightly
differently.)

1. **Add the MIDI device (once):** in ProPresenter's Settings, open **Devices** (or Connections /
   Communications), click **+**, add a **MIDI** device, and choose **Lights Bridge** as its output. Name
   it "Lights". Do not choose the USB cable itself; ProPresenter talks to Lights Bridge, and Lights
   Bridge talks to the cable.
2. **Make one macro per look:** open the **Macros** tab and create a macro for each board cue. Name it
   `Lights NN - Look`, so the cue number is in the name and the list sorts in cue order:

   | Macro name           | Its one action                          |
   |----------------------|-----------------------------------------|
   | `Lights 01 - Walk-in` | Communication > Lights > Note On, note 1 |
   | `Lights 02 - Worship` | Communication > Lights > Note On, note 2 |
   | `Lights 03 - Sermon`  | Communication > Lights > Note On, note 3 |

   - Note = the board cue number. Velocity = anything above 0 (100 is fine). Channel doesn't matter.
   - Note 0 means "GO next cue" on the board, if you ever want a `Lights - Next` macro.
   - Give the macros one color (for example amber) so they stand out from other macros.
3. **Use them on slides:** add the macro to the slide where the look should change (right-click the
   slide > Macro, or drag the macro onto the slide). You can also click a macro in the Macros tab to
   run that look by hand.

## (e) First test

Click the Lights dot and choose **Send Test Cue...**, type 1, and check that the board runs cue 1.
You can also use the **Test** section of **Settings...**.

If the board runs the wrong cue number (one too high or too low), click the Lights dot, choose
**Settings...**, and change **Advanced > Cue number offset** (for example +1 or -1). The change takes
effect right away.

## (f) Updating

1. Hold the **Option** key, click the Lights dot, and choose **Quit**.
2. Open the new **LightsBridge.dmg** (same link as above) and drag **Lights Bridge** onto
   **Applications**. Choose **Replace** when asked.
3. Eject the disk and open Lights Bridge again. Your settings are kept.

## (g) Uninstall

In Terminal:

```
launchctl bootout gui/$(id -u)/io.github.sethburt6.lightsbridge; rm ~/Library/LaunchAgents/io.github.sethburt6.lightsbridge.plist
```

Then delete Lights Bridge from Applications.

## (h) Logs

`~/Library/Logs/LightsBridge.log` (or click the Lights dot and choose **Show Log**). Every cue sent is recorded there.
