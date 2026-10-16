# UltimateToolkit Pro GUI

Run:

```bat
Toolkit-GUI.cmd
```

The GUI reads `Toolkit.bat` at startup and builds a visual menu system automatically.

## What it shows

- Main CMD menus in 4 columns.
- Submenus in 4 columns after clicking a menu.
- Leaf options launch the original CMD option through `Toolkit.bat`.
- One Click Actions are collected into a separate section.
- System Inventory has its own GUI screen for HTML inventory reports.
- Portable Software is collected from `Config\tools.catalog`.
- Search can find any parsed menu, submenu, option, or label.

## System Inventory

The `System Inventory` sidebar menu can:

- Generate one complete HTML report with saved Wi-Fi keys, Windows key when available, serial numbers, health colors, installed software, and portable tools inventory.
- Open the latest report.
- Open the inventory output folder.

Inventory reports intentionally include saved Wi-Fi passwords and Windows key details when available.

Reports are written to:

```text
C:\System Inventory\COMPUTERNAME_Inventory.html
```

If that folder cannot be created, the GUI falls back to `Logs\SystemInventory`.

## Add portable software

Create a folder:

```text
Tools\ToolName\ToolName.exe
```

Then add a line:

```text
Config\tools.catalog
```

Example:

```text
08|CPU-Z|exe|Tools\CPUZ\cpuz_x64.exe|Hardware information
```

Restart the GUI and the tool appears in the Portable Software section.

## CMD compatibility

The GUI does not remove CMD functionality. It uses:

```bat
Toolkit.bat --no-elevate --label menu_label --back parent_label
```

Submenu buttons navigate inside the GUI. CMD option buttons open the mapped batch label directly when possible, and safe inline actions run in their own CMD window without redirected input loops.
