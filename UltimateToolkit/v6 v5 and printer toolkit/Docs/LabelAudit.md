# Label Audit

Source: Toolkit.bat
Generated: 2026-05-25T16:52:38+05:30

## Summary

- Total lines: 10754
- Labels found: 475
- Literal goto/call label references: 3680
- Duplicate labels: 0
- Broken literal labels: 0
- Dynamic goto statements: 2
- Menu-like blocks mapped: 157

## Broken Labels

No broken literal `goto` or `call :label` references were detected.

## Duplicate Labels

No duplicate labels were detected.

## Dynamic Goto Statements

- Line 285: `goto !BACK_MENU!`
- Line 300: `goto !SAFE_DEST!`

## Added Routing

- Main menu `G` routes to `launch_gui` and opens `Toolkit-GUI.cmd`.
- Main menu `T` and `36` route to `portable_tools_menu`.
- Main menu `37` routes to `menu_1click_100_apps`.
- `--label <label>` can launch existing CMD labels from the GUI.
- Logs default to `Logs` under the toolkit root for portability.
