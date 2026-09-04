# eb-gui-qt6

The Qt6 backend adapter for
[eb-gui](https://github.com/yann64/eb-gui), eBasic's universal,
cross-toolkit `Application`/`Window` API, managed with `ebpm`.

## Status

Phase 1: `Application`/`Window` only, implementing every function in
`eb-gui`'s own contract by calling into
[`eb-qt6`](https://github.com/yann64/eb-qt6). Needs **no native code at
all** - unlike `eb-gui-gtk4`, `eb-qt6`'s own `MainWindowSetCloseCallback`
already matches `eb-gui`'s contract shape and polarity exactly, so
`GuiWindowSetCloseCallback` is a direct pass-through.

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

CALL GuiApplicationRun(app)
```

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
  pass-through with no translation of its own to test).

## See also

- [`eb-gui`](https://github.com/yann64/eb-gui) - the shared contract this package implements.
- [`eb-gui-gtk4`](https://github.com/yann64/eb-gui-gtk4) - the GTK4 adapter.
- [`eb-qt6`](https://github.com/yann64/eb-qt6) - the underlying Qt6 binding.
