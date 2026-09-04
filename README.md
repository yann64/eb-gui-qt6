# eb-gui-qt6

The Qt6 backend adapter for
[eb-gui](https://github.com/yann64/eb-gui), eBasic's universal,
cross-toolkit `Application`/`Window` API, managed with `ebpm`.

## Status

**Confirmed running on Haiku, unmodified** (2026-09-04) - real
HaikuPorts `qt6_base`, and `examples/verify` (compiled directly via
`ebc`, same manual-linking gap as on Linux) all work with zero source
changes; see `eb-qt6`'s own README for the platform detail (Qt6's Haiku
port uses its own native platform plugin).

Phase 1 (`Application`/`Window`) plus all of Phase 2
(`StatusBar`/`Timer`/`Menu`/`Toolbar`/`Action`), implementing every
function in `eb-gui`'s own contract by calling into
[`eb-qt6`](https://github.com/yann64/eb-qt6). Needs **no native code at
all** - unlike `eb-gui-gtk4`, `eb-qt6`'s own `MainWindowSetCloseCallback`
already matches `eb-gui`'s contract shape and polarity exactly, so
`GuiWindowSetCloseCallback` is a direct pass-through, and `GuiTimer` maps
directly onto `eb-qt6`'s own richer `QTimer` object model
(`GuiTimerDestroy` is a documented no-op here - `eb-qt6`'s own
`timer.bas` has no manual destroy at all, since real Qt destroys a
`QTimer` when its parent window is destroyed). The Menu/Toolbar/Action
functions are direct pass-throughs too, for the same reason: `eb-gui`'s
own contract deliberately follows Qt6's simpler "create a fresh action
per call" shape rather than GTK4's richer, action-sharing model (see
`eb-gui`'s own README), so this adapter needed no bridging at all -
`eb-qt6`'s own `MenuAddAction`/`ToolBarAddAction`/`ActionConnectTriggered`/
`ActionSetEnabled`/`ActionIsEnabled`/`ActionTrigger`/`MainWindowToolBar`
(the last four added in `eb-qt6` v0.26.0 specifically for this) already
match the contract shape verbatim.

**Widget/Layout Round 1** (`GuiButton`/`GuiLabel`/`GuiEntry` +
`GuiBox`/`GuiGrid`) needed one real design decision: a `QBoxLayout`/
`QGridLayout` is NOT itself a `QWidget`, unlike GTK4's own `Box`/`Grid`
- so `GuiBox`/`GuiGrid.handle` here is really a small holder `QWidget`
(created internally, with the real layout applied to it via
`WidgetSetLayout`), not the layout object directly. The real layout is
tracked separately (`EbGuiQt6RecordLayout`/`LayoutOf`, a small
association table) so `GuiBoxAddChild`/`GuiGridAttach` know which one
to call `AddWidget` on - from the contract's own perspective a
`GuiBox`/`GuiGrid` still always "is a thing you can hand to
`GuiBoxAddChild`/`GuiGridAttach`/`GuiWindowSetContent` uniformly,"
matching `eb-gui-gtk4`'s own direct (holder-free) shape from the
outside. `GuiButtonGetText`/`GuiEntryGetText` intentionally leak one
small heap buffer per call - real Qt's own text getters return a
freshly allocated buffer every time (unlike GTK4/Haiku's borrowed,
long-lived storage), and `eb-gui`'s own contract has no matching free
function for this return value.

## Building

```sh
cd ../eb-qt6/native && cmake -S . -B build && cmake --build build && cd -
EBASIC_LIBRARY_PATH=$(pwd)/../eb-qt6/native/build ebpm build
```

**Known gap, inherited from `eb-qt6` itself**: Qt6 has no legitimate
public C symbol anywhere in its core libraries for `ebpm`'s `.libs`
sidecar to auto-forward, so `ebpm build`/`run` cannot produce a final
linked *binary* on its own - only a library target builds cleanly this
way. A consumer program must compile via `ebc` directly with the
manual `-l` flags `eb-qt6`'s own README documents
(`-l Qt6PrintSupport -l Qt6Network -l Qt6Widgets -l Qt6Gui -l Qt6Core`,
plus `-L`/`-l` for this adapter's, `eb-gui`'s, and `eb-qt6`'s own
compiled archives) - see `examples/*/ebasic.toml` for the dependency
declarations and this README's own "Verifying" section for the exact
working `ebc` invocation.

## A real, backend-specific asymmetry worth knowing

`GuiApplicationQuit` called *before* `GuiApplicationRun` has ever
started its event loop has **no effect at all** on this backend -
confirmed by direct reproduction (a hang). Real
`QCoreApplication::quit()` just posts a quit request; nothing is
running yet to process it. This is different from `eb-gui-gtk4`, where
the same ordering produces a noisy `GLib-GIO-CRITICAL` assertion but
still works. Not a bug in either adapter - a genuine difference between
the two toolkits' own startup models. In practice this never matters:
`GuiApplicationQuit` is always called from a real running callback
(a close handler, a menu action, ...), never before `GuiApplicationRun`
starts.

## A real, confirmed-not-assumed correction to this project's own plan

The plan for this package originally assumed Qt6's `QApplication`
doesn't auto-quit when its last window closes (unlike GTK4's
`GApplication`), and that this adapter would need to track its own
live-window count. **Confirmed by direct reproduction, this was
wrong**: `quitOnLastWindowClosed` (`ApplicationSetQuitOnLastWindowClosed`,
already default-on per `eb-qt6`'s own docs) genuinely works for
`eb-gui`'s synchronous construct-then-run style - *as long as the close
happens while `GuiApplicationRun`'s event loop is actually running*
(true of any real user interaction). An initial test hung because it
closed the window *before* calling `GuiApplicationRun` at all - not a
real usage shape, and not evidence of a missing feature. This adapter
needs zero window-count bookkeeping as a result - just one explicit
`ApplicationSetQuitOnLastWindowClosed(realApp, 1)` call inside
`NewGuiApplication`, for certainty regardless of any future `eb-qt6`
default change.

## A real, confirmed-not-assumed Qt quit/close interaction

`ApplicationQuit`/`GuiApplicationQuit` implicitly tries to close every
*visible* top-level window as part of Qt's own shutdown sequence -
found the hard way while writing this package's own `examples/verify`:
an early version showed a window with a permanently-vetoing
`GuiWindowSetCloseCallback` and then expected a later, unrelated
`GuiTimer`-driven `GuiApplicationQuit` to still work - it silently
hung instead, since the vetoed implicit close aborted the quit too.
Fixed by not showing that window (an invisible window's veto has no
such effect). GTK4 has no equivalent negotiation - `GuiApplicationQuit`
there always stops unconditionally. See `MainWindowSetCloseCallback`'s
own doc comment in `eb-qt6` for the full detail.

## Using as a dependency

```toml
[dependencies]
gui-qt6 = { git = "https://github.com/yann64/eb-gui-qt6.git" }
```

```basic
' Only the adapter's own interface is needed - it already carries a
' full copy of GuiApplication/GuiWindow.
#include "gui-qt6.iface.bas"

DIM app AS GuiApplication
app = NewGuiApplication("io.github.you.yourapp")

DIM win AS GuiWindow
win = NewGuiWindow(app, "Hello", 320, 240)
CALL GuiWindowShow(win)

DIM bar AS GuiMenuBar
bar = GuiWindowMenuBar(win)
DIM fileMenu AS GuiMenu
fileMenu = GuiMenuBarAddMenu(bar, "File")
DIM openAction AS GuiAction
openAction = GuiMenuAddAction(fileMenu, "Open...")

SUB OnOpen(userData AS ANY PTR)
    PRINT "open"
END SUB
CALL GuiActionConnectTriggered(openAction, @OnOpen, 0)

DIM box AS GuiBox
box = NewGuiBox(1, 8)   ' 1 = vertical

DIM lbl AS GuiLabel
lbl = NewGuiLabel("Type something, then click Go")
CALL GuiBoxAddChild(box, lbl.handle)

DIM entry AS GuiEntry
entry = NewGuiEntry("")
CALL GuiBoxAddChild(box, entry.handle)

SUB OnGo(userData AS ANY PTR)
    DIM e AS GuiEntry
    e.handle = userData
    PRINT GuiEntryGetText(e)
END SUB

DIM btn AS GuiButton
btn = NewGuiButton("Go")
CALL GuiButtonConnectClicked(btn, @OnGo, entry.handle)
CALL GuiBoxAddChild(box, btn.handle)

CALL GuiWindowSetContent(win, box.handle)

CALL GuiApplicationRun(app)
```

Round 2 constraints (expand/align/weight):

```basic
DIM growBtn AS GuiButton
growBtn = NewGuiButton("Grows")
CALL GuiBoxAddChildEx(box, growBtn.handle, 1.0, GUI_ALIGN_FILL, GUI_ALIGN_CENTER)

DIM fixedBtn AS GuiButton
fixedBtn = NewGuiButton("Fixed")
CALL GuiBoxAddChildEx(box, fixedBtn.handle, 0.0, GUI_ALIGN_END, GUI_ALIGN_START)
```

`GuiBoxAddChildEx`/`GuiGridAttachEx` look up the real underlying
`BoxLayout`/`GridLayout` via the same `EbGuiQt6LayoutOf` association
table `NewGuiBox`/`NewGuiGrid` already use (see above), then call
`eb-qt6` v0.27.0's new `BoxLayoutAddWidgetEx`/`GridLayoutAddWidgetEx` -
real `QBoxLayout`/`QGridLayout` overloads, a genuine proportional
stretch factor (`expand`, cast to an `INTEGER` via `CInt`), not just a
boolean like `eb-gui-gtk4`'s own. `GUI_ALIGN_*` maps to real Qt's own
horizontal/vertical `Qt::AlignmentFlag` constants (`label.bas`'s
`QtAlign*`, combined via `OR`) - `GUI_ALIGN_FILL` maps to `0` (no flag),
real Qt's own default when neither is given. `GuiGridSetColumnWeight`/
`SetRowWeight` are real, direct `setColumnStretch`/`setRowStretch`
pass-throughs - unlike `eb-gui-gtk4`, where they're a documented no-op
(`GtkGrid` has no such concept in real GTK4 at all).

Round 3 explicit min/max size - needed **zero** prerequisite native
work (`WidgetSetMinimumSize`/`MaximumSize` already existed):

```basic
CALL GuiWidgetSetMinSize(entry.handle, 200, 40)
CALL GuiWidgetSetMaxSize(entry.handle, 400, 40)
```

`GuiWidgetSetMinSize`/`SetMaxSize` are direct pass-throughs to
`WidgetSetMinimumSize`/`WidgetSetMaximumSize` - both real here, unlike
`eb-gui-gtk4`'s own `GuiWidgetSetMaxSize` (a documented no-op, GTK4 has
no such API at all). Note min/max size are a floor/ceiling on what the
layout may allocate, not a growth mechanism by themselves - pair with
`GuiBoxAddChildEx`'s own `expand` parameter (Round 2) if you want a
constrained item to also visibly grow into leftover space.

## Widgets (Round 4) - CheckBox, RadioButton, ComboBox

Needed **zero** prerequisite native work - `eb-qt6` already had rich
`CheckBox`/`RadioButton`/`ComboBox`/`ButtonGroup` bindings; this round
anchored the whole cross-toolkit contract's shape on this package's own
already-built model, the reverse of the layout-constraints rounds
(where Haiku anchored the shape instead).

```basic
DIM cb AS GuiCheckBox
cb = NewGuiCheckBox("Enable feature")
CALL GuiCheckBoxSetChecked(cb, 1)

DIM r1 AS GuiRadioButton
r1 = NewGuiRadioButton("Option A")
DIM r2 AS GuiRadioButton
r2 = NewGuiRadioButton("Option B")
CALL GuiRadioButtonSetGroup(r2, r1)   ' r1/r2 now mutually exclusive

DIM combo AS GuiComboBox
combo = NewGuiComboBox()
CALL GuiComboBoxAddItem(combo, "First")
CALL GuiComboBoxAddItem(combo, "Second")
CALL GuiComboBoxSetSelectedIndex(combo, 0)
PRINT GuiComboBoxGetSelectedText(combo)
```

`GuiCheckBox`/`GuiRadioButton` both wrap `eb-qt6`'s own `CheckBox`/
`RadioButton` (both `EXTENDS AbstractButton`) - the shared
`AbstractButtonSetChecked`/`IsChecked`/`ConnectToggled` functions work
on either concrete type's handle identically. `ConnectToggled`'s real
native shim actually passes a second `checked AS INTEGER` argument the
contract's own 1-param handler shape doesn't declare - safe per this
ecosystem's established ABI rule (a native call site passing MORE
arguments than an eBasic handler declares is safe, the extras just sit
unused - the same reasoning `GuiEntryConnectChanged`'s own pass-through
to `LineEditConnectTextChanged` already relies on).

**The real 3-way grouping asymmetry, hidden in this adapter**: real Qt6
needs an explicit `ButtonGroup` object for cross-container radio
exclusivity, but the contract's own `GuiRadioButtonSetGroup(rb,
firstInGroup)` matches GTK4's simpler "chain to a reference button"
shape instead (no object at all). This adapter reuses the existing
`EbGuiQt6LayoutOf`/`RecordLayout` association table (Round 1) to lazily
create and track a real `ButtonGroup` the first time a given
`firstInGroup` handle is grouped, parented to `firstInGroup` itself for
lifetime - same "hide the real object behind the scenes" pattern as
`GuiBox`/`GuiGrid`'s own holder-widget design.

`GuiComboBoxGetSelectedText` deliberately leaks a small per-call
buffer, same accepted precedent as this package's own `GuiButtonGetText`
(Round 1) - real `ComboBoxCurrentText` returns a freshly allocated
string and the contract has no matching free function.

## Widgets (Round 5) - ProgressBar, Slider

Needed **zero** prerequisite native work - `eb-qt6` already had rich
`ProgressBar`/`Slider` bindings.

```basic
DIM pb AS GuiProgressBar
pb = NewGuiProgressBar()
CALL GuiProgressBarSetRange(pb, 0, 200)
CALL GuiProgressBarSetValue(pb, 150)

DIM slider AS GuiSlider
slider = NewGuiSlider(0)
CALL GuiSliderSetRange(slider, 0, 200)
CALL GuiSliderSetValue(slider, 150)
```

Direct pass-throughs throughout. `GuiSliderConnectValueChanged` passes
the caller's own handler straight to `SliderConnectValueChanged` - the
real native shim passes an extra `value AS INTEGER` the contract's
1-param handler doesn't declare, safe per this ecosystem's established
ABI rule (extra trailing args are ignored), same reasoning already
used for `GuiCheckBoxConnectToggled`.

**Real, confirmed-not-assumed default-value difference**: a freshly
created `GuiProgressBar` reads `-1` here (real Qt's own documented
"no value set yet" sentinel for `QProgressBar`), not `0` like
`eb-gui-gtk4`'s own default - a genuine Qt convention, not a bug;
`SetValue`/`SetRange` behave identically once called.

## Verifying

Built and run via `ebc` directly (see "Building" above for why):

```sh
ebc examples/hello_window/src/main.bas -o hello_window \
    -I target -I ../eb-qt6/target \
    -L target -l gui-qt6 \
    -L ../eb-qt6/target -l qt6 \
    -L ../eb-qt6/native/build -l ebqt6shim \
    -l Qt6PrintSupport -l Qt6Network -l Qt6Widgets -l Qt6Gui -l Qt6Core
```

- `examples/hello_window` - a plain window appears, title set through
  the universal API (screenshot-verified live on this host - visually
  distinct from `eb-gui-gtk4`'s own equivalent only in native theming,
  never in behavior).
- `examples/verify` - headless(-ish) verification of every contract
  function: `GuiWindowSetEnabled`/`IsEnabled` round-tripped correctly;
  `GuiWindowCanMove()` correctly reads `1` on this backend (vs. `0` for
  GTK4) and a real `GuiWindowMove` call didn't crash; `GuiWindowSetModal`/
  `ClearModal` and `GuiWindowSetCloseCallback` connected without
  crashing (the underlying close-callback firing behavior is already
  directly verified at the `eb-qt6` layer,
  `window_lifecycle_verify.bas`, since this adapter is a direct
  pass-through with no translation of its own to test); `GuiStatusBar`
  show/clear didn't crash; `GuiActionTrigger` genuinely reaches a
  connected `GuiActionConnectTriggered` handler for both a menu action
  and a tool bar action; `GuiActionSetEnabled`/`IsEnabled` round-trip
  correctly; `GuiWindowToolBar` returns the identical handle on repeated
  calls; `GuiEntrySetText`/`GetText` round-trip correctly through a
  `GuiGrid` nested inside a `GuiBox` (each via its own holder-widget
  mechanism); `GuiWindowSetContent` onto the `MainWindow`'s own central
  widget slot doesn't crash; `GuiBoxAddChildEx`/`GuiGridAttachEx`/
  `GuiGridSetColumnWeight`/`SetRowWeight` (Round 2 constraints) run
  without crashing, resolving through `EbGuiQt6LayoutOf` correctly
  including a nested `GuiGrid`; `GuiWidgetSetMinSize`/`SetMaxSize`
  (Round 3) run without crashing; `GuiCheckBoxConnectToggled`/
  `GuiRadioButtonSetGroup` (real cross-container exclusivity via the
  lazily-created `ButtonGroup`)/`GuiComboBoxConnectChanged` (Round 4)
  all fire/round-trip correctly on a genuine programmatic state change;
  `GuiProgressBarSetRange`/`SetValue`/`GetValue` and
  `GuiSliderSetRange`/`SetValue`/`GetValue`/`ConnectValueChanged`
  (Round 5) round-trip correctly; and - genuinely exercised this time,
  closing a gap this file used to flag - `GuiTimer` driving a real,
  running-loop `GuiApplicationQuit` (a single-shot timer's own callback
  calls it): the program exiting promptly rather than hanging proves
  the interval/single-shot/callback-dispatch and quit all work correctly
  together.
- `examples/widgets_form` - a `GuiBox` containing a `GuiLabel` +
  `GuiEntry` + `GuiButton`, clicking the button reads the entry and
  updates the label (confirmed launches and runs without crashing on
  this host).

## See also

- [`eb-gui`](https://github.com/yann64/eb-gui) - the shared contract this package implements.
- [`eb-gui-gtk4`](https://github.com/yann64/eb-gui-gtk4) - the GTK4 adapter.
- [`eb-qt6`](https://github.com/yann64/eb-qt6) - the underlying Qt6 binding.
