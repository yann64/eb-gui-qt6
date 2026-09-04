' eb-gui-qt6's own smoke test - the exact same shape of program as
' eb-gui-gtk4's own hello_window.bas, differing only in the #include
' target and the two string literals below: no Qt6-specific idiom at
' all, just the universal contract. This near-identical pair is this
' project's own cross-backend proof - both screenshot-verified live,
' producing the same behavior through the same call sequence.
'
' Only the adapter's own interface is needed - it already carries a
' full copy of GuiApplication/GuiWindow (it #includes gui.iface.bas
' itself), so #including gui.iface.bas here too would redeclare both
' TYPEs.
#include "gui-qt6.iface.bas"

DIM app AS GuiApplication
app = NewGuiApplication("eb-gui-qt6-hellowindow")

DIM win AS GuiWindow
win = NewGuiWindow(app, "eb-gui-qt6 Hello", 320, 200)
CALL GuiWindowShow(win)

CALL GuiApplicationRun(app)
PRINT "GuiApplicationRun returned"
