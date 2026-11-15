# Lights didn't change?

Look at the dot and the word "Lights" next to the clock.

- **Red dot:** the USB MIDI cable isn't found. Unplug it and plug it back in, or
  try another USB port.
- **No dot at all:** open **Lights Bridge** from the Applications folder.
- **Yellow dot, and it stays yellow after you change slides:** the cable is found, but ProPresenter isn't
  sending anything. Check that the slide has a MIDI action and that "Lights Bridge" is turned on in
  ProPresenter's Settings > Devices > MIDI. To check, click the dot, choose **Settings...**, and look at
  **From ProPresenter**. If it says "Nothing received yet", ProPresenter isn't sending.
- **Green dot, but the board doesn't react:**
  - Is the board's MIDI channel the same as **MIDI channel** in Lights Bridge Settings?
  - Is the cable plugged into the board's MIDI **IN** (not OUT)?
  - Is the board in a mode that blocks MIDI?
  - Click the dot, choose **Send Test Cue...**, type 1, and watch the board.

**Emergency:** run the lights by hand on the board, like before. Nothing about the board was changed.
