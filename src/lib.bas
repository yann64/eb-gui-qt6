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

''' Direct pass-through - real QMainWindow::statusBar() already
''' auto-creates and owns its own status bar per window, exactly
''' matching this contract function's own shape.
FUNCTION GuiWindowStatusBar(win AS GuiWindow) AS GuiStatusBar
    DIM realWin AS MainWindow
    realWin.handle = win.handle
    DIM sb AS StatusBar
    sb = MainWindowStatusBar(realWin)
    DIM result AS GuiStatusBar
    result.handle = sb.handle
    GuiWindowStatusBar = result
END FUNCTION

SUB GuiStatusBarShowMessage(sb AS GuiStatusBar, text AS ZSTRING)
    DIM realSb AS StatusBar
    realSb.handle = sb.handle
    CALL StatusBarShowMessage(realSb, text, 0)
END SUB

''' Real QStatusBar has no explicit "clear" - showing an empty message
''' achieves the same visible effect.
SUB GuiStatusBarClear(sb AS GuiStatusBar)
    DIM realSb AS StatusBar
    realSb.handle = sb.handle
    CALL StatusBarShowMessage(realSb, "", 0)
END SUB

''' `parent` is required here (unlike eb-gui-gtk4, where it's accepted
''' but ignored) - real QTimer must be parented or it leaks, matching
''' this package's own NewQTimer requirement.
FUNCTION NewGuiTimer(parent AS GuiWindow) AS GuiTimer
    DIM realParent AS QtWidget
    realParent.handle = parent.handle
    DIM t AS QTimer
    t = NewQTimer(realParent)
    DIM result AS GuiTimer
    result.handle = t.handle
    NewGuiTimer = result
END FUNCTION

SUB GuiTimerSetInterval(t AS GuiTimer, milliseconds AS INTEGER)
    DIM realT AS QTimer
    realT.handle = t.handle
    CALL QTimerSetInterval(realT, milliseconds)
END SUB

SUB GuiTimerSetSingleShot(t AS GuiTimer, singleShot AS INTEGER)
    DIM realT AS QTimer
    realT.handle = t.handle
    CALL QTimerSetSingleShot(realT, singleShot)
END SUB

SUB GuiTimerConnectTimeout(t AS GuiTimer, handler AS ANY PTR, userData AS ANY PTR)
    DIM realT AS QTimer
    realT.handle = t.handle
    CALL QTimerConnectTimeout(realT, handler, userData)
END SUB

SUB GuiTimerStart(t AS GuiTimer)
    DIM realT AS QTimer
    realT.handle = t.handle
    CALL QTimerStart(realT)
END SUB

SUB GuiTimerStop(t AS GuiTimer)
    DIM realT AS QTimer
    realT.handle = t.handle
    CALL QTimerStop(realT)
END SUB

FUNCTION GuiTimerIsActive(t AS GuiTimer) AS INTEGER
    DIM realT AS QTimer
    realT.handle = t.handle
    GuiTimerIsActive = QTimerIsActive(realT)
END FUNCTION

''' A documented no-op on this backend - real Qt destroys a QTimer
''' automatically when its parent window is destroyed (this package's
''' own timer.bas has no manual destroy/free function at all). Present
''' only for signature parity with eb-gui-gtk4, where it's meaningful.
SUB GuiTimerDestroy(t AS GuiTimer)
END SUB

''' Direct pass-through - real QMainWindow::menuBar() already
''' auto-creates and owns its own menu bar per window, exactly matching
''' this contract function's own shape.
FUNCTION GuiWindowMenuBar(win AS GuiWindow) AS GuiMenuBar
    DIM realWin AS MainWindow
    realWin.handle = win.handle
    DIM bar AS MenuBar
    bar = MainWindowMenuBar(realWin)
    DIM result AS GuiMenuBar
    result.handle = bar.handle
    GuiWindowMenuBar = result
END FUNCTION

FUNCTION GuiMenuBarAddMenu(bar AS GuiMenuBar, title AS ZSTRING) AS GuiMenu
    DIM realBar AS MenuBar
    realBar.handle = bar.handle
    DIM m AS Menu
    m = MenuBarAddMenu(realBar, title)
    DIM result AS GuiMenu
    result.handle = m.handle
    GuiMenuBarAddMenu = result
END FUNCTION

''' Direct pass-through - real QAction is already created fresh per
''' call by this package's own MenuAddAction, exactly matching this
''' contract function's own "create fresh per call" shape (see eb-gui's
''' own README on why the contract follows Qt6's shape rather than
''' GTK4's richer, action-sharing model).
FUNCTION GuiMenuAddAction(guiMenu AS GuiMenu, text AS ZSTRING) AS GuiAction
    DIM realMenu AS Menu
    realMenu.handle = guiMenu.handle
    DIM act AS Action
    act = MenuAddAction(realMenu, text)
    DIM result AS GuiAction
    result.handle = act.handle
    GuiMenuAddAction = result
END FUNCTION

SUB GuiActionConnectTriggered(a AS GuiAction, handler AS ANY PTR, userData AS ANY PTR)
    DIM realAction AS Action
    realAction.handle = a.handle
    CALL ActionConnectTriggered(realAction, handler, userData)
END SUB

SUB GuiActionSetEnabled(a AS GuiAction, enabled AS INTEGER)
    DIM realAction AS Action
    realAction.handle = a.handle
    CALL ActionSetEnabled(realAction, enabled)
END SUB

FUNCTION GuiActionIsEnabled(a AS GuiAction) AS INTEGER
    DIM realAction AS Action
    realAction.handle = a.handle
    GuiActionIsEnabled = ActionIsEnabled(realAction)
END FUNCTION

SUB GuiActionTrigger(a AS GuiAction)
    DIM realAction AS Action
    realAction.handle = a.handle
    CALL ActionTrigger(realAction)
END SUB

''' Direct pass-through - MainWindowToolBar (eb-qt6 v0.26.0+) already
''' gives this window a single, auto-created-once tool bar, exactly
''' matching this contract function's own shape.
FUNCTION GuiWindowToolBar(win AS GuiWindow) AS GuiToolBar
    DIM realWin AS MainWindow
    realWin.handle = win.handle
    DIM tb AS ToolBar
    tb = MainWindowToolBar(realWin)
    DIM result AS GuiToolBar
    result.handle = tb.handle
    GuiWindowToolBar = result
END FUNCTION

FUNCTION GuiToolBarAddAction(bar AS GuiToolBar, text AS ZSTRING) AS GuiAction
    DIM realBar AS ToolBar
    realBar.handle = bar.handle
    DIM act AS Action
    act = ToolBarAddAction(realBar, text)
    DIM result AS GuiAction
    result.handle = act.handle
    GuiToolBarAddAction = result
END FUNCTION

''' A real QBoxLayout/QGridLayout is NOT a QWidget itself, unlike GTK4's
''' own Box/Grid - so GuiBox/GuiGrid.handle is really a small holder
''' QWidget (created here, with the real layout applied to it via
''' WidgetSetLayout) rather than the layout object directly. The real
''' layout is tracked separately (this table) so GuiBoxAddChild/
''' GuiGridAttach know which one to call AddWidget on - from this
''' contract's own perspective a GuiBox/GuiGrid is still always "a
''' thing you can hand to GuiBoxAddChild/GuiGridAttach/
''' GuiWindowSetContent uniformly," matching eb-gui-gtk4's own direct
''' (holder-free) shape from the outside.
DIM ebGuiQt6LayoutOfKeys(128) AS ANY PTR
DIM ebGuiQt6LayoutOfVals(128) AS ANY PTR
DIM ebGuiQt6LayoutOfCount AS INTEGER

SUB EbGuiQt6RecordLayout(holderHandle AS ANY PTR, layoutHandle AS ANY PTR)
    ebGuiQt6LayoutOfKeys(ebGuiQt6LayoutOfCount) = holderHandle
    ebGuiQt6LayoutOfVals(ebGuiQt6LayoutOfCount) = layoutHandle
    ebGuiQt6LayoutOfCount = ebGuiQt6LayoutOfCount + 1
END SUB

FUNCTION EbGuiQt6LayoutOf(holderHandle AS ANY PTR) AS ANY PTR
    DIM i AS INTEGER
    FOR i = 0 TO ebGuiQt6LayoutOfCount - 1
        IF ebGuiQt6LayoutOfKeys(i) = holderHandle THEN
            EbGuiQt6LayoutOf = ebGuiQt6LayoutOfVals(i)
            EXIT FUNCTION
        END IF
    NEXT i
    EbGuiQt6LayoutOf = 0
END FUNCTION

FUNCTION NewGuiButton(text AS ZSTRING) AS GuiButton
    DIM realBtn AS Button
    realBtn = NewButton(text)
    DIM result AS GuiButton
    result.handle = realBtn.handle
    NewGuiButton = result
END FUNCTION

SUB GuiButtonSetText(b AS GuiButton, text AS ZSTRING)
    DIM realBtn AS Button
    realBtn.handle = b.handle
    CALL ButtonSetText(realBtn, text)
END SUB

''' Real Qt returns a freshly heap-allocated buffer on every call
''' (unlike GTK4/Haiku's borrowed, long-lived storage) - intentionally
''' not freed here, since eb-gui's own contract has no matching free
''' function for this return value. A real, documented, minor per-call
''' leak, not an oversight.
FUNCTION GuiButtonGetText(b AS GuiButton) AS ZSTRING
    DIM realBtn AS Button
    realBtn.handle = b.handle
    DIM raw AS ANY PTR
    raw = ButtonGetText(realBtn)
    DIM z AS ZSTRING
    z = raw
    GuiButtonGetText = z
END FUNCTION

SUB GuiButtonConnectClicked(b AS GuiButton, handler AS ANY PTR, userData AS ANY PTR)
    DIM realBtn AS Button
    realBtn.handle = b.handle
    CALL ButtonConnectClicked(realBtn, handler, userData)
END SUB

FUNCTION NewGuiLabel(text AS ZSTRING) AS GuiLabel
    DIM realLbl AS Label
    realLbl = NewLabel(text)
    DIM result AS GuiLabel
    result.handle = realLbl.handle
    NewGuiLabel = result
END FUNCTION

SUB GuiLabelSetText(l AS GuiLabel, text AS ZSTRING)
    DIM realLbl AS Label
    realLbl.handle = l.handle
    CALL LabelSetText(realLbl, text)
END SUB

FUNCTION NewGuiEntry(text AS ZSTRING) AS GuiEntry
    DIM realEntry AS LineEdit
    realEntry = NewLineEdit(text)
    DIM result AS GuiEntry
    result.handle = realEntry.handle
    NewGuiEntry = result
END FUNCTION

SUB GuiEntrySetText(e AS GuiEntry, text AS ZSTRING)
    DIM realEntry AS LineEdit
    realEntry.handle = e.handle
    CALL LineEditSetText(realEntry, text)
END SUB

''' Same real, documented, minor per-call leak as GuiButtonGetText -
''' Qt's own QLineEdit::text() marshaling returns a fresh buffer each
''' call.
FUNCTION GuiEntryGetText(e AS GuiEntry) AS ZSTRING
    DIM realEntry AS LineEdit
    realEntry.handle = e.handle
    DIM raw AS ANY PTR
    raw = LineEditGetText(realEntry)
    DIM z AS ZSTRING
    z = raw
    GuiEntryGetText = z
END FUNCTION

''' Real Qt's own `textChanged` signal actually passes a borrowed
''' `text AS ZSTRING` as a second argument to the handler - eb-gui's
''' own contract handler shape omits it (`SUB(userData AS ANY PTR)`
''' only, call `GuiEntryGetText` yourself instead), which is still
''' ABI-safe to connect directly: a native call always passes both
''' arguments in fixed registers regardless of how many the actual
''' handler declares, so a handler simply not accepting the second one
''' never reads it.
SUB GuiEntryConnectChanged(e AS GuiEntry, handler AS ANY PTR, userData AS ANY PTR)
    DIM realEntry AS LineEdit
    realEntry.handle = e.handle
    CALL LineEditConnectTextChanged(realEntry, handler, userData)
END SUB

''' orientation: 0=horizontal, 1=vertical (matches eb-gui's own
''' contract convention).
FUNCTION NewGuiBox(orientation AS INTEGER, spacing AS INTEGER) AS GuiBox
    DIM realLayout AS BoxLayout
    IF orientation = 1 THEN
        realLayout = NewVBoxLayout()
    ELSE
        realLayout = NewHBoxLayout()
    END IF
    CALL BoxLayoutSetSpacing(realLayout, spacing)
    DIM holder AS QtWidget
    holder = NewWidget()
    CALL WidgetSetLayout(holder, realLayout)
    CALL EbGuiQt6RecordLayout(holder.handle, realLayout.handle)
    DIM result AS GuiBox
    result.handle = holder.handle
    NewGuiBox = result
END FUNCTION

SUB GuiBoxAddChild(bx AS GuiBox, child AS ANY PTR)
    DIM realLayout AS BoxLayout
    realLayout.handle = EbGuiQt6LayoutOf(bx.handle)
    DIM childWidget AS QtWidget
    childWidget.handle = child
    CALL BoxLayoutAddWidget(realLayout, childWidget)
END SUB

FUNCTION NewGuiGrid() AS GuiGrid
    DIM realLayout AS GridLayout
    realLayout = NewGridLayout()
    DIM holder AS QtWidget
    holder = NewWidget()
    CALL WidgetSetLayout(holder, realLayout)
    CALL EbGuiQt6RecordLayout(holder.handle, realLayout.handle)
    DIM result AS GuiGrid
    result.handle = holder.handle
    NewGuiGrid = result
END FUNCTION

''' `GridLayoutAddWidget`'s own real param order is (row, column,
''' rowSpan, columnSpan) - reordered here to match this contract's own
''' (column, row, columnSpan, rowSpan) convention, shared with
''' `eb-gui-gtk4`'s identical `GuiGridAttach` shape.
SUB GuiGridAttach(gr AS GuiGrid, child AS ANY PTR, column AS INTEGER, row AS INTEGER, columnSpan AS INTEGER, rowSpan AS INTEGER)
    DIM realLayout AS GridLayout
    realLayout.handle = EbGuiQt6LayoutOf(gr.handle)
    DIM childWidget AS QtWidget
    childWidget.handle = child
    CALL GridLayoutAddWidget(realLayout, childWidget, row, column, rowSpan, columnSpan)
END SUB

''' Maps the contract's toolkit-neutral GUI_ALIGN_* onto real Qt's own
''' horizontal Qt::AlignmentFlag constants (label.bas). GUI_ALIGN_FILL
''' maps to 0 (no flag) - real Qt fills an axis by default when no
''' alignment flag is given for it.
FUNCTION EbGuiQt6MapHAlign(guiAlign AS INTEGER) AS INTEGER
    IF guiAlign = GUI_ALIGN_START THEN
        EbGuiQt6MapHAlign = QtAlignLeft
    ELSEIF guiAlign = GUI_ALIGN_CENTER THEN
        EbGuiQt6MapHAlign = QtAlignHCenter
    ELSEIF guiAlign = GUI_ALIGN_END THEN
        EbGuiQt6MapHAlign = QtAlignRight
    ELSE
        EbGuiQt6MapHAlign = 0
    END IF
END FUNCTION

''' Same as EbGuiQt6MapHAlign, for the vertical axis.
FUNCTION EbGuiQt6MapVAlign(guiAlign AS INTEGER) AS INTEGER
    IF guiAlign = GUI_ALIGN_START THEN
        EbGuiQt6MapVAlign = QtAlignTop
    ELSEIF guiAlign = GUI_ALIGN_CENTER THEN
        EbGuiQt6MapVAlign = QtAlignVCenter
    ELSEIF guiAlign = GUI_ALIGN_END THEN
        EbGuiQt6MapVAlign = QtAlignBottom
    ELSE
        EbGuiQt6MapVAlign = 0
    END IF
END FUNCTION

''' Like GuiBoxAddChild, but also sets `child`'s relative growth weight
''' along the box's own main axis (real QBoxLayout stretch factor - a
''' genuine proportional ratio, unlike eb-gui-gtk4's boolean-only
''' expand) and its alignment on the cross axis.
SUB GuiBoxAddChildEx(bx AS GuiBox, child AS ANY PTR, expand AS SINGLE, halign AS INTEGER, valign AS INTEGER)
    DIM realLayout AS BoxLayout
    realLayout.handle = EbGuiQt6LayoutOf(bx.handle)
    DIM childWidget AS QtWidget
    childWidget.handle = child
    DIM alignment AS INTEGER
    alignment = EbGuiQt6MapHAlign(halign) OR EbGuiQt6MapVAlign(valign)
    CALL BoxLayoutAddWidgetEx(realLayout, childWidget, CInt(expand), alignment)
END SUB

''' Like GuiGridAttach, but also sets `child`'s alignment within its cell.
SUB GuiGridAttachEx(gr AS GuiGrid, child AS ANY PTR, column AS INTEGER, row AS INTEGER, columnSpan AS INTEGER, rowSpan AS INTEGER, halign AS INTEGER, valign AS INTEGER)
    DIM realLayout AS GridLayout
    realLayout.handle = EbGuiQt6LayoutOf(gr.handle)
    DIM childWidget AS QtWidget
    childWidget.handle = child
    DIM alignment AS INTEGER
    alignment = EbGuiQt6MapHAlign(halign) OR EbGuiQt6MapVAlign(valign)
    CALL GridLayoutAddWidgetEx(realLayout, childWidget, row, column, rowSpan, columnSpan, alignment)
END SUB

''' Real QGridLayout::setRowStretch/setColumnStretch - independent of
''' which widget(s) occupy that row/column.
SUB GuiGridSetColumnWeight(gr AS GuiGrid, column AS INTEGER, weight AS SINGLE)
    DIM realLayout AS GridLayout
    realLayout.handle = EbGuiQt6LayoutOf(gr.handle)
    CALL GridLayoutSetColumnStretch(realLayout, column, CInt(weight))
END SUB

SUB GuiGridSetRowWeight(gr AS GuiGrid, row AS INTEGER, weight AS SINGLE)
    DIM realLayout AS GridLayout
    realLayout.handle = EbGuiQt6LayoutOf(gr.handle)
    CALL GridLayoutSetRowStretch(realLayout, row, CInt(weight))
END SUB

''' Direct pass-through to QWidget::setMinimumSize/setMaximumSize -
''' both already real and bound, no prerequisite native work needed
''' this round (unlike eb-gui-gtk4's own GuiWidgetSetMaxSize, a
''' documented no-op - real GTK4 has no such API at all).
SUB GuiWidgetSetMinSize(handle AS ANY PTR, width AS INTEGER, height AS INTEGER)
    DIM w AS QtWidget
    w.handle = handle
    CALL WidgetSetMinimumSize(w, width, height)
END SUB

SUB GuiWidgetSetMaxSize(handle AS ANY PTR, width AS INTEGER, height AS INTEGER)
    DIM w AS QtWidget
    w.handle = handle
    CALL WidgetSetMaximumSize(w, width, height)
END SUB

''' Structurally independent of Menu/ToolBar/StatusBar chrome (unlike
''' eb-gui-gtk4/eb-gui-haiku's own shared content area) - a direct
''' pass-through to QMainWindow::setCentralWidget, no ordering concern
''' at all.
SUB GuiWindowSetContent(win AS GuiWindow, content AS ANY PTR)
    DIM realWin AS MainWindow
    realWin.handle = win.handle
    DIM contentWidget AS QtWidget
    contentWidget.handle = content
    CALL MainWindowSetCentralWidget(realWin, contentWidget)
END SUB

''' Real Qt6 shares one AbstractButton base for CheckBox/RadioButton -
''' both map to eb-qt6's own CheckBox TYPE here (eb-qt6's own real
''' CheckBox/RadioButton TYPEs both EXTEND AbstractButton, and the
''' shared AbstractButtonSetChecked/IsChecked/ConnectToggled functions
''' take an AbstractButton, so wrapping either concrete type's handle
''' as AbstractButton works identically).
FUNCTION NewGuiCheckBox(text AS ZSTRING) AS GuiCheckBox
    DIM realCb AS CheckBox
    realCb = NewCheckBox(text)
    DIM result AS GuiCheckBox
    result.handle = realCb.handle
    NewGuiCheckBox = result
END FUNCTION

SUB GuiCheckBoxSetChecked(cb AS GuiCheckBox, checked AS INTEGER)
    DIM realAb AS AbstractButton
    realAb.handle = cb.handle
    CALL AbstractButtonSetChecked(realAb, checked)
END SUB

FUNCTION GuiCheckBoxIsChecked(cb AS GuiCheckBox) AS INTEGER
    DIM realAb AS AbstractButton
    realAb.handle = cb.handle
    GuiCheckBoxIsChecked = AbstractButtonIsChecked(realAb)
END FUNCTION

''' Discards the real `checked AS INTEGER` value AbstractButtonConnectToggled's
''' own native shim passes - the contract's own handler shape has no
''' extra param (see eb-gui's own README) - call GuiCheckBoxIsChecked
''' yourself from inside the handler instead.
SUB GuiCheckBoxConnectToggled(cb AS GuiCheckBox, handler AS ANY PTR, userData AS ANY PTR)
    DIM realAb AS AbstractButton
    realAb.handle = cb.handle
    CALL AbstractButtonConnectToggled(realAb, handler, userData)
END SUB

FUNCTION NewGuiRadioButton(text AS ZSTRING) AS GuiRadioButton
    DIM realRb AS RadioButton
    realRb = NewRadioButton(text)
    DIM result AS GuiRadioButton
    result.handle = realRb.handle
    NewGuiRadioButton = result
END FUNCTION

SUB GuiRadioButtonSetChecked(rb AS GuiRadioButton, checked AS INTEGER)
    DIM realAb AS AbstractButton
    realAb.handle = rb.handle
    CALL AbstractButtonSetChecked(realAb, checked)
END SUB

FUNCTION GuiRadioButtonIsChecked(rb AS GuiRadioButton) AS INTEGER
    DIM realAb AS AbstractButton
    realAb.handle = rb.handle
    GuiRadioButtonIsChecked = AbstractButtonIsChecked(realAb)
END FUNCTION

SUB GuiRadioButtonConnectToggled(rb AS GuiRadioButton, handler AS ANY PTR, userData AS ANY PTR)
    DIM realAb AS AbstractButton
    realAb.handle = rb.handle
    CALL AbstractButtonConnectToggled(realAb, handler, userData)
END SUB

''' Real Qt6 needs an explicit QButtonGroup object for cross-container
''' radio exclusivity - the contract's own shape matches GTK4's simpler
''' chain-to-a-reference-button model instead (no group object), so
''' this adapter hides a real ButtonGroup behind the scenes: the first
''' time a given `firstInGroup` handle is seen, a new ButtonGroup is
''' created (parented to `firstInGroup` itself for lifetime) and both
''' buttons are added to it; subsequent calls sharing the same
''' `firstInGroup` reuse the same group. Same "hide the real object"
''' pattern as GuiBox/GuiGrid's own holder-widget design (Round 1).
SUB GuiRadioButtonSetGroup(rb AS GuiRadioButton, firstInGroup AS GuiRadioButton)
    DIM groupHandle AS ANY PTR
    groupHandle = EbGuiQt6LayoutOf(firstInGroup.handle)
    DIM realGroup AS ButtonGroup
    IF groupHandle = 0 THEN
        DIM firstAb AS AbstractButton
        firstAb.handle = firstInGroup.handle
        realGroup = NewButtonGroup(firstAb)
        CALL EbGuiQt6RecordLayout(firstInGroup.handle, realGroup.handle)
        CALL ButtonGroupAddButton(realGroup, firstAb)
    ELSE
        realGroup.handle = groupHandle
    END IF
    DIM rbAb AS AbstractButton
    rbAb.handle = rb.handle
    CALL ButtonGroupAddButton(realGroup, rbAb)
END SUB

FUNCTION NewGuiComboBox() AS GuiComboBox
    DIM realCombo AS ComboBox
    realCombo = NewComboBox()
    DIM result AS GuiComboBox
    result.handle = realCombo.handle
    NewGuiComboBox = result
END FUNCTION

SUB GuiComboBoxAddItem(cb AS GuiComboBox, text AS ZSTRING)
    DIM realCombo AS ComboBox
    realCombo.handle = cb.handle
    CALL ComboBoxAddItem(realCombo, text)
END SUB

FUNCTION GuiComboBoxGetSelectedIndex(cb AS GuiComboBox) AS INTEGER
    DIM realCombo AS ComboBox
    realCombo.handle = cb.handle
    GuiComboBoxGetSelectedIndex = ComboBoxCurrentIndex(realCombo)
END FUNCTION

SUB GuiComboBoxSetSelectedIndex(cb AS GuiComboBox, index AS INTEGER)
    DIM realCombo AS ComboBox
    realCombo.handle = cb.handle
    CALL ComboBoxSetCurrentIndex(realCombo, index)
END SUB

''' Real ComboBoxCurrentText returns a freshly allocated string - same
''' accepted per-call leak as GuiButtonGetText's own precedent (Round 1),
''' the contract has no matching free function.
FUNCTION GuiComboBoxGetSelectedText(cb AS GuiComboBox) AS ZSTRING
    DIM realCombo AS ComboBox
    realCombo.handle = cb.handle
    DIM raw AS ANY PTR
    raw = ComboBoxCurrentText(realCombo)
    DIM z AS ZSTRING
    z = raw
    GuiComboBoxGetSelectedText = z
END FUNCTION

''' Discards the real `index AS INTEGER` value
''' ComboBoxConnectCurrentIndexChanged's own shim passes - see
''' GuiCheckBoxConnectToggled's own doc comment above.
SUB GuiComboBoxConnectChanged(cb AS GuiComboBox, handler AS ANY PTR, userData AS ANY PTR)
    DIM realCombo AS ComboBox
    realCombo.handle = cb.handle
    CALL ComboBoxConnectCurrentIndexChanged(realCombo, handler, userData)
END SUB
