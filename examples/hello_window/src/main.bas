' eb-gui-qt6's own smoke test - the exact same shape of program as
' eb-gui-gtk4's own hello_window (and, byte-for-byte, the shared
' cross-backend smoke test in eb-gui's own repo): no Qt6-specific idiom
' at all, just the universal contract.

#include "gui-qt6.iface.bas"

DIM app AS GuiApplication
app = NewGuiApplication("eb-gui-qt6-hellowindow")

DIM win AS GuiWindow
win = NewGuiWindow(app, "eb-gui-qt6 Hello", 320, 200)
CALL GuiWindowShow(win)

CALL GuiApplicationRun(app)
PRINT "GuiApplicationRun returned"
