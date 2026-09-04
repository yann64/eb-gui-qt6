' Idiomatic layer: eb-gui's Application/Window contract, implemented over
' eb-qt6.
'
' `GuiApplication.handle`/`GuiWindow.handle` are the exact same
' QApplication*/QMainWindow* eb-qt6's own Application/MainWindow TYPEs
' wrap - this adapter just copies that field across the two TYPE shapes
' at each call (a cheap 8-byte pointer copy, not a real conversion),
' never allocating a second handle of its own.
'
' Needs NO native code at all (unlike eb-gui-gtk4) - eb-qt6's own
' MainWindowSetCloseCallback already matches eb-gui's contract shape and
' polarity exactly (`FUNCTION(userData AS ANY PTR) AS INTEGER`, nonzero
' = allow), so GuiWindowSetCloseCallback below is a direct pass-through.

#include "gui.iface.bas"
#include "qt6.iface.bas"

FUNCTION NewGuiApplication(appId AS ZSTRING) AS GuiApplication
    DIM realApp AS Application
    realApp = NewApplication(appId)
    ' CONFIRMED (via a standalone spike, not assumed - and contrary to
    ' this plan's own original assumption that Qt6 needed manual
    ' window-count bookkeeping): quitOnLastWindowClosed genuinely works
    ' for eb-gui's synchronous construct-then-run style, AS LONG AS the
    ' close happens while ApplicationExec's event loop is actually
    ' running (real user interaction always does) - closing a window
    ' BEFORE ApplicationExec starts does not retroactively trigger it,
    ' but that's not a shape eb-gui's contract ever produces.
    CALL ApplicationSetQuitOnLastWindowClosed(realApp, 1)
    DIM result AS GuiApplication
    result.handle = realApp.handle
    NewGuiApplication = result
END FUNCTION

FUNCTION GuiApplicationRun(app AS GuiApplication) AS INTEGER
    DIM realApp AS Application
    realApp.handle = app.handle
    GuiApplicationRun = ApplicationExec(realApp)
END FUNCTION

SUB GuiApplicationQuit(app AS GuiApplication)
    DIM realApp AS Application
    realApp.handle = app.handle
    CALL ApplicationQuit(realApp)
END SUB

FUNCTION NewGuiWindow(app AS GuiApplication, title AS ZSTRING, width AS INTEGER, height AS INTEGER) AS GuiWindow
    DIM win AS MainWindow
    win = NewMainWindow()
    CALL WidgetSetWindowTitle(win, title)
    CALL WidgetResize(win, width, height)
    DIM result AS GuiWindow
    result.handle = win.handle
    NewGuiWindow = result
END FUNCTION

SUB GuiWindowSetTitle(win AS GuiWindow, title AS ZSTRING)
    DIM realWidget AS QtWidget
    realWidget.handle = win.handle
    CALL WidgetSetWindowTitle(realWidget, title)
END SUB

SUB GuiWindowShow(win AS GuiWindow)
    DIM realWidget AS QtWidget
    realWidget.handle = win.handle
    CALL WidgetShow(realWidget)
END SUB

SUB GuiWindowHide(win AS GuiWindow)
    DIM realWidget AS QtWidget
    realWidget.handle = win.handle
    CALL WidgetSetVisible(realWidget, 0)
END SUB

SUB GuiWindowSetEnabled(win AS GuiWindow, enabled AS INTEGER)
    DIM realWidget AS QtWidget
    realWidget.handle = win.handle
    CALL WidgetSetEnabled(realWidget, enabled)
END SUB

FUNCTION GuiWindowIsEnabled(win AS GuiWindow) AS INTEGER
    DIM realWidget AS QtWidget
    realWidget.handle = win.handle
    GuiWindowIsEnabled = WidgetIsEnabled(realWidget)
END FUNCTION

''' Always 1 on this backend - real Qt genuinely supports programmatic
''' window positioning (unlike GTK4, which removed it upstream).
FUNCTION GuiWindowCanMove() AS INTEGER
    GuiWindowCanMove = 1
END FUNCTION

SUB GuiWindowMove(win AS GuiWindow, x AS INTEGER, y AS INTEGER)
    DIM realWidget AS QtWidget
    realWidget.handle = win.handle
    CALL WidgetMove(realWidget, x, y)
END SUB

SUB GuiWindowResize(win AS GuiWindow, width AS INTEGER, height AS INTEGER)
    DIM realWidget AS QtWidget
    realWidget.handle = win.handle
    CALL WidgetResize(realWidget, width, height)
END SUB

''' Real Qt window modality has no visible effect without a parent
''' association set first (the same precondition GTK4's own
''' gtk_window_set_modal has) - see WidgetSetParentWindow.
SUB GuiWindowSetModal(win AS GuiWindow, parent AS GuiWindow)
    DIM realWidget AS QtWidget
    realWidget.handle = win.handle
    DIM realParent AS QtWidget
    realParent.handle = parent.handle
    CALL WidgetSetParentWindow(realWidget, realParent)
    CALL WidgetSetModal(realWidget, QtWindowModal)
END SUB

SUB GuiWindowClearModal(win AS GuiWindow)
    DIM realWidget AS QtWidget
    realWidget.handle = win.handle
    CALL WidgetSetModal(realWidget, QtNonModal)
END SUB

''' Direct pass-through - see this file's own top comment on why no
''' native trampoline is needed here (unlike eb-gui-gtk4).
SUB GuiWindowSetCloseCallback(win AS GuiWindow, handler AS ANY PTR, userData AS ANY PTR)
    DIM realWin AS MainWindow
    realWin.handle = win.handle
    CALL MainWindowSetCloseCallback(realWin, handler, userData)
END SUB

''' Only meaningful for a window never Run/shown - see eb-gui's own
''' README "Ownership and the quit model".
SUB GuiWindowDestroy(win AS GuiWindow)
    DIM realWidget AS QtWidget
    realWidget.handle = win.handle
    CALL WidgetDestroy(realWidget)
END SUB
