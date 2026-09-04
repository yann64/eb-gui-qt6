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
' top comment).
DIM vetoWin AS GuiWindow
vetoWin = NewGuiWindow(app, "veto", 200, 100)
CALL GuiWindowSetCloseCallback(vetoWin, @OnVetoClose, 0)
CALL GuiWindowShow(vetoWin)
PRINT "close callback connected without crashing"

' GuiApplicationQuit/GuiApplicationRun are each a one-line pass-through
' to eb-qt6's own already-verified ApplicationQuit/ApplicationExec, not
' tested here: real Qt's QCoreApplication::quit() called BEFORE exec()
' starts has no effect at all (confirmed by direct reproduction - a
' hang, unlike GTK4's own tolerance of the same ordering, just with a
' noisy assertion) - triggering it for real needs the event loop
' already running (a QTimer, or real user interaction), a shape outside
' what a plain top-to-bottom headless script can safely exercise.
PRINT "verify complete"
