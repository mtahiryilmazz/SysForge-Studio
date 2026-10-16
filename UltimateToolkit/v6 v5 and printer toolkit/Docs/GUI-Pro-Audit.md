# Pro GUI Audit

Generated for the current `Toolkit.bat` on 2026-05-25.

```text
Batch labels        : 475
Menu blocks         : 159
Parsed options      : 2195
One-click options   : 129
Portable tools      : 17
Static GUI shortcuts: 73
Inventory script    : OK
Report center       : OK
Bad label targets   : 0
```

Result:

- The Pro GUI parser can read the current CMD menus and submenus.
- Menu and submenu cards are rendered in a 4-column layout.
- Sidebar and content now use a fixed 2-column layout, so cards do not slide under the left menu.
- Top toolbar and card grid now use a fixed 2-row layout, so cards do not hide behind the header controls.
- One-click style actions are grouped separately.
- System Inventory now has a dedicated GUI screen and complete HTML report generator.
- Battery Report has a dedicated CMD wrapper in `Modules\BatteryReport.cmd`.
- Inventory reports intentionally include saved Wi-Fi passwords and Windows key details when available.
- Portable tools catalog now lists only existing EXE/script targets.
- Portable software is loaded from `Config\tools.catalog`.
- `Toolkit.bat --label ...` now opens mapped CMD menus from the GUI.
- Main menu option `37` is exposed in the GUI catalog.
- Winget search/upgrade output parsing handles both Winget and Microsoft Store source tables.
- All static Winget IDs in `Toolkit.bat` validated against the local Winget catalog.
- No broken GUI label targets were found in the parsed model.
