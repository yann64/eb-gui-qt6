' Headless(-ish) verification of the eb-gui contract implemented over
' eb-qt6 - every check is a direct function call + printed result, not
' a synthetic mouse/keyboard event (matches eb-gui-gtk4's own
' examples/verify discipline). Only TYPEs carry through an adapter's
' generated interface automatically (a side effect of --lib's interface
' generator copying every visible plain-data TYPE) - FUNCTIONs don't,
' so this can't reach past the contract to eb-qt6's own WidgetClose the
' way a same-package test could; the close-callback's actual firing
' behavior is already verified directly at the eb-qt6 layer
' (window_lifecycle_verify.bas).

#include "gui-qt6.iface.bas"

FUNCTION OnVetoClose(userData AS ANY PTR) AS INTEGER
    PRINT "close callback fired (veto)"
    OnVetoClose = 0
END FUNCTION

DIM app AS GuiApplication

SUB OnTimeout(userData AS ANY PTR)
    PRINT "timer fired - quitting"
    CALL GuiApplicationQuit(app)
END SUB
app = NewGuiApplication("eb-gui-qt6-verify")

' 1. Enable/disable round trip.
DIM win AS GuiWindow
win = NewGuiWindow(app, "verify", 300, 200)
PRINT "enabled by default: ", GuiWindowIsEnabled(win)
CALL GuiWindowSetEnabled(win, 0)
PRINT "enabled after SetEnabled(0): ", GuiWindowIsEnabled(win)
CALL GuiWindowSetEnabled(win, 1)
PRINT "enabled after SetEnabled(1): ", GuiWindowIsEnabled(win)

' 2. Modal, and real move/resize (this backend genuinely supports it -
' GuiWindowCanMove() should read 1, unlike eb-gui-gtk4's own 0).
DIM childWin AS GuiWindow
childWin = NewGuiWindow(app, "child", 200, 100)
CALL GuiWindowSetModal(childWin, win)
CALL GuiWindowClearModal(childWin)
PRINT "modal set/clear did not crash"
PRINT "can move on this backend: ", GuiWindowCanMove()
CALL GuiWindowMove(childWin, 15, 15)
PRINT "move did not crash"

' 3. Close callback wiring - no crash is the bar (see this file's own
' top comment). Deliberately NOT shown: a VISIBLE window with a
' permanently-vetoing close callback would also block step 5's
' GuiApplicationQuit below - CONFIRMED (not assumed) real Qt behavior,
' not a bug: QCoreApplication::quit() implicitly tries to close every
' *visible* top-level window first, and a vetoed close aborts the quit
' too. GTK4's own ApplicationQuit has no such negotiation - it always
' stops the loop unconditionally regardless of any window's
' close-callback state. A real, confirmed cross-backend asymmetry.
DIM vetoWin AS GuiWindow
vetoWin = NewGuiWindow(app, "veto", 200, 100)
CALL GuiWindowSetCloseCallback(vetoWin, @OnVetoClose, 0)
PRINT "close callback connected without crashing"

' 4. StatusBar - real QStatusBar has no message getter either, so "did
' not crash" is the bar here too (both adapters' own StatusBar support
' is symmetric in this respect).
DIM sbWin AS GuiWindow
sbWin = NewGuiWindow(app, "statusbar", 200, 100)
DIM sb AS GuiStatusBar
sb = GuiWindowStatusBar(sbWin)
CALL GuiStatusBarShowMessage(sb, "hello")
CALL GuiStatusBarClear(sb)
PRINT "status bar show/clear did not crash"

' 5. GuiTimer, and (via its own callback) GuiApplicationQuit stopping
' GuiApplicationRun - this finally closes the gap this file's own
' comment used to flag: GuiTimer is now part of the contract itself, so
' a real running-loop quit (the only shape that works on this backend -
' quit-before-run just hangs, see eb-gui-gtk4's own README for the
' opposite-but-also-real asymmetry) is testable without reaching past
' the contract into eb-qt6 directly.
DIM t AS GuiTimer
t = NewGuiTimer(win)
CALL GuiTimerSetInterval(t, 200)
CALL GuiTimerSetSingleShot(t, 1)
PRINT "timer active before start: ", GuiTimerIsActive(t)
CALL GuiTimerConnectTimeout(t, @OnTimeout, 0)
CALL GuiTimerStart(t)
PRINT "timer active after start: ", GuiTimerIsActive(t)

CALL GuiApplicationRun(app)
PRINT "GuiApplicationRun returned - timer-driven quit worked"
CALL GuiTimerDestroy(t)
