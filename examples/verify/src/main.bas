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

DIM triggerCount AS INTEGER

SUB OnActionTriggered(userData AS ANY PTR)
    triggerCount = triggerCount + 1
END SUB

SUB OnWidgetButtonClicked(userData AS ANY PTR)
END SUB

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

' 6. Menu/ToolBar/Action - a programmatic GuiActionTrigger should
' genuinely reach a connected GuiActionConnectTriggered handler for
' both a menu action and a tool bar action.
DIM mbar AS GuiMenuBar
mbar = GuiWindowMenuBar(sbWin)
DIM fileMenu AS GuiMenu
fileMenu = GuiMenuBarAddMenu(mbar, "File")
DIM menuAction AS GuiAction
menuAction = GuiMenuAddAction(fileMenu, "Test")
CALL GuiActionConnectTriggered(menuAction, @OnActionTriggered, 0)
PRINT "before menu action trigger: ", triggerCount
CALL GuiActionTrigger(menuAction)
PRINT "after menu action trigger: ", triggerCount

PRINT "action enabled by default: ", GuiActionIsEnabled(menuAction)
CALL GuiActionSetEnabled(menuAction, 0)
PRINT "action enabled after disable: ", GuiActionIsEnabled(menuAction)
CALL GuiActionSetEnabled(menuAction, 1)
PRINT "action enabled after re-enable: ", GuiActionIsEnabled(menuAction)

DIM tbar1 AS GuiToolBar
tbar1 = GuiWindowToolBar(sbWin)
DIM tbar2 AS GuiToolBar
tbar2 = GuiWindowToolBar(sbWin)
PRINT "GuiWindowToolBar returns the same handle both times: ", (tbar1.handle = tbar2.handle)

DIM toolAction AS GuiAction
toolAction = GuiToolBarAddAction(tbar1, "Go")
CALL GuiActionConnectTriggered(toolAction, @OnActionTriggered, 0)
CALL GuiActionTrigger(toolAction)
PRINT "after toolbar action trigger: ", triggerCount

' 6. Widget/Layout Round 1 - GuiBox/GuiGrid nesting (a GuiGrid inside a
' GuiBox, via each's own holder-widget mechanism - see eb-gui-qt6's own
' src/lib.bas top comment on EbGuiQt6RecordLayout), GuiEntry text
' round-trip, and GuiWindowSetContent onto the MainWindow's own central
' widget slot (structurally independent of Menu/ToolBar/StatusBar here,
' unlike eb-gui-gtk4/eb-gui-haiku's shared content area).
' GuiButtonConnectClicked itself is only confirmed "connects without
' crashing" - real Qt's own QAbstractButton has no bound programmatic
' "click()" primitive in this package either, matching eb-gui-gtk4's
' identical gap for the same underlying reason (real interactive
' clicking isn't headlessly driveable).
DIM widgetsBox AS GuiBox
widgetsBox = NewGuiBox(1, 4)

DIM formGrid AS GuiGrid
formGrid = NewGuiGrid()
DIM nameLbl AS GuiLabel
nameLbl = NewGuiLabel("Name:")
CALL GuiGridAttach(formGrid, nameLbl.handle, 0, 0, 1, 1)
DIM nameEntry AS GuiEntry
nameEntry = NewGuiEntry("")
CALL GuiGridAttach(formGrid, nameEntry.handle, 1, 0, 1, 1)
CALL GuiBoxAddChild(widgetsBox, formGrid.handle)

CALL GuiEntrySetText(nameEntry, "hello")
PRINT "entry text round-trip: ", GuiEntryGetText(nameEntry)

DIM goBtn AS GuiButton
goBtn = NewGuiButton("Go")
CALL GuiButtonConnectClicked(goBtn, @OnWidgetButtonClicked, 0)
CALL GuiBoxAddChild(widgetsBox, goBtn.handle)

CALL GuiWindowSetContent(sbWin, widgetsBox.handle)
PRINT "GuiWindowSetContent (central widget) did not crash"

' 6. Round 2: per-child constraints - expand/align/weight. Real Qt
' behavior isn't introspectable headlessly (it's a layout allocation-
' time effect) - this confirms the calls don't crash, resolve through
' the LayoutOf association table correctly, and compose with a nested
' Grid.
DIM constraintsBox AS GuiBox
constraintsBox = NewGuiBox(0, 4)
DIM growBtn AS GuiButton
growBtn = NewGuiButton("Grows")
CALL GuiBoxAddChildEx(constraintsBox, growBtn.handle, 1.0, GUI_ALIGN_FILL, GUI_ALIGN_CENTER)
DIM fixedBtn AS GuiButton
fixedBtn = NewGuiButton("Fixed")
CALL GuiBoxAddChildEx(constraintsBox, fixedBtn.handle, 0.0, GUI_ALIGN_END, GUI_ALIGN_START)

DIM constraintsGrid AS GuiGrid
constraintsGrid = NewGuiGrid()
DIM gridLbl AS GuiLabel
gridLbl = NewGuiLabel("Grid cell")
CALL GuiGridAttachEx(constraintsGrid, gridLbl.handle, 0, 0, 1, 1, GUI_ALIGN_CENTER, GUI_ALIGN_CENTER)
CALL GuiGridSetColumnWeight(constraintsGrid, 0, 1.0)
CALL GuiGridSetRowWeight(constraintsGrid, 0, 1.0)
CALL GuiBoxAddChild(constraintsBox, constraintsGrid.handle)
CALL GuiBoxAddChild(widgetsBox, constraintsBox.handle)
PRINT "Round 2 constraints (GuiBoxAddChildEx/GuiGridAttachEx/GuiGridSetColumnWeight/SetRowWeight) ran without crashing"

' 7. Round 3: explicit min/max size - both real on this backend.
CALL GuiWidgetSetMinSize(fixedBtn.handle, 200, 40)
CALL GuiWidgetSetMaxSize(fixedBtn.handle, 300, 60)
PRINT "Round 3 min/max size (GuiWidgetSetMinSize/SetMaxSize) ran without crashing"

' 8. Round 4: CheckBox/RadioButton/ComboBox.
DIM cb AS GuiCheckBox
cb = NewGuiCheckBox("Enable feature")
PRINT "checkbox initial: ", GuiCheckBoxIsChecked(cb)
CALL GuiCheckBoxSetChecked(cb, 1)
PRINT "checkbox after set: ", GuiCheckBoxIsChecked(cb)

DIM checkboxToggleCount AS INTEGER
checkboxToggleCount = 0
SUB OnCheckBoxToggled(userData AS ANY PTR)
    checkboxToggleCount = checkboxToggleCount + 1
END SUB
CALL GuiCheckBoxConnectToggled(cb, @OnCheckBoxToggled, 0)
CALL GuiCheckBoxSetChecked(cb, 0)
PRINT "checkbox toggle count after programmatic uncheck: ", checkboxToggleCount

DIM r1 AS GuiRadioButton
r1 = NewGuiRadioButton("Option A")
DIM r2 AS GuiRadioButton
r2 = NewGuiRadioButton("Option B")
CALL GuiRadioButtonSetGroup(r2, r1)
CALL GuiRadioButtonSetChecked(r1, 1)
PRINT "r1: ", GuiRadioButtonIsChecked(r1)
PRINT "r2 (grouped, expect 0): ", GuiRadioButtonIsChecked(r2)
CALL GuiRadioButtonSetChecked(r2, 1)
PRINT "r1 (grouped, expect 0): ", GuiRadioButtonIsChecked(r1)
PRINT "r2: ", GuiRadioButtonIsChecked(r2)

DIM combo AS GuiComboBox
combo = NewGuiComboBox()
CALL GuiComboBoxAddItem(combo, "First")
CALL GuiComboBoxAddItem(combo, "Second")
CALL GuiComboBoxSetSelectedIndex(combo, 1)
PRINT "combo selected index: ", GuiComboBoxGetSelectedIndex(combo)
PRINT "combo selected text: ", GuiComboBoxGetSelectedText(combo)

DIM comboChangedCount AS INTEGER
comboChangedCount = 0
SUB OnComboChanged(userData AS ANY PTR)
    comboChangedCount = comboChangedCount + 1
END SUB
CALL GuiComboBoxConnectChanged(combo, @OnComboChanged, 0)
CALL GuiComboBoxSetSelectedIndex(combo, 0)
PRINT "combo changed count: ", comboChangedCount
PRINT "Round 4 widgets (CheckBox/RadioButton/ComboBox) ran without crashing"

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
