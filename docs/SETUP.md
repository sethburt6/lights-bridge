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

Every lighting look is a **ProPresenter macro**. All of them are listed together in the Macros area,
slides never hold raw MIDI, and to change what a look does you edit its macro once and every slide
that uses it follows.

Menu names below come from Renewed Vision's own guides for ProPresenter 7 and later. Newer versions may
word a menu slightly differently; the official articles linked in each step have pictures of each screen.

### d1. Connect ProPresenter to Lights Bridge (once per Mac)

Lights Bridge must be running (dot next to the clock) before you start.

1. Open ProPresenter's settings: **ProPresenter > Settings** (or **Preferences**), or press **Cmd+,**.
2. Click the **Devices** tab.
3. Click the **+** button at the bottom left and choose **MIDI**.
4. Click the device's **gear icon** to set it up for **output**. For **Destination**, choose
   **Lights Bridge**. Do not choose the USB cable (for example UM-ONE): ProPresenter talks to Lights
   Bridge, and Lights Bridge talks to the cable.
5. Name the device **Lights**.
6. Turn on **auto reconnect**, so ProPresenter finds Lights Bridge again by itself after either app or
   the Mac restarts.

If Lights Bridge is not in the list, check the dot next to the clock, then quit and reopen ProPresenter.

Official guide: [Communication Devices in ProPresenter](https://support.renewedvision.com/hc/en-us/articles/360058141114-Communication-Devices-in-ProPresenter-7)

### d2. Make one macro for each lighting look

First decide your looks and their cue numbers on the board, for example:

| Macro name                   | Board cue | MIDI note |
|------------------------------|-----------|-----------|
| `Lights 01 - Walk-in`        | 1         | 1         |
| `Lights 02 - Worship`        | 2         | 2         |
| `Lights 03 - Sermon`         | 3         | 3         |
| `Lights 04 - Announcements`  | 4         | 4         |

The note number is always the cue number. Putting the number in the name keeps the macros in cue order.

Then, for each row:

1. Open the Macros area: click the **M** icon in the show controls at the **bottom right** of the
   ProPresenter window.
2. Click the small **+** button to make a new macro.
3. Right-click the new macro and rename it, for example **Lights 02 - Worship**. While you are there,
   give it a color (amber works well) so lighting macros stand out from other macros.
4. Right-click the macro again and choose **Add Action > Communication > MIDI > MIDI Note On**. If
   ProPresenter asks which device, choose **Lights**.
5. In the pop-up:
   - **Note:** the cue number (2 for Worship).
   - **Velocity** (some versions say **Intensity**): **1**. Any number from 1 to 127 works; 0 does not.
     Use the same number in every macro.
   - **Channel:** leave as it is. Lights Bridge accepts any channel.
6. Close the pop-up.

Faster way to make the rest: right-click a finished macro, **Duplicate** it, then rename the copy and
change only its **Note**.

Each lighting macro has exactly **one** action. If a look also needs other things (a background, a
clear), make a separate macro for those, so the lighting macros stay simple.

Official guide: [Using Macros in ProPresenter](https://support.renewedvision.com/hc/en-us/articles/4402663090323-Using-Macros-in-ProPresenter)
and [MIDI Note On actions](https://support.renewedvision.com/hc/en-us/articles/1500000020301)

### d3. Test each macro

Click a macro in the Macros area. Its action runs right away, without changing slides.

- The dot next to the clock turns **green**.
- Click the dot: **Last cue** shows the macro's number.
- With the board connected, the board runs that cue.

If the dot stays yellow, ProPresenter is not sending: re-check step d1, then the macro's action.

### d4. Put the macros on slides

Add a lighting macro only to the slide **where the look changes**. The lights stay on that cue until
another slide with a lighting macro comes up, so most slides need nothing.

For each of those slides:

1. Open the presentation (song, sermon, announcements) in the **Library**.
2. **Right-click the slide** where the look should change.
3. Choose **Add Action > Add Macro** (shown as **Add Action > Macro** in some versions), then pick the
   lighting macro, for example **Lights 02 - Worship**.
4. The slide now shows a small macro label or icon.

Shortcut: drag the macro from the Macros area straight onto the slide. (Do not hold Option while
dragging; that copies the macro's MIDI action onto the slide instead of the macro itself, and then
editing the macro later will not update that slide.)

Typical placement:

| Slide                                 | Macro                       |
|---------------------------------------|-----------------------------|
| Pre-service loop / welcome slide      | `Lights 01 - Walk-in`       |
| First slide of the first song         | `Lights 02 - Worship`       |
| Sermon title slide                    | `Lights 03 - Sermon`        |
| First announcement slide              | `Lights 04 - Announcements` |

To remove one: right-click the slide, find the macro under its actions, and remove it.

### d5. Run through once

Click through the whole presentation from the first slide. Each time a slide with a lighting macro
comes up, **Last cue** in the Lights Bridge menu should change to that macro's number. Do this once
after any change to the service order.

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

## (i) Settings reference

Click the Lights dot and choose **Settings...**. Changes save the moment you make them; there is no Save
button. The defaults are right for almost everyone.

**Status** (read-only)

- **Board cable:** green "Connected" with the cable's name, or red "Not found".
- **From ProPresenter:** the last note ProPresenter sent, and when. If a lighting slide did nothing and
  this did not change, the problem is on the ProPresenter side.
- **Last cue sent:** the last cue sent to the board. If this changed but the board did nothing, the
  problem is the cable or the board.

**Board**

- **Send to** (default **Automatic (only cable)**): uses whichever single MIDI cable is plugged in, so a
  replacement cable works with no change. Pick a specific device only if two MIDI devices are plugged in.
- **MIDI channel** (default **1**): must match the board's MIDI channel (see section c).

**Reliability** (all on by default; leave them on)

- **Start when the Mac logs in:** Lights Bridge is ready before ProPresenter opens.
- **Restart automatically if it quits or crashes:** it comes back within about 10 seconds.
- **Hide Quit unless the Option key is held:** prevents quitting it by accident. To quit, hold Option
  and click the dot.
- **Cable reconnect: Always on.** It finds the cable again after it is unplugged; there is no switch.

**Advanced**

- **Cue number offset** (default **0**): only if the board runs a different cue than the slide asks for
  (see section e).

**Test**

- **Cue number + Send Test Cue:** sends that cue straight to the board, without ProPresenter.
