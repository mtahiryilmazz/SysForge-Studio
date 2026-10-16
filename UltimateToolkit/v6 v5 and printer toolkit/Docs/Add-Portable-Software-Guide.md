# Add Portable Software

Use this pattern for every future tool:

```text
Tools\ToolName\ToolName.exe
```

Then add one line in:

```text
Config\tools.catalog
```

Format:

```text
ID|Name|Type|RelativeOrAbsolutePath|Notes
```

Example:

```text
08|CPU-Z|exe|Tools\CPUZ\cpuz_x64.exe|Hardware information
09|CrystalDiskInfo|exe|Tools\CrystalDiskInfo\DiskInfo64.exe|Disk SMART viewer
10|My Script|script|Modules\MyScript.cmd|Run custom batch script
```

Supported types:

```text
exe     Launches an EXE
script  Calls a CMD/BAT script
folder  Opens a folder
url     Opens a URL or Windows URI
```

Important:

Use relative paths for SFX portability. Avoid paths like `C:\Tools`, `Desktop`, `Downloads`, or another user's profile.
