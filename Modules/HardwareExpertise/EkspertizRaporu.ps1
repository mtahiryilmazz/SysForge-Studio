[CmdletBinding()]
param(
    [switch]$NoGui,
    [switch]$SaveSnapshot,
    [string]$BaselineSnapshotPath,
    [string]$TargetSnapshotPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:AppName = 'Donanim Ekspertiz Merkezi'
$script:AppVersion = '2.0'
$script:DesktopPath = [Environment]::GetFolderPath('Desktop')
$script:BaseFolder = Join-Path $script:DesktopPath 'EkspertizArsivi'
$script:SnapshotFolder = Join-Path $script:BaseFolder 'Snapshots'
$script:ReportFolder = Join-Path $script:BaseFolder 'Raporlar'
$script:CompareFolder = Join-Path $script:BaseFolder 'Karsilastirmalar'
$script:BatteryFolder = Join-Path $script:BaseFolder 'BataryaRaporlari'
$script:CurrentSnapshot = $null
$script:CurrentTextReport = ''
$script:CurrentHtmlReport = ''
$script:LastCompareResult = $null
$script:StatusLabel = $null

function Initialize-Storage {
    foreach ($folder in @(
        $script:BaseFolder,
        $script:SnapshotFolder,
        $script:ReportFolder,
        $script:CompareFolder,
        $script:BatteryFolder
    )) {
        if (-not (Test-Path -LiteralPath $folder)) {
            [void](New-Item -ItemType Directory -Path $folder -Force)
        }
    }
}

function Set-Status {
    param(
        [string]$Message
    )

    if ($script:StatusLabel) {
        $script:StatusLabel.Text = $Message
        [System.Windows.Forms.Application]::DoEvents()
    }
}

function Get-SafeText {
    param(
        [object]$Value,
        [string]$Fallback = '-'
    )

    if ($null -eq $Value) {
        return $Fallback
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $Fallback
    }

    return $text.Trim()
}

function Get-SafeNumber {
    param(
        [object]$Value,
        [double]$Default = 0
    )

    if ($null -eq $Value) {
        return $Default
    }

    try {
        return [double]$Value
    }
    catch {
        return $Default
    }
}

function Convert-ToGb {
    param(
        [object]$Value
    )

    if ($null -eq $Value) {
        return 0
    }

    try {
        return [Math]::Round(([double]$Value / 1GB), 2)
    }
    catch {
        return 0
    }
}

function Format-DateValue {
    param(
        [object]$Value
    )

    if ($null -eq $Value) {
        return '-'
    }

    try {
        return ([datetime]$Value).ToString('yyyy-MM-dd HH:mm:ss')
    }
    catch {
        return (Get-SafeText -Value $Value)
    }
}

function Get-UniqueFilePath {
    param(
        [string]$Directory,
        [string]$BaseName,
        [string]$Extension
    )

    $candidate = Join-Path $Directory ($BaseName + $Extension)
    $index = 1

    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path $Directory ('{0}_{1}{2}' -f $BaseName, $index, $Extension)
        $index++
    }

    return $candidate
}

function Get-SafeCimInstance {
    param(
        [string]$ClassName,
        [string]$Namespace = 'root/cimv2'
    )

    try {
        return @(Get-CimInstance -Namespace $Namespace -ClassName $ClassName -ErrorAction Stop)
    }
    catch {
        return @()
    }
}

function Test-ToolCommand {
    param(
        [string]$Name
    )

    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Convert-ByteArrayToText {
    param(
        [byte[]]$Bytes
    )

    if (-not $Bytes) {
        return '-'
    }

    $chars = foreach ($byte in $Bytes) {
        if ($byte -gt 0) {
            [char]$byte
        }
    }

    $value = -join $chars
    if ([string]::IsNullOrWhiteSpace($value)) {
        return '-'
    }

    return $value.Trim()
}

function Get-HashString {
    param(
        [string]$InputString
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
        $hashBytes = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hashBytes) -replace '-', '')
    }
    finally {
        $sha.Dispose()
    }
}

function Get-SectionHash {
    param(
        [object]$InputObject
    )

    try {
        $json = $InputObject | ConvertTo-Json -Compress -Depth 12
    }
    catch {
        $json = (Get-SafeText -Value $InputObject)
    }

    return (Get-HashString -InputString $json)
}

function Get-VideoOutputTechnologyName {
    param(
        [int]$Code
    )

    switch ($Code) {
        -2 { 'Unknown' }
        -1 { 'Other' }
        0 { 'HD15 / VGA' }
        1 { 'S-Video' }
        2 { 'Composite Video' }
        3 { 'Component Video' }
        4 { 'DVI' }
        5 { 'HDMI' }
        6 { 'LVDS' }
        8 { 'D-JPN' }
        9 { 'SDI' }
        10 { 'DisplayPort External' }
        11 { 'DisplayPort Embedded' }
        12 { 'UDI External' }
        13 { 'UDI Embedded' }
        14 { 'Miracast' }
        15 { 'Indirect Wired' }
        16 { 'Indirect Virtual' }
        default { 'Kod {0}' -f $Code }
    }
}

function Get-BatteryChemistryName {
    param(
        [int]$Code
    )

    switch ($Code) {
        1 { 'Other' }
        2 { 'Unknown' }
        3 { 'Lead Acid' }
        4 { 'Nickel Cadmium' }
        5 { 'Nickel Metal Hydride' }
        6 { 'Lithium-ion' }
        7 { 'Zinc Air' }
        8 { 'Lithium Polymer' }
        default { 'Kod {0}' -f $Code }
    }
}

function Get-LicenseSummary {
    $license = $null

    try {
        $license = Get-CimInstance SoftwareLicensingProduct -ErrorAction Stop |
            Where-Object { $_.PartialProductKey -and $_.Name -like '*Windows*' } |
            Select-Object -First 1
    }
    catch {
        $license = $null
    }

    if ($null -eq $license) {
        return [pscustomobject][ordered]@{
            Name = '-'
            LicenseStatus = '-'
            PartialProductKey = '-'
            Description = '-'
        }
    }

    return [pscustomobject][ordered]@{
        Name = Get-SafeText -Value $license.Name
        LicenseStatus = Get-SafeText -Value $license.LicenseStatus
        PartialProductKey = Get-SafeText -Value $license.PartialProductKey
        Description = Get-SafeText -Value $license.Description
    }
}

function Get-SecuritySummary {
    $tpmPresent = 'Unknown'
    $tpmReady = 'Unknown'
    $tpmManufacturer = '-'
    $tpmVersion = '-'
    $secureBoot = 'Unknown'

    if (Test-ToolCommand -Name 'Get-Tpm') {
        try {
            $tpm = Get-Tpm
            if ($tpm) {
                $tpmPresent = [string]$tpm.TpmPresent
                $tpmReady = [string]$tpm.TpmReady
                $tpmManufacturer = Get-SafeText -Value $tpm.ManufacturerIdTxt
                $tpmVersion = Get-SafeText -Value $tpm.ManufacturerVersion
            }
        }
        catch {
        }
    }

    try {
        $secureBoot = [string](Confirm-SecureBootUEFI)
    }
    catch {
        $secureBoot = 'Desteklenmiyor'
    }

    return [pscustomobject][ordered]@{
        TpmPresent = $tpmPresent
        TpmReady = $tpmReady
        TpmManufacturer = $tpmManufacturer
        TpmVersion = $tpmVersion
        SecureBoot = $secureBoot
    }
}

function Get-CurrentScreenInfo {
    $items = foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
        [pscustomobject][ordered]@{
            DeviceName = Get-SafeText -Value $screen.DeviceName
            IsPrimary = [bool]$screen.Primary
            Resolution = '{0} x {1}' -f $screen.Bounds.Width, $screen.Bounds.Height
            WorkingArea = '{0} x {1}' -f $screen.WorkingArea.Width, $screen.WorkingArea.Height
            Bounds = '{0},{1},{2},{3}' -f $screen.Bounds.X, $screen.Bounds.Y, $screen.Bounds.Width, $screen.Bounds.Height
        }
    }

    return @($items | Sort-Object DeviceName)
}

function Get-MonitorInventory {
    $monitorIds = @(Get-SafeCimInstance -Namespace 'root/wmi' -ClassName 'WmiMonitorID')
    $monitorConnections = @(Get-SafeCimInstance -Namespace 'root/wmi' -ClassName 'WmiMonitorConnectionParams')
    $connectionMap = @{}

    foreach ($connection in $monitorConnections) {
        $connectionMap[$connection.InstanceName] = $connection
    }

    $items = foreach ($monitor in $monitorIds) {
        $serialNumber = Convert-ByteArrayToText -Bytes $monitor.SerialNumberID
        $friendlyName = Convert-ByteArrayToText -Bytes $monitor.UserFriendlyName
        $manufacturer = Convert-ByteArrayToText -Bytes $monitor.ManufacturerName
        $productCode = Convert-ByteArrayToText -Bytes $monitor.ProductCodeID
        $connection = $connectionMap[$monitor.InstanceName]
        $connectionType = '-'

        if ($connection) {
            $connectionType = Get-VideoOutputTechnologyName -Code ([int]$connection.VideoOutputTechnology)
        }

        [pscustomobject][ordered]@{
            FriendlyName = $friendlyName
            Manufacturer = $manufacturer
            ProductCode = $productCode
            SerialNumber = $serialNumber
            InstanceName = Get-SafeText -Value $monitor.InstanceName
            Active = [bool]$monitor.Active
            YearOfManufacture = Get-SafeText -Value $monitor.YearOfManufacture
            WeekOfManufacture = Get-SafeText -Value $monitor.WeekOfManufacture
            ConnectionType = $connectionType
        }
    }

    return @($items | Sort-Object FriendlyName, SerialNumber, InstanceName)
}

function Get-DeviceClassSummary {
    if (-not (Test-ToolCommand -Name 'Get-PnpDevice')) {
        return @()
    }

    try {
        $devices = Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object { $_.Class }

        $summary = $devices |
            Group-Object Class |
            Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false } |
            ForEach-Object {
                [pscustomobject][ordered]@{
                    Class = Get-SafeText -Value $_.Name
                    Count = [int]$_.Count
                }
            }

        return @($summary)
    }
    catch {
        return @()
    }
}

function Get-BatteryReportFile {
    param(
        [string]$FileStem
    )

    $batteries = @(Get-SafeCimInstance -ClassName 'Win32_Battery')
    if ($batteries.Count -eq 0) {
        return $null
    }

    $path = Get-UniqueFilePath -Directory $script:BatteryFolder -BaseName ('Battery_{0}' -f $FileStem) -Extension '.html'

    try {
        powercfg /batteryreport /output $path | Out-Null
        if (Test-Path -LiteralPath $path) {
            return $path
        }
    }
    catch {
    }

    return $null
}

function Convert-CollectionToText {
    param(
        [object[]]$Items,
        [scriptblock]$Formatter
    )

    if (-not $Items -or $Items.Count -eq 0) {
        return '- Veri yok'
    }

    $lines = foreach ($item in $Items) {
        & $Formatter $item
    }

    return ($lines -join [Environment]::NewLine)
}

function Get-HardwareFingerprint {
    param(
        [object[]]$Cpu,
        [object]$Board,
        [object]$Bios,
        [object[]]$Disks,
        [object[]]$Gpu,
        [object[]]$Monitors,
        [object]$SystemInfo
    )

    $parts = @()

    foreach ($item in $Cpu) {
        $parts += (Get-SafeText -Value $item.ProcessorId)
        $parts += (Get-SafeText -Value $item.Name)
    }

    $parts += (Get-SafeText -Value $Board.SerialNumber)
    $parts += (Get-SafeText -Value $Bios.SerialNumber)

    foreach ($item in $Disks) {
        $parts += (Get-SafeText -Value $item.SerialNumber)
    }

    foreach ($item in $Gpu) {
        $parts += (Get-SafeText -Value $item.PnpDeviceId)
    }

    foreach ($item in $Monitors) {
        $parts += (Get-SafeText -Value $item.SerialNumber)
    }

    $parts += (Get-SafeText -Value $SystemInfo.Manufacturer)
    $parts += (Get-SafeText -Value $SystemInfo.Model)

    $normalized = $parts |
        Where-Object { $_ -and $_ -ne '-' } |
        Sort-Object

    if ($normalized.Count -eq 0) {
        $normalized = @(
            Get-SafeText -Value $env:COMPUTERNAME,
            (Get-Date).ToString('yyyyMMdd')
        )
    }

    return (Get-HashString -InputString ($normalized -join '|'))
}

function Get-InventorySnapshot {
    Initialize-Storage
    Set-Status -Message 'Donanim verileri toplanıyor...'

    $computer = Get-SafeCimInstance -ClassName 'Win32_ComputerSystem' | Select-Object -First 1
    $operatingSystem = Get-SafeCimInstance -ClassName 'Win32_OperatingSystem' | Select-Object -First 1
    $board = Get-SafeCimInstance -ClassName 'Win32_BaseBoard' | Select-Object -First 1
    $bios = Get-SafeCimInstance -ClassName 'Win32_BIOS' | Select-Object -First 1
    $memoryArray = Get-SafeCimInstance -ClassName 'Win32_PhysicalMemoryArray' | Select-Object -First 1
    $computerName = Get-SafeText -Value $env:COMPUTERNAME

    if ($computer -and $computer.Name) {
        $computerName = Get-SafeText -Value $computer.Name
    }

    $snapshotId = '{0}_{1}' -f (Get-Date).ToString('yyyy-MM-dd_HH-mm-ss'), ($computerName -replace '[^A-Za-z0-9_-]', '_')

    $cpu = @(Get-SafeCimInstance -ClassName 'Win32_Processor' |
        ForEach-Object {
            [pscustomobject][ordered]@{
                DeviceId = Get-SafeText -Value $_.DeviceID
                Name = Get-SafeText -Value $_.Name
                Manufacturer = Get-SafeText -Value $_.Manufacturer
                ProcessorId = Get-SafeText -Value $_.ProcessorId
                Socket = Get-SafeText -Value $_.SocketDesignation
                CoreCount = [int](Get-SafeNumber -Value $_.NumberOfCores)
                LogicalProcessorCount = [int](Get-SafeNumber -Value $_.NumberOfLogicalProcessors)
                MaxClockMHz = [int](Get-SafeNumber -Value $_.MaxClockSpeed)
            }
        } |
        Sort-Object DeviceId, Name)

    $memoryModules = @(Get-SafeCimInstance -ClassName 'Win32_PhysicalMemory' |
        ForEach-Object {
            [pscustomobject][ordered]@{
                BankLabel = Get-SafeText -Value $_.BankLabel
                DeviceLocator = Get-SafeText -Value $_.DeviceLocator
                Manufacturer = Get-SafeText -Value $_.Manufacturer
                PartNumber = Get-SafeText -Value $_.PartNumber
                SerialNumber = Get-SafeText -Value $_.SerialNumber
                CapacityGB = Convert-ToGb -Value $_.Capacity
                SpeedMHz = [int](Get-SafeNumber -Value $_.Speed)
                ConfiguredSpeedMHz = [int](Get-SafeNumber -Value $_.ConfiguredClockSpeed)
                MemoryType = [int](Get-SafeNumber -Value $_.SMBIOSMemoryType)
            }
        } |
        Sort-Object BankLabel, DeviceLocator, SerialNumber)

    $physicalDisks = @(Get-SafeCimInstance -ClassName 'Win32_DiskDrive' |
        ForEach-Object {
            [pscustomobject][ordered]@{
                Model = Get-SafeText -Value $_.Model
                SerialNumber = Get-SafeText -Value $_.SerialNumber
                InterfaceType = Get-SafeText -Value $_.InterfaceType
                MediaType = Get-SafeText -Value $_.MediaType
                FirmwareRevision = Get-SafeText -Value $_.FirmwareRevision
                Partitions = [int](Get-SafeNumber -Value $_.Partitions)
                SizeGB = Convert-ToGb -Value $_.Size
                PnpDeviceId = Get-SafeText -Value $_.PNPDeviceID
            }
        } |
        Sort-Object Model, SerialNumber, SizeGB)

    $logicalDisks = @(Get-SafeCimInstance -ClassName 'Win32_LogicalDisk' |
        Where-Object { $_.DriveType -eq 3 } |
        ForEach-Object {
            [pscustomobject][ordered]@{
                DriveLetter = Get-SafeText -Value $_.DeviceID
                VolumeName = Get-SafeText -Value $_.VolumeName
                FileSystem = Get-SafeText -Value $_.FileSystem
                SizeGB = Convert-ToGb -Value $_.Size
                FreeGB = Convert-ToGb -Value $_.FreeSpace
            }
        } |
        Sort-Object DriveLetter)

    $gpu = @(Get-SafeCimInstance -ClassName 'Win32_VideoController' |
        ForEach-Object {
            $resolution = '-'
            if ($_.CurrentHorizontalResolution -and $_.CurrentVerticalResolution) {
                $resolution = '{0} x {1}' -f $_.CurrentHorizontalResolution, $_.CurrentVerticalResolution
            }

            [pscustomobject][ordered]@{
                Name = Get-SafeText -Value $_.Name
                VideoProcessor = Get-SafeText -Value $_.VideoProcessor
                DriverVersion = Get-SafeText -Value $_.DriverVersion
                AdapterRamGB = Convert-ToGb -Value $_.AdapterRAM
                CurrentResolution = $resolution
                Status = Get-SafeText -Value $_.Status
                PnpDeviceId = Get-SafeText -Value $_.PNPDeviceID
            }
        } |
        Sort-Object Name, PnpDeviceId)

    $monitors = @(Get-MonitorInventory)
    $screens = @(Get-CurrentScreenInfo)

    $networkAdapters = @(Get-SafeCimInstance -ClassName 'Win32_NetworkAdapter' |
        Where-Object {
            $_.PhysicalAdapter -eq $true -or
            -not [string]::IsNullOrWhiteSpace([string]$_.MACAddress)
        } |
        ForEach-Object {
            $speedGbps = 0
            if ($_.Speed) {
                $speedGbps = [Math]::Round(([double]$_.Speed / 1e9), 2)
            }

            [pscustomobject][ordered]@{
                Name = Get-SafeText -Value $_.Name
                Manufacturer = Get-SafeText -Value $_.Manufacturer
                MACAddress = Get-SafeText -Value $_.MACAddress
                AdapterType = Get-SafeText -Value $_.AdapterType
                SpeedGbps = $speedGbps
                PhysicalAdapter = [bool]$_.PhysicalAdapter
                NetConnectionStatus = Get-SafeText -Value $_.NetConnectionStatus
                PnpDeviceId = Get-SafeText -Value $_.PNPDeviceID
            }
        } |
        Sort-Object Name, MACAddress)

    $soundDevices = @(Get-SafeCimInstance -ClassName 'Win32_SoundDevice' |
        ForEach-Object {
            [pscustomobject][ordered]@{
                Name = Get-SafeText -Value $_.Name
                Manufacturer = Get-SafeText -Value $_.Manufacturer
                Status = Get-SafeText -Value $_.Status
                PnpDeviceId = Get-SafeText -Value $_.PNPDeviceID
            }
        } |
        Sort-Object Name, Manufacturer)

    $batteryInfo = @(Get-SafeCimInstance -ClassName 'Win32_Battery' |
        ForEach-Object {
            [pscustomobject][ordered]@{
                Name = Get-SafeText -Value $_.Name
                DeviceId = Get-SafeText -Value $_.DeviceID
                Chemistry = Get-BatteryChemistryName -Code ([int](Get-SafeNumber -Value $_.Chemistry))
                Status = Get-SafeText -Value $_.Status
                BatteryStatus = Get-SafeText -Value $_.BatteryStatus
            }
        } |
        Sort-Object Name, DeviceId)

    $deviceClassSummary = @(Get-DeviceClassSummary)
    $security = Get-SecuritySummary
    $license = Get-LicenseSummary
    $batteryReport = Get-BatteryReportFile -FileStem $snapshotId

    $systemInfo = [pscustomobject][ordered]@{
        ComputerName = $computerName
        Manufacturer = Get-SafeText -Value $computer.Manufacturer
        Model = Get-SafeText -Value $computer.Model
        SystemType = Get-SafeText -Value $computer.SystemType
        Domain = Get-SafeText -Value $computer.Domain
        TotalPhysicalMemoryGB = Convert-ToGb -Value $computer.TotalPhysicalMemory
        UserName = Get-SafeText -Value $computer.UserName
    }

    $osInfo = [pscustomobject][ordered]@{
        Caption = Get-SafeText -Value $operatingSystem.Caption
        Version = Get-SafeText -Value $operatingSystem.Version
        BuildNumber = Get-SafeText -Value $operatingSystem.BuildNumber
        Architecture = Get-SafeText -Value $operatingSystem.OSArchitecture
        InstallDate = Format-DateValue -Value $operatingSystem.InstallDate
        LastBootUpTime = Format-DateValue -Value $operatingSystem.LastBootUpTime
        SerialNumber = Get-SafeText -Value $operatingSystem.SerialNumber
    }

    $motherboardInfo = [pscustomobject][ordered]@{
        Manufacturer = Get-SafeText -Value $board.Manufacturer
        Product = Get-SafeText -Value $board.Product
        SerialNumber = Get-SafeText -Value $board.SerialNumber
        Version = Get-SafeText -Value $board.Version
    }

    $biosInfo = [pscustomobject][ordered]@{
        Manufacturer = Get-SafeText -Value $bios.Manufacturer
        SMBIOSVersion = Get-SafeText -Value $bios.SMBIOSBIOSVersion
        Version = Get-SafeText -Value $bios.Version
        ReleaseDate = Format-DateValue -Value $bios.ReleaseDate
        SerialNumber = Get-SafeText -Value $bios.SerialNumber
    }

    $maxCapacityGb = 0
    if ($memoryArray -and $memoryArray.MaxCapacityEx) {
        $maxCapacityGb = Convert-ToGb -Value $memoryArray.MaxCapacityEx
    }
    elseif ($memoryArray -and $memoryArray.MaxCapacity) {
        $maxCapacityGb = [Math]::Round(([double]$memoryArray.MaxCapacity / 1MB), 2)
    }

    $memoryInfo = [pscustomobject][ordered]@{
        TotalInstalledGB = [Math]::Round((($memoryModules | Measure-Object -Property CapacityGB -Sum).Sum), 2)
        ModuleCount = $memoryModules.Count
        MemorySlotCount = [int](Get-SafeNumber -Value $memoryArray.MemoryDevices)
        MaxCapacityGB = $maxCapacityGb
        Modules = @($memoryModules)
    }

    $fingerprint = Get-HardwareFingerprint -Cpu $cpu -Board $motherboardInfo -Bios $biosInfo -Disks $physicalDisks -Gpu $gpu -Monitors $monitors -SystemInfo $systemInfo

    $componentHashes = [pscustomobject][ordered]@{
        System = Get-SectionHash -InputObject $systemInfo
        OperatingSystem = Get-SectionHash -InputObject $osInfo
        Motherboard = Get-SectionHash -InputObject $motherboardInfo
        Bios = Get-SectionHash -InputObject $biosInfo
        Cpu = Get-SectionHash -InputObject $cpu
        Memory = Get-SectionHash -InputObject $memoryInfo
        Disks = Get-SectionHash -InputObject $physicalDisks
        Volumes = Get-SectionHash -InputObject $logicalDisks
        Gpu = Get-SectionHash -InputObject $gpu
        Monitors = Get-SectionHash -InputObject $monitors
        Screens = Get-SectionHash -InputObject $screens
        NetworkAdapters = Get-SectionHash -InputObject $networkAdapters
        SoundDevices = Get-SectionHash -InputObject $soundDevices
        Battery = Get-SectionHash -InputObject $batteryInfo
        Security = Get-SectionHash -InputObject $security
    }

    return [pscustomobject][ordered]@{
        Metadata = [pscustomobject][ordered]@{
            AppName = $script:AppName
            AppVersion = $script:AppVersion
            SnapshotId = $snapshotId
            CreatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            ComputerName = $computerName
            BaseFolder = $script:BaseFolder
            BatteryReportPath = $batteryReport
            SnapshotJsonPath = ''
            TextReportPath = ''
            HtmlReportPath = ''
        }
        System = $systemInfo
        OperatingSystem = $osInfo
        Motherboard = $motherboardInfo
        Bios = $biosInfo
        Cpu = @($cpu)
        Memory = $memoryInfo
        Disks = @($physicalDisks)
        Volumes = @($logicalDisks)
        Gpu = @($gpu)
        Monitors = @($monitors)
        Screens = @($screens)
        NetworkAdapters = @($networkAdapters)
        SoundDevices = @($soundDevices)
        Battery = @($batteryInfo)
        DeviceClassSummary = @($deviceClassSummary)
        Security = $security
        License = $license
        Fingerprint = $fingerprint
        ComponentHashes = $componentHashes
    }
}

function Get-SnapshotQuickSummary {
    param(
        [object]$Snapshot
    )

    $cpuName = '-'
    if ($Snapshot.Cpu -and $Snapshot.Cpu.Count -gt 0) {
        $cpuName = Get-SafeText -Value $Snapshot.Cpu[0].Name
    }

    $gpuName = '-'
    if ($Snapshot.Gpu -and $Snapshot.Gpu.Count -gt 0) {
        $gpuName = Get-SafeText -Value $Snapshot.Gpu[0].Name
    }

    $monitorCount = 0
    if ($Snapshot.Monitors) {
        $monitorCount = $Snapshot.Monitors.Count
    }

    return @(
        'Bilgisayar : {0} {1}' -f (Get-SafeText -Value $Snapshot.System.Manufacturer), (Get-SafeText -Value $Snapshot.System.Model)
        'Host       : {0}' -f (Get-SafeText -Value $Snapshot.Metadata.ComputerName)
        'Windows    : {0} ({1})' -f (Get-SafeText -Value $Snapshot.OperatingSystem.Caption), (Get-SafeText -Value $Snapshot.OperatingSystem.Version)
        'CPU        : {0}' -f $cpuName
        'RAM        : {0} GB ({1} modul)' -f (Get-SafeText -Value $Snapshot.Memory.TotalInstalledGB), (Get-SafeText -Value $Snapshot.Memory.ModuleCount)
        'GPU        : {0}' -f $gpuName
        'Disk       : {0} fiziksel / {1} bolum' -f ($Snapshot.Disks.Count), ($Snapshot.Volumes.Count)
        'Monitor    : {0}' -f $monitorCount
        'Parmak Izi : {0}' -f (Get-SafeText -Value $Snapshot.Fingerprint)
    ) -join [Environment]::NewLine
}

function Convert-SnapshotToText {
    param(
        [object]$Snapshot
    )

    $cpuText = Convert-CollectionToText -Items $Snapshot.Cpu -Formatter {
        param($item)
        '- {0} | Uretici: {1} | Socket: {2} | Core: {3} | Thread: {4} | Max MHz: {5} | ProcessorId: {6}' -f
            (Get-SafeText -Value $item.Name),
            (Get-SafeText -Value $item.Manufacturer),
            (Get-SafeText -Value $item.Socket),
            (Get-SafeText -Value $item.CoreCount),
            (Get-SafeText -Value $item.LogicalProcessorCount),
            (Get-SafeText -Value $item.MaxClockMHz),
            (Get-SafeText -Value $item.ProcessorId)
    }

    $ramText = Convert-CollectionToText -Items $Snapshot.Memory.Modules -Formatter {
        param($item)
        '- {0} | Slot: {1} | Uretici: {2} | Part: {3} | Seri: {4} | Kapasite: {5} GB | Hiz: {6} MHz | Config: {7} MHz' -f
            (Get-SafeText -Value $item.BankLabel),
            (Get-SafeText -Value $item.DeviceLocator),
            (Get-SafeText -Value $item.Manufacturer),
            (Get-SafeText -Value $item.PartNumber),
            (Get-SafeText -Value $item.SerialNumber),
            (Get-SafeText -Value $item.CapacityGB),
            (Get-SafeText -Value $item.SpeedMHz),
            (Get-SafeText -Value $item.ConfiguredSpeedMHz)
    }

    $diskText = Convert-CollectionToText -Items $Snapshot.Disks -Formatter {
        param($item)
        '- {0} | Seri: {1} | Tip: {2} | Arayuz: {3} | Boyut: {4} GB | Firmware: {5} | Partitions: {6}' -f
            (Get-SafeText -Value $item.Model),
            (Get-SafeText -Value $item.SerialNumber),
            (Get-SafeText -Value $item.MediaType),
            (Get-SafeText -Value $item.InterfaceType),
            (Get-SafeText -Value $item.SizeGB),
            (Get-SafeText -Value $item.FirmwareRevision),
            (Get-SafeText -Value $item.Partitions)
    }

    $volumeText = Convert-CollectionToText -Items $Snapshot.Volumes -Formatter {
        param($item)
        '- {0} | Hacim: {1} | Dosya Sistemi: {2} | Boyut: {3} GB | Bos: {4} GB' -f
            (Get-SafeText -Value $item.DriveLetter),
            (Get-SafeText -Value $item.VolumeName),
            (Get-SafeText -Value $item.FileSystem),
            (Get-SafeText -Value $item.SizeGB),
            (Get-SafeText -Value $item.FreeGB)
    }

    $gpuText = Convert-CollectionToText -Items $Snapshot.Gpu -Formatter {
        param($item)
        '- {0} | Islemci: {1} | RAM: {2} GB | Surucu: {3} | Cozunurluk: {4} | PNP: {5}' -f
            (Get-SafeText -Value $item.Name),
            (Get-SafeText -Value $item.VideoProcessor),
            (Get-SafeText -Value $item.AdapterRamGB),
            (Get-SafeText -Value $item.DriverVersion),
            (Get-SafeText -Value $item.CurrentResolution),
            (Get-SafeText -Value $item.PnpDeviceId)
    }

    $monitorText = Convert-CollectionToText -Items $Snapshot.Monitors -Formatter {
        param($item)
        '- {0} | Uretici: {1} | Seri: {2} | Baglanti: {3} | Uretim: {4}/{5} | Active: {6}' -f
            (Get-SafeText -Value $item.FriendlyName),
            (Get-SafeText -Value $item.Manufacturer),
            (Get-SafeText -Value $item.SerialNumber),
            (Get-SafeText -Value $item.ConnectionType),
            (Get-SafeText -Value $item.WeekOfManufacture),
            (Get-SafeText -Value $item.YearOfManufacture),
            (Get-SafeText -Value $item.Active)
    }

    $screenText = Convert-CollectionToText -Items $Snapshot.Screens -Formatter {
        param($item)
        '- {0} | Primary: {1} | Resolution: {2} | WorkingArea: {3} | Bounds: {4}' -f
            (Get-SafeText -Value $item.DeviceName),
            (Get-SafeText -Value $item.IsPrimary),
            (Get-SafeText -Value $item.Resolution),
            (Get-SafeText -Value $item.WorkingArea),
            (Get-SafeText -Value $item.Bounds)
    }

    $networkText = Convert-CollectionToText -Items $Snapshot.NetworkAdapters -Formatter {
        param($item)
        '- {0} | MAC: {1} | Uretici: {2} | Tip: {3} | Hiz: {4} Gbps | Fiziksel: {5} | PNP: {6}' -f
            (Get-SafeText -Value $item.Name),
            (Get-SafeText -Value $item.MACAddress),
            (Get-SafeText -Value $item.Manufacturer),
            (Get-SafeText -Value $item.AdapterType),
            (Get-SafeText -Value $item.SpeedGbps),
            (Get-SafeText -Value $item.PhysicalAdapter),
            (Get-SafeText -Value $item.PnpDeviceId)
    }

    $soundText = Convert-CollectionToText -Items $Snapshot.SoundDevices -Formatter {
        param($item)
        '- {0} | Uretici: {1} | Durum: {2} | PNP: {3}' -f
            (Get-SafeText -Value $item.Name),
            (Get-SafeText -Value $item.Manufacturer),
            (Get-SafeText -Value $item.Status),
            (Get-SafeText -Value $item.PnpDeviceId)
    }

    $batteryText = Convert-CollectionToText -Items $Snapshot.Battery -Formatter {
        param($item)
        '- {0} | DeviceId: {1} | Kimya: {2} | Durum: {3} | BatteryStatus: {4}' -f
            (Get-SafeText -Value $item.Name),
            (Get-SafeText -Value $item.DeviceId),
            (Get-SafeText -Value $item.Chemistry),
            (Get-SafeText -Value $item.Status),
            (Get-SafeText -Value $item.BatteryStatus)
    }

    $deviceClassText = Convert-CollectionToText -Items $Snapshot.DeviceClassSummary -Formatter {
        param($item)
        '- {0}: {1}' -f (Get-SafeText -Value $item.Class), (Get-SafeText -Value $item.Count)
    }

    $componentHashText = Convert-CollectionToText -Items $Snapshot.ComponentHashes.PSObject.Properties -Formatter {
        param($item)
        '- {0}: {1}' -f (Get-SafeText -Value $item.Name), (Get-SafeText -Value $item.Value)
    }

    return @"
=========================================================
                DONANIM EKSPERTIZ RAPORU
=========================================================

Rapor Zamani : $($Snapshot.Metadata.CreatedAt)
Snapshot ID  : $($Snapshot.Metadata.SnapshotId)

=== GENEL SISTEM ===

Bilgisayar Adi : $($Snapshot.Metadata.ComputerName)
Marka / Model  : $($Snapshot.System.Manufacturer) $($Snapshot.System.Model)
Sistem Tipi    : $($Snapshot.System.SystemType)
Domain         : $($Snapshot.System.Domain)
Toplam RAM     : $($Snapshot.System.TotalPhysicalMemoryGB) GB
Kullanici      : $($Snapshot.System.UserName)

=== ISLETIM SISTEMI ===

Windows        : $($Snapshot.OperatingSystem.Caption)
Versiyon       : $($Snapshot.OperatingSystem.Version)
Build          : $($Snapshot.OperatingSystem.BuildNumber)
Mimari         : $($Snapshot.OperatingSystem.Architecture)
Kurulum Tarihi : $($Snapshot.OperatingSystem.InstallDate)
Son Acilis     : $($Snapshot.OperatingSystem.LastBootUpTime)
Seri No        : $($Snapshot.OperatingSystem.SerialNumber)

=== CPU ===

$cpuText

=== ANAKART ===

Uretici        : $($Snapshot.Motherboard.Manufacturer)
Model          : $($Snapshot.Motherboard.Product)
Seri No        : $($Snapshot.Motherboard.SerialNumber)
Versiyon       : $($Snapshot.Motherboard.Version)

=== BIOS ===

Uretici        : $($Snapshot.Bios.Manufacturer)
SMBIOS         : $($Snapshot.Bios.SMBIOSVersion)
Versiyon       : $($Snapshot.Bios.Version)
Yayin Tarihi   : $($Snapshot.Bios.ReleaseDate)
Seri No        : $($Snapshot.Bios.SerialNumber)

=== RAM ===

Toplam Takili  : $($Snapshot.Memory.TotalInstalledGB) GB
Modul Sayisi   : $($Snapshot.Memory.ModuleCount)
Slot Sayisi    : $($Snapshot.Memory.MemorySlotCount)
Max Kapasite   : $($Snapshot.Memory.MaxCapacityGB) GB

$ramText

=== FIZIKSEL DISKLER ===

$diskText

=== BOLUM / VOLUME ===

$volumeText

=== GPU / EKRAN KARTI ===

$gpuText

=== MONITORLER ===

$monitorText

=== EKRAN YERLESIMI ===

$screenText

=== AG BAGLASTIRICILARI ===

$networkText

=== SES AYGITLARI ===

$soundText

=== BATARYA ===

$batteryText

=== GUVENLIK ===

TPM Present    : $($Snapshot.Security.TpmPresent)
TPM Ready      : $($Snapshot.Security.TpmReady)
TPM Uretici    : $($Snapshot.Security.TpmManufacturer)
TPM Versiyon   : $($Snapshot.Security.TpmVersion)
Secure Boot    : $($Snapshot.Security.SecureBoot)

=== WINDOWS LISANS ===

Urun           : $($Snapshot.License.Name)
Lisans Durumu  : $($Snapshot.License.LicenseStatus)
Partial Key    : $($Snapshot.License.PartialProductKey)
Aciklama       : $($Snapshot.License.Description)

=== AYGIT SINIFI OZETI ===

$deviceClassText

=== CIHAZ PARMAK IZI ===

$($Snapshot.Fingerprint)

=== BILESEN HASHLERI ===

$componentHashText

=== RAPOR DOSYALARI ===

JSON           : $($Snapshot.Metadata.SnapshotJsonPath)
TXT            : $($Snapshot.Metadata.TextReportPath)
HTML           : $($Snapshot.Metadata.HtmlReportPath)
BATARYA HTML   : $($Snapshot.Metadata.BatteryReportPath)

=========================================================
Bu rapor snapshot mantigi ile olusturulmustur.
Sonraki yedeklerle karsilastirma yapilabilir.
=========================================================
"@
}

function New-HtmlSection {
    param(
        [string]$Title,
        [string]$Content
    )

    $encodedTitle = [System.Net.WebUtility]::HtmlEncode($Title)
    $encodedContent = [System.Net.WebUtility]::HtmlEncode($Content)

    return @"
<section class="section">
  <h2>$encodedTitle</h2>
  <pre>$encodedContent</pre>
</section>
"@
}

function Convert-SnapshotToHtml {
    param(
        [object]$Snapshot
    )

    $sections = @(
        (New-HtmlSection -Title 'Genel Sistem' -Content (@(
            'Bilgisayar Adi : {0}' -f $Snapshot.Metadata.ComputerName
            'Marka / Model  : {0} {1}' -f $Snapshot.System.Manufacturer, $Snapshot.System.Model
            'Sistem Tipi    : {0}' -f $Snapshot.System.SystemType
            'Toplam RAM     : {0} GB' -f $Snapshot.System.TotalPhysicalMemoryGB
            'Kullanici      : {0}' -f $Snapshot.System.UserName
        ) -join [Environment]::NewLine))
        (New-HtmlSection -Title 'Isletim Sistemi' -Content (@(
            'Windows        : {0}' -f $Snapshot.OperatingSystem.Caption
            'Versiyon       : {0}' -f $Snapshot.OperatingSystem.Version
            'Build          : {0}' -f $Snapshot.OperatingSystem.BuildNumber
            'Mimari         : {0}' -f $Snapshot.OperatingSystem.Architecture
            'Kurulum        : {0}' -f $Snapshot.OperatingSystem.InstallDate
            'Son Acilis     : {0}' -f $Snapshot.OperatingSystem.LastBootUpTime
        ) -join [Environment]::NewLine))
        (New-HtmlSection -Title 'CPU' -Content (Convert-CollectionToText -Items $Snapshot.Cpu -Formatter {
            param($item)
            '{0} | Core: {1} | Thread: {2} | Socket: {3} | ProcessorId: {4}' -f
                $item.Name, $item.CoreCount, $item.LogicalProcessorCount, $item.Socket, $item.ProcessorId
        }))
        (New-HtmlSection -Title 'Anakart' -Content (@(
            'Uretici        : {0}' -f $Snapshot.Motherboard.Manufacturer
            'Model          : {0}' -f $Snapshot.Motherboard.Product
            'Seri No        : {0}' -f $Snapshot.Motherboard.SerialNumber
            'Versiyon       : {0}' -f $Snapshot.Motherboard.Version
        ) -join [Environment]::NewLine))
        (New-HtmlSection -Title 'BIOS' -Content (@(
            'Uretici        : {0}' -f $Snapshot.Bios.Manufacturer
            'SMBIOS         : {0}' -f $Snapshot.Bios.SMBIOSVersion
            'Versiyon       : {0}' -f $Snapshot.Bios.Version
            'Yayin Tarihi   : {0}' -f $Snapshot.Bios.ReleaseDate
            'Seri No        : {0}' -f $Snapshot.Bios.SerialNumber
        ) -join [Environment]::NewLine))
        (New-HtmlSection -Title 'RAM' -Content (@(
            'Toplam Takili  : {0} GB' -f $Snapshot.Memory.TotalInstalledGB
            'Modul Sayisi   : {0}' -f $Snapshot.Memory.ModuleCount
            'Slot Sayisi    : {0}' -f $Snapshot.Memory.MemorySlotCount
            'Max Kapasite   : {0} GB' -f $Snapshot.Memory.MaxCapacityGB
            ''
            (Convert-CollectionToText -Items $Snapshot.Memory.Modules -Formatter {
                param($item)
                '{0} | Slot: {1} | Seri: {2} | Kapasite: {3} GB | Hız: {4} MHz' -f
                    $item.BankLabel, $item.DeviceLocator, $item.SerialNumber, $item.CapacityGB, $item.SpeedMHz
            })
        ) -join [Environment]::NewLine))
        (New-HtmlSection -Title 'Fiziksel Diskler' -Content (Convert-CollectionToText -Items $Snapshot.Disks -Formatter {
            param($item)
            '{0} | Seri: {1} | Tip: {2} | Boyut: {3} GB | Firmware: {4}' -f
                $item.Model, $item.SerialNumber, $item.InterfaceType, $item.SizeGB, $item.FirmwareRevision
        }))
        (New-HtmlSection -Title 'Volume / Partition' -Content (Convert-CollectionToText -Items $Snapshot.Volumes -Formatter {
            param($item)
            '{0} | Hacim: {1} | FS: {2} | Boyut: {3} GB | Bos: {4} GB' -f
                $item.DriveLetter, $item.VolumeName, $item.FileSystem, $item.SizeGB, $item.FreeGB
        }))
        (New-HtmlSection -Title 'GPU / Ekran Karti' -Content (Convert-CollectionToText -Items $Snapshot.Gpu -Formatter {
            param($item)
            '{0} | GPU: {1} | RAM: {2} GB | Surucu: {3} | Cozunurluk: {4}' -f
                $item.Name, $item.VideoProcessor, $item.AdapterRamGB, $item.DriverVersion, $item.CurrentResolution
        }))
        (New-HtmlSection -Title 'Monitorler' -Content (Convert-CollectionToText -Items $Snapshot.Monitors -Formatter {
            param($item)
            '{0} | Uretici: {1} | Seri: {2} | Baglanti: {3}' -f
                $item.FriendlyName, $item.Manufacturer, $item.SerialNumber, $item.ConnectionType
        }))
        (New-HtmlSection -Title 'Ekran Yerlesimi' -Content (Convert-CollectionToText -Items $Snapshot.Screens -Formatter {
            param($item)
            '{0} | Primary: {1} | Resolution: {2} | Bounds: {3}' -f
                $item.DeviceName, $item.IsPrimary, $item.Resolution, $item.Bounds
        }))
        (New-HtmlSection -Title 'Ag Baglastiricilari' -Content (Convert-CollectionToText -Items $Snapshot.NetworkAdapters -Formatter {
            param($item)
            '{0} | MAC: {1} | Hiz: {2} Gbps | PNP: {3}' -f
                $item.Name, $item.MACAddress, $item.SpeedGbps, $item.PnpDeviceId
        }))
        (New-HtmlSection -Title 'Ses Aygitlari' -Content (Convert-CollectionToText -Items $Snapshot.SoundDevices -Formatter {
            param($item)
            '{0} | Uretici: {1} | PNP: {2}' -f
                $item.Name, $item.Manufacturer, $item.PnpDeviceId
        }))
        (New-HtmlSection -Title 'Batarya' -Content (Convert-CollectionToText -Items $Snapshot.Battery -Formatter {
            param($item)
            '{0} | DeviceId: {1} | Kimya: {2} | Durum: {3}' -f
                $item.Name, $item.DeviceId, $item.Chemistry, $item.Status
        }))
        (New-HtmlSection -Title 'Guvenlik' -Content (@(
            'TPM Present : {0}' -f $Snapshot.Security.TpmPresent
            'TPM Ready   : {0}' -f $Snapshot.Security.TpmReady
            'TPM Vendor  : {0}' -f $Snapshot.Security.TpmManufacturer
            'Secure Boot : {0}' -f $Snapshot.Security.SecureBoot
        ) -join [Environment]::NewLine))
        (New-HtmlSection -Title 'Windows Lisansi' -Content (@(
            'Urun         : {0}' -f $Snapshot.License.Name
            'Durum        : {0}' -f $Snapshot.License.LicenseStatus
            'Partial Key  : {0}' -f $Snapshot.License.PartialProductKey
            'Aciklama     : {0}' -f $Snapshot.License.Description
        ) -join [Environment]::NewLine))
        (New-HtmlSection -Title 'Aygit Sinifi Ozeti' -Content (Convert-CollectionToText -Items $Snapshot.DeviceClassSummary -Formatter {
            param($item)
            '{0}: {1}' -f $item.Class, $item.Count
        }))
        (New-HtmlSection -Title 'Cihaz Parmak Izi' -Content $Snapshot.Fingerprint)
        (New-HtmlSection -Title 'Bilesen Hashleri' -Content (Convert-CollectionToText -Items $Snapshot.ComponentHashes.PSObject.Properties -Formatter {
            param($item)
            '{0}: {1}' -f $item.Name, $item.Value
        }))
    )

    $summaryCards = @(
        '<div class="card"><span>Snapshot</span><strong>{0}</strong></div>' -f [System.Net.WebUtility]::HtmlEncode($Snapshot.Metadata.SnapshotId)
        '<div class="card"><span>Bilgisayar</span><strong>{0}</strong></div>' -f [System.Net.WebUtility]::HtmlEncode($Snapshot.Metadata.ComputerName)
        '<div class="card"><span>Model</span><strong>{0} {1}</strong></div>' -f [System.Net.WebUtility]::HtmlEncode($Snapshot.System.Manufacturer), [System.Net.WebUtility]::HtmlEncode($Snapshot.System.Model)
        '<div class="card"><span>Windows</span><strong>{0}</strong></div>' -f [System.Net.WebUtility]::HtmlEncode($Snapshot.OperatingSystem.Version)
        '<div class="card"><span>RAM</span><strong>{0} GB</strong></div>' -f [System.Net.WebUtility]::HtmlEncode([string]$Snapshot.Memory.TotalInstalledGB)
        '<div class="card"><span>Monitor</span><strong>{0}</strong></div>' -f [System.Net.WebUtility]::HtmlEncode([string]$Snapshot.Monitors.Count)
    ) -join [Environment]::NewLine

    return @"
<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="utf-8" />
  <title>Ekspertiz Raporu - $($Snapshot.Metadata.SnapshotId)</title>
  <style>
    body {
      margin: 0;
      font-family: "Segoe UI", Arial, sans-serif;
      background: linear-gradient(180deg, #f5f7fb 0%, #ebf0f7 100%);
      color: #1d2734;
    }
    .wrap {
      max-width: 1180px;
      margin: 24px auto;
      padding: 0 18px 36px;
    }
    .hero {
      background: #14213d;
      color: #ffffff;
      padding: 24px 28px;
      border-radius: 18px;
      box-shadow: 0 16px 40px rgba(20, 33, 61, 0.24);
    }
    .hero h1 {
      margin: 0 0 8px;
      font-size: 30px;
    }
    .hero p {
      margin: 6px 0;
      opacity: 0.92;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
      gap: 14px;
      margin: 20px 0 26px;
    }
    .card {
      background: #ffffff;
      border-radius: 16px;
      padding: 16px 18px;
      box-shadow: 0 10px 24px rgba(15, 23, 42, 0.08);
      border: 1px solid #d8e0ee;
    }
    .card span {
      display: block;
      font-size: 12px;
      color: #5a677d;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      margin-bottom: 8px;
    }
    .card strong {
      font-size: 16px;
      color: #14213d;
    }
    .section {
      background: #ffffff;
      border-radius: 16px;
      padding: 18px 20px;
      margin-bottom: 16px;
      border: 1px solid #d8e0ee;
      box-shadow: 0 10px 24px rgba(15, 23, 42, 0.06);
    }
    .section h2 {
      margin: 0 0 12px;
      color: #0f172a;
      font-size: 21px;
    }
    pre {
      margin: 0;
      white-space: pre-wrap;
      word-break: break-word;
      font-family: "Consolas", "Courier New", monospace;
      font-size: 13px;
      line-height: 1.55;
      background: #f8fafc;
      border-radius: 12px;
      padding: 16px;
      border: 1px solid #e2e8f0;
    }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="hero">
      <h1>Bilgisayar Ekspertiz Raporu</h1>
      <p><strong>Snapshot:</strong> $([System.Net.WebUtility]::HtmlEncode($Snapshot.Metadata.SnapshotId))</p>
      <p><strong>Rapor Zamani:</strong> $([System.Net.WebUtility]::HtmlEncode($Snapshot.Metadata.CreatedAt))</p>
      <p><strong>Parmak Izi:</strong> $([System.Net.WebUtility]::HtmlEncode($Snapshot.Fingerprint))</p>
    </div>
    <div class="grid">
      $summaryCards
    </div>
    $($sections -join [Environment]::NewLine)
  </div>
</body>
</html>
"@
}

function Save-SnapshotPackage {
    param(
        [object]$Snapshot
    )

    Initialize-Storage

    $baseName = 'Snapshot_{0}' -f $Snapshot.Metadata.SnapshotId
    $jsonPath = Get-UniqueFilePath -Directory $script:SnapshotFolder -BaseName $baseName -Extension '.json'
    $txtPath = Get-UniqueFilePath -Directory $script:ReportFolder -BaseName ('Rapor_{0}' -f $Snapshot.Metadata.SnapshotId) -Extension '.txt'
    $htmlPath = Get-UniqueFilePath -Directory $script:ReportFolder -BaseName ('Rapor_{0}' -f $Snapshot.Metadata.SnapshotId) -Extension '.html'

    $Snapshot.Metadata.SnapshotJsonPath = $jsonPath
    $Snapshot.Metadata.TextReportPath = $txtPath
    $Snapshot.Metadata.HtmlReportPath = $htmlPath

    $textReport = Convert-SnapshotToText -Snapshot $Snapshot
    $htmlReport = Convert-SnapshotToHtml -Snapshot $Snapshot
    $jsonReport = $Snapshot | ConvertTo-Json -Depth 12

    Set-Content -LiteralPath $jsonPath -Value $jsonReport -Encoding UTF8
    Set-Content -LiteralPath $txtPath -Value $textReport -Encoding UTF8
    Set-Content -LiteralPath $htmlPath -Value $htmlReport -Encoding UTF8

    return [pscustomobject][ordered]@{
        JsonPath = $jsonPath
        TextPath = $txtPath
        HtmlPath = $htmlPath
        BatteryReportPath = $Snapshot.Metadata.BatteryReportPath
        TextReport = $textReport
        HtmlReport = $htmlReport
    }
}

function Get-FriendlyPath {
    param(
        [string]$Path
    )

    $friendly = $Path
    $friendly = $friendly -replace '^System', 'Sistem'
    $friendly = $friendly -replace '^OperatingSystem', 'IsletimSistemi'
    $friendly = $friendly -replace '^Motherboard', 'Anakart'
    $friendly = $friendly -replace '^Bios', 'BIOS'
    $friendly = $friendly -replace '^Cpu', 'CPU'
    $friendly = $friendly -replace '^Memory', 'RAM'
    $friendly = $friendly -replace '^Disks', 'Diskler'
    $friendly = $friendly -replace '^Volumes', 'Bolumler'
    $friendly = $friendly -replace '^Gpu', 'GPU'
    $friendly = $friendly -replace '^Monitors', 'Monitorler'
    $friendly = $friendly -replace '^Screens', 'Ekranlar'
    $friendly = $friendly -replace '^NetworkAdapters', 'AgAygitlari'
    $friendly = $friendly -replace '^SoundDevices', 'SesAygitlari'
    $friendly = $friendly -replace '^Battery', 'Batarya'
    $friendly = $friendly -replace '^Security', 'Guvenlik'
    $friendly = $friendly -replace '^License', 'Lisans'
    $friendly = $friendly -replace '^Fingerprint', 'ParmakIzi'
    $friendly = $friendly -replace '^DeviceClassSummary', 'AygitSinifiOzeti'
    return $friendly
}

function Should-IgnoreComparePath {
    param(
        [string]$Path
    )

    $ignoredPrefixes = @(
        'Metadata',
        'ComponentHashes'
    )

    foreach ($prefix in $ignoredPrefixes) {
        if ($Path -eq $prefix -or $Path.StartsWith($prefix + '.') -or $Path.StartsWith($prefix + '[')) {
            return $true
        }
    }

    return $false
}

function Convert-ObjectToFlatMap {
    param(
        [object]$InputObject,
        [string]$Prefix = ''
    )

    $map = @{}

    if ([string]::IsNullOrWhiteSpace($Prefix) -eq $false -and (Should-IgnoreComparePath -Path $Prefix)) {
        return $map
    }

    if ($null -eq $InputObject) {
        if ($Prefix) {
            $map[$Prefix] = '(bos)'
        }
        return $map
    }

    if ($InputObject -is [string] -or
        $InputObject -is [ValueType] -or
        $InputObject -is [datetime]) {
        if ($Prefix) {
            $map[$Prefix] = [string]$InputObject
        }
        return $map
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($key in ($InputObject.Keys | Sort-Object)) {
            $childPrefix = if ($Prefix) { '{0}.{1}' -f $Prefix, $key } else { [string]$key }
            $childMap = Convert-ObjectToFlatMap -InputObject $InputObject[$key] -Prefix $childPrefix
            foreach ($entry in $childMap.GetEnumerator()) {
                $map[$entry.Key] = $entry.Value
            }
        }
        return $map
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $index = 0
        foreach ($item in $InputObject) {
            $childPrefix = '{0}[{1}]' -f $Prefix, $index
            $childMap = Convert-ObjectToFlatMap -InputObject $item -Prefix $childPrefix
            foreach ($entry in $childMap.GetEnumerator()) {
                $map[$entry.Key] = $entry.Value
            }
            $index++
        }

        if ($index -eq 0 -and $Prefix) {
            $map[$Prefix] = '(bos-koleksiyon)'
        }

        return $map
    }

    $properties = @($InputObject.PSObject.Properties | Sort-Object Name)
    if ($properties.Count -eq 0) {
        if ($Prefix) {
            $map[$Prefix] = [string]$InputObject
        }
        return $map
    }

    foreach ($property in $properties) {
        $childPrefix = if ($Prefix) { '{0}.{1}' -f $Prefix, $property.Name } else { [string]$property.Name }
        $childMap = Convert-ObjectToFlatMap -InputObject $property.Value -Prefix $childPrefix
        foreach ($entry in $childMap.GetEnumerator()) {
            $map[$entry.Key] = $entry.Value
        }
    }

    return $map
}

function Get-ChangedSections {
    param(
        [object]$Baseline,
        [object]$Target
    )

    $names = @()

    if ($Baseline.ComponentHashes) {
        $names += $Baseline.ComponentHashes.PSObject.Properties.Name
    }

    if ($Target.ComponentHashes) {
        $names += $Target.ComponentHashes.PSObject.Properties.Name
    }

    $names = $names | Sort-Object -Unique
    $changed = @()

    foreach ($name in $names) {
        $baseValue = Get-SafeText -Value $Baseline.ComponentHashes.$name
        $targetValue = Get-SafeText -Value $Target.ComponentHashes.$name

        if ($baseValue -ne $targetValue) {
            $changed += $name
        }
    }

    return @($changed)
}

function Compare-Snapshots {
    param(
        [object]$Baseline,
        [object]$Target
    )

    $baselineMap = Convert-ObjectToFlatMap -InputObject $Baseline
    $targetMap = Convert-ObjectToFlatMap -InputObject $Target
    $allKeys = @($baselineMap.Keys + $targetMap.Keys | Sort-Object -Unique)
    $added = @()
    $removed = @()
    $changed = @()

    foreach ($key in $allKeys) {
        $hasBase = $baselineMap.ContainsKey($key)
        $hasTarget = $targetMap.ContainsKey($key)

        if (-not $hasBase -and $hasTarget) {
            $added += [pscustomobject][ordered]@{
                Path = $key
                FriendlyPath = Get-FriendlyPath -Path $key
                Value = $targetMap[$key]
            }
            continue
        }

        if ($hasBase -and -not $hasTarget) {
            $removed += [pscustomobject][ordered]@{
                Path = $key
                FriendlyPath = Get-FriendlyPath -Path $key
                Value = $baselineMap[$key]
            }
            continue
        }

        if ($baselineMap[$key] -ne $targetMap[$key]) {
            $changed += [pscustomobject][ordered]@{
                Path = $key
                FriendlyPath = Get-FriendlyPath -Path $key
                Before = $baselineMap[$key]
                After = $targetMap[$key]
            }
        }
    }

    return [pscustomobject][ordered]@{
        BaselineId = Get-SafeText -Value $Baseline.Metadata.SnapshotId
        BaselineCreatedAt = Get-SafeText -Value $Baseline.Metadata.CreatedAt
        BaselineComputer = Get-SafeText -Value $Baseline.Metadata.ComputerName
        TargetId = Get-SafeText -Value $Target.Metadata.SnapshotId
        TargetCreatedAt = Get-SafeText -Value $Target.Metadata.CreatedAt
        TargetComputer = Get-SafeText -Value $Target.Metadata.ComputerName
        ChangedSections = @(Get-ChangedSections -Baseline $Baseline -Target $Target)
        Added = @($added | Sort-Object FriendlyPath)
        Removed = @($removed | Sort-Object FriendlyPath)
        Changed = @($changed | Sort-Object FriendlyPath)
    }
}

function Convert-CompareResultToText {
    param(
        [object]$CompareResult
    )

    $lines = @(
        '========================================================='
        '             SNAPSHOT KARSILASTIRMA RAPORU'
        '========================================================='
        ''
        'Temel Snapshot : {0}' -f $CompareResult.BaselineId
        'Temel Tarih    : {0}' -f $CompareResult.BaselineCreatedAt
        'Temel Bilg.    : {0}' -f $CompareResult.BaselineComputer
        ''
        'Yeni Snapshot  : {0}' -f $CompareResult.TargetId
        'Yeni Tarih     : {0}' -f $CompareResult.TargetCreatedAt
        'Yeni Bilg.     : {0}' -f $CompareResult.TargetComputer
        ''
        'Degisen Bolumler : {0}' -f ($(if ($CompareResult.ChangedSections.Count -gt 0) { $CompareResult.ChangedSections -join ', ' } else { 'Yok' }))
        'Eklenen Kayitlar : {0}' -f $CompareResult.Added.Count
        'Kaldirilanlar    : {0}' -f $CompareResult.Removed.Count
        'Degisen Alanlar  : {0}' -f $CompareResult.Changed.Count
        ''
        '=== DEGISEN BOLUMLER ==='
    )

    if ($CompareResult.ChangedSections.Count -gt 0) {
        foreach ($section in $CompareResult.ChangedSections) {
            $lines += '- {0}' -f $section
        }
    }
    else {
        $lines += '- Degisim bulunmadi'
    }

    $lines += ''
    $lines += '=== EKLENEN KAYITLAR ==='
    if ($CompareResult.Added.Count -gt 0) {
        foreach ($item in $CompareResult.Added) {
            $lines += '- {0} => {1}' -f $item.FriendlyPath, $item.Value
        }
    }
    else {
        $lines += '- Eklenen veri yok'
    }

    $lines += ''
    $lines += '=== KALDIRILAN KAYITLAR ==='
    if ($CompareResult.Removed.Count -gt 0) {
        foreach ($item in $CompareResult.Removed) {
            $lines += '- {0} => {1}' -f $item.FriendlyPath, $item.Value
        }
    }
    else {
        $lines += '- Kaldirilan veri yok'
    }

    $lines += ''
    $lines += '=== DEGISEN ALANLAR ==='
    if ($CompareResult.Changed.Count -gt 0) {
        foreach ($item in $CompareResult.Changed) {
            $lines += '- {0}' -f $item.FriendlyPath
            $lines += '  Once : {0}' -f $item.Before
            $lines += '  Sonra: {0}' -f $item.After
            $lines += ''
        }
    }
    else {
        $lines += '- Alan bazli degisim yok'
    }

    return ($lines -join [Environment]::NewLine)
}

function Convert-CompareResultToHtml {
    param(
        [object]$CompareResult
    )

    $text = Convert-CompareResultToText -CompareResult $CompareResult
    $encoded = [System.Net.WebUtility]::HtmlEncode($text)

    return @"
<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="utf-8" />
  <title>Snapshot Karsilastirma</title>
  <style>
    body {
      margin: 0;
      background: #f5f7fb;
      font-family: "Segoe UI", Arial, sans-serif;
      color: #172033;
    }
    .wrap {
      max-width: 1100px;
      margin: 24px auto;
      padding: 0 18px 30px;
    }
    .panel {
      background: #ffffff;
      border: 1px solid #d9e1ef;
      border-radius: 18px;
      box-shadow: 0 16px 36px rgba(15, 23, 42, 0.08);
      padding: 22px;
    }
    h1 {
      margin-top: 0;
      color: #14213d;
    }
    pre {
      white-space: pre-wrap;
      word-break: break-word;
      font-family: "Consolas", "Courier New", monospace;
      line-height: 1.6;
      background: #f8fafc;
      border-radius: 12px;
      padding: 18px;
      border: 1px solid #e2e8f0;
      margin: 0;
    }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="panel">
      <h1>Snapshot Karsilastirma</h1>
      <pre>$encoded</pre>
    </div>
  </div>
</body>
</html>
"@
}

function Save-ComparePackage {
    param(
        [object]$CompareResult
    )

    Initialize-Storage

    $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $baseName = 'Karsilastirma_{0}_{1}_vs_{2}' -f $stamp, $CompareResult.BaselineId, $CompareResult.TargetId
    $safeBaseName = $baseName -replace '[^A-Za-z0-9._-]', '_'
    $textPath = Get-UniqueFilePath -Directory $script:CompareFolder -BaseName $safeBaseName -Extension '.txt'
    $htmlPath = Get-UniqueFilePath -Directory $script:CompareFolder -BaseName $safeBaseName -Extension '.html'

    $text = Convert-CompareResultToText -CompareResult $CompareResult
    $html = Convert-CompareResultToHtml -CompareResult $CompareResult

    Set-Content -LiteralPath $textPath -Value $text -Encoding UTF8
    Set-Content -LiteralPath $htmlPath -Value $html -Encoding UTF8

    return [pscustomobject][ordered]@{
        TextPath = $textPath
        HtmlPath = $htmlPath
        TextReport = $text
        HtmlReport = $html
    }
}

function Load-SnapshotFromFile {
    param(
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Snapshot dosyasi bulunamadi: $Path"
    }

    return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-SnapshotCatalog {
    Initialize-Storage

    $items = foreach ($file in (Get-ChildItem -LiteralPath $script:SnapshotFolder -Filter '*.json' -File | Sort-Object LastWriteTime)) {
        try {
            $snapshot = Load-SnapshotFromFile -Path $file.FullName

            [pscustomobject][ordered]@{
                DisplayName = '{0} | {1} | {2} {3}' -f
                    (Get-SafeText -Value $snapshot.Metadata.CreatedAt),
                    (Get-SafeText -Value $snapshot.Metadata.ComputerName),
                    (Get-SafeText -Value $snapshot.System.Manufacturer),
                    (Get-SafeText -Value $snapshot.System.Model)
                SnapshotId = Get-SafeText -Value $snapshot.Metadata.SnapshotId
                CreatedAt = Get-SafeText -Value $snapshot.Metadata.CreatedAt
                ComputerName = Get-SafeText -Value $snapshot.Metadata.ComputerName
                Manufacturer = Get-SafeText -Value $snapshot.System.Manufacturer
                Model = Get-SafeText -Value $snapshot.System.Model
                Fingerprint = Get-SafeText -Value $snapshot.Fingerprint
                JsonPath = $file.FullName
                HtmlPath = Get-SafeText -Value $snapshot.Metadata.HtmlReportPath
                TextPath = Get-SafeText -Value $snapshot.Metadata.TextReportPath
                Snapshot = $snapshot
            }
        }
        catch {
        }
    }

    return @($items)
}

function Update-ListViewAndCombos {
    param(
        [System.Windows.Forms.ListView]$ListView,
        [System.Windows.Forms.ComboBox]$BaselineCombo,
        [System.Windows.Forms.ComboBox]$TargetCombo
    )

    $catalog = @(Get-SnapshotCatalog)

    $ListView.BeginUpdate()
    $ListView.Items.Clear()
    foreach ($item in $catalog) {
        $listItem = New-Object System.Windows.Forms.ListViewItem($item.CreatedAt)
        [void]$listItem.SubItems.Add($item.ComputerName)
        [void]$listItem.SubItems.Add(('{0} {1}' -f $item.Manufacturer, $item.Model).Trim())
        [void]$listItem.SubItems.Add(($item.Fingerprint.Substring(0, [Math]::Min(16, $item.Fingerprint.Length))))
        $listItem.Tag = $item
        [void]$ListView.Items.Add($listItem)
    }
    $ListView.EndUpdate()

    $BaselineCombo.BeginUpdate()
    $TargetCombo.BeginUpdate()
    $BaselineCombo.Items.Clear()
    $TargetCombo.Items.Clear()

    foreach ($item in $catalog) {
        [void]$BaselineCombo.Items.Add($item)
        [void]$TargetCombo.Items.Add($item)
    }

    $BaselineCombo.EndUpdate()
    $TargetCombo.EndUpdate()

    if ($catalog.Count -gt 0) {
        $BaselineCombo.DisplayMember = 'DisplayName'
        $TargetCombo.DisplayMember = 'DisplayName'
        $BaselineCombo.SelectedIndex = 0
        $TargetCombo.SelectedIndex = $catalog.Count - 1
    }
}

function Invoke-UiAction {
    param(
        [System.Windows.Forms.Form]$Form,
        [string]$StatusMessage,
        [scriptblock]$Action
    )

    try {
        $Form.UseWaitCursor = $true
        Set-Status -Message $StatusMessage
        [System.Windows.Forms.Application]::DoEvents()
        & $Action
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            $script:AppName,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null

        Set-Status -Message ('Hata: {0}' -f $_.Exception.Message)
    }
    finally {
        $Form.UseWaitCursor = $false
    }
}

function Show-MainForm {
    Initialize-Storage
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "$script:AppName v$script:AppVersion"
    $form.StartPosition = 'CenterScreen'
    $form.Size = New-Object System.Drawing.Size(1280, 860)
    $form.MinimumSize = New-Object System.Drawing.Size(1100, 760)
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 251)

    $topPanel = New-Object System.Windows.Forms.Panel
    $topPanel.Dock = 'Top'
    $topPanel.Height = 54
    $topPanel.Padding = New-Object System.Windows.Forms.Padding(10, 10, 10, 6)
    $topPanel.BackColor = [System.Drawing.Color]::FromArgb(20, 33, 61)

    $btnScan = New-Object System.Windows.Forms.Button
    $btnScan.Text = 'Canli Taramayi Yenile'
    $btnScan.AutoSize = $true
    $btnScan.Location = New-Object System.Drawing.Point(10, 11)
    $btnScan.BackColor = [System.Drawing.Color]::White

    $btnSaveSnapshot = New-Object System.Windows.Forms.Button
    $btnSaveSnapshot.Text = 'Snapshot Kaydet'
    $btnSaveSnapshot.AutoSize = $true
    $btnSaveSnapshot.Location = New-Object System.Drawing.Point(170, 11)
    $btnSaveSnapshot.BackColor = [System.Drawing.Color]::White

    $btnOpenFolder = New-Object System.Windows.Forms.Button
    $btnOpenFolder.Text = 'Arsiv Klasorunu Ac'
    $btnOpenFolder.AutoSize = $true
    $btnOpenFolder.Location = New-Object System.Drawing.Point(305, 11)
    $btnOpenFolder.BackColor = [System.Drawing.Color]::White

    $btnRefreshArchive = New-Object System.Windows.Forms.Button
    $btnRefreshArchive.Text = 'Listeyi Yenile'
    $btnRefreshArchive.AutoSize = $true
    $btnRefreshArchive.Location = New-Object System.Drawing.Point(456, 11)
    $btnRefreshArchive.BackColor = [System.Drawing.Color]::White

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = 'GUI + Snapshot + Karsilastirma'
    $titleLabel.ForeColor = [System.Drawing.Color]::White
    $titleLabel.AutoSize = $true
    $titleLabel.Location = New-Object System.Drawing.Point(610, 15)
    $titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)

    $topPanel.Controls.AddRange(@($btnScan, $btnSaveSnapshot, $btnOpenFolder, $btnRefreshArchive, $titleLabel))

    $statusStrip = New-Object System.Windows.Forms.StatusStrip
    $statusStrip.SizingGrip = $false
    $script:StatusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $script:StatusLabel.Text = 'Hazir'
    [void]$statusStrip.Items.Add($script:StatusLabel)

    $tabs = New-Object System.Windows.Forms.TabControl
    $tabs.Dock = 'Fill'
    $tabs.Font = New-Object System.Drawing.Font('Segoe UI', 10)

    $tabLive = New-Object System.Windows.Forms.TabPage
    $tabLive.Text = 'Canli Rapor'
    $tabLive.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 251)

    $tabArchive = New-Object System.Windows.Forms.TabPage
    $tabArchive.Text = 'Snapshot Arsivi'
    $tabArchive.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 251)

    $tabCompare = New-Object System.Windows.Forms.TabPage
    $tabCompare.Text = 'Karsilastirma'
    $tabCompare.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 251)

    $tabs.TabPages.AddRange(@($tabLive, $tabArchive, $tabCompare))

    $livePanel = New-Object System.Windows.Forms.Panel
    $livePanel.Dock = 'Fill'
    $livePanel.Padding = New-Object System.Windows.Forms.Padding(10)

    $txtQuickSummary = New-Object System.Windows.Forms.TextBox
    $txtQuickSummary.Multiline = $true
    $txtQuickSummary.Dock = 'Top'
    $txtQuickSummary.Height = 165
    $txtQuickSummary.ScrollBars = 'Vertical'
    $txtQuickSummary.ReadOnly = $true
    $txtQuickSummary.Font = New-Object System.Drawing.Font('Consolas', 11)
    $txtQuickSummary.BackColor = [System.Drawing.Color]::White

    $rtbLive = New-Object System.Windows.Forms.RichTextBox
    $rtbLive.Dock = 'Fill'
    $rtbLive.ReadOnly = $true
    $rtbLive.Font = New-Object System.Drawing.Font('Consolas', 10.5)
    $rtbLive.BackColor = [System.Drawing.Color]::White
    $rtbLive.WordWrap = $false

    $livePanel.Controls.Add($rtbLive)
    $livePanel.Controls.Add($txtQuickSummary)
    $tabLive.Controls.Add($livePanel)

    $archiveTopPanel = New-Object System.Windows.Forms.Panel
    $archiveTopPanel.Dock = 'Top'
    $archiveTopPanel.Height = 48
    $archiveTopPanel.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)

    $btnOpenSelectedHtml = New-Object System.Windows.Forms.Button
    $btnOpenSelectedHtml.Text = 'Secili HTML Ac'
    $btnOpenSelectedHtml.AutoSize = $true
    $btnOpenSelectedHtml.Location = New-Object System.Drawing.Point(10, 9)

    $btnOpenSelectedJson = New-Object System.Windows.Forms.Button
    $btnOpenSelectedJson.Text = 'Secili JSON Ac'
    $btnOpenSelectedJson.AutoSize = $true
    $btnOpenSelectedJson.Location = New-Object System.Drawing.Point(130, 9)

    $archiveTopPanel.Controls.AddRange(@($btnOpenSelectedHtml, $btnOpenSelectedJson))

    $archiveSplit = New-Object System.Windows.Forms.SplitContainer
    $archiveSplit.Dock = 'Fill'

    $listSnapshots = New-Object System.Windows.Forms.ListView
    $listSnapshots.Dock = 'Fill'
    $listSnapshots.View = 'Details'
    $listSnapshots.FullRowSelect = $true
    $listSnapshots.GridLines = $true
    $listSnapshots.MultiSelect = $false
    $listSnapshots.HideSelection = $false
    [void]$listSnapshots.Columns.Add('Tarih', 150)
    [void]$listSnapshots.Columns.Add('Bilgisayar', 130)
    [void]$listSnapshots.Columns.Add('Model', 210)
    [void]$listSnapshots.Columns.Add('Parmak Izi', 120)

    $archiveRightPanel = New-Object System.Windows.Forms.Panel
    $archiveRightPanel.Dock = 'Fill'
    $archiveRightPanel.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)

    $txtArchiveSummary = New-Object System.Windows.Forms.TextBox
    $txtArchiveSummary.Multiline = $true
    $txtArchiveSummary.Dock = 'Top'
    $txtArchiveSummary.Height = 165
    $txtArchiveSummary.ScrollBars = 'Vertical'
    $txtArchiveSummary.ReadOnly = $true
    $txtArchiveSummary.Font = New-Object System.Drawing.Font('Consolas', 10.5)
    $txtArchiveSummary.BackColor = [System.Drawing.Color]::White

    $rtbArchive = New-Object System.Windows.Forms.RichTextBox
    $rtbArchive.Dock = 'Fill'
    $rtbArchive.ReadOnly = $true
    $rtbArchive.Font = New-Object System.Drawing.Font('Consolas', 10)
    $rtbArchive.BackColor = [System.Drawing.Color]::White
    $rtbArchive.WordWrap = $false

    $archiveRightPanel.Controls.Add($rtbArchive)
    $archiveRightPanel.Controls.Add($txtArchiveSummary)

    $archiveSplit.Panel1.Controls.Add($listSnapshots)
    $archiveSplit.Panel2.Controls.Add($archiveRightPanel)

    $archivePanel = New-Object System.Windows.Forms.Panel
    $archivePanel.Dock = 'Fill'
    $archivePanel.Padding = New-Object System.Windows.Forms.Padding(10)
    $archivePanel.Controls.Add($archiveSplit)
    $archivePanel.Controls.Add($archiveTopPanel)
    $tabArchive.Controls.Add($archivePanel)

    $comparePanel = New-Object System.Windows.Forms.Panel
    $comparePanel.Dock = 'Fill'
    $comparePanel.Padding = New-Object System.Windows.Forms.Padding(10)

    $compareTop = New-Object System.Windows.Forms.Panel
    $compareTop.Dock = 'Top'
    $compareTop.Height = 95

    $lblBaseline = New-Object System.Windows.Forms.Label
    $lblBaseline.Text = 'Temel Snapshot (ilk yedek):'
    $lblBaseline.AutoSize = $true
    $lblBaseline.Location = New-Object System.Drawing.Point(8, 12)

    $cmbBaseline = New-Object System.Windows.Forms.ComboBox
    $cmbBaseline.DropDownStyle = 'DropDownList'
    $cmbBaseline.Location = New-Object System.Drawing.Point(210, 8)
    $cmbBaseline.Width = 650

    $lblTarget = New-Object System.Windows.Forms.Label
    $lblTarget.Text = 'Sonraki Snapshot:'
    $lblTarget.AutoSize = $true
    $lblTarget.Location = New-Object System.Drawing.Point(8, 48)

    $cmbTarget = New-Object System.Windows.Forms.ComboBox
    $cmbTarget.DropDownStyle = 'DropDownList'
    $cmbTarget.Location = New-Object System.Drawing.Point(210, 44)
    $cmbTarget.Width = 650

    $btnCompare = New-Object System.Windows.Forms.Button
    $btnCompare.Text = 'Karsilastir'
    $btnCompare.AutoSize = $true
    $btnCompare.Location = New-Object System.Drawing.Point(885, 7)

    $btnSaveCompare = New-Object System.Windows.Forms.Button
    $btnSaveCompare.Text = 'Karsilastirmayi Kaydet'
    $btnSaveCompare.AutoSize = $true
    $btnSaveCompare.Location = New-Object System.Drawing.Point(885, 43)

    $compareTop.Controls.AddRange(@(
        $lblBaseline, $cmbBaseline,
        $lblTarget, $cmbTarget,
        $btnCompare, $btnSaveCompare
    ))

    $rtbCompare = New-Object System.Windows.Forms.RichTextBox
    $rtbCompare.Dock = 'Fill'
    $rtbCompare.ReadOnly = $true
    $rtbCompare.Font = New-Object System.Drawing.Font('Consolas', 10.5)
    $rtbCompare.BackColor = [System.Drawing.Color]::White
    $rtbCompare.WordWrap = $false

    $comparePanel.Controls.Add($rtbCompare)
    $comparePanel.Controls.Add($compareTop)
    $tabCompare.Controls.Add($comparePanel)

    $form.Controls.Add($tabs)
    $form.Controls.Add($topPanel)
    $form.Controls.Add($statusStrip)

    $refreshCurrentView = {
        $snapshot = Get-InventorySnapshot
        $script:CurrentSnapshot = $snapshot
        $script:CurrentTextReport = Convert-SnapshotToText -Snapshot $snapshot
        $script:CurrentHtmlReport = Convert-SnapshotToHtml -Snapshot $snapshot
        $txtQuickSummary.Text = Get-SnapshotQuickSummary -Snapshot $snapshot
        $rtbLive.Text = $script:CurrentTextReport
        $tabs.SelectedTab = $tabLive
        Set-Status -Message 'Canli tarama tamamlandi'
    }

    $loadSelectedSnapshot = {
        if ($listSnapshots.SelectedItems.Count -eq 0) {
            return
        }

        $selected = $listSnapshots.SelectedItems[0].Tag
        $snapshot = Load-SnapshotFromFile -Path $selected.JsonPath
        $txtArchiveSummary.Text = Get-SnapshotQuickSummary -Snapshot $snapshot
        $rtbArchive.Text = Convert-SnapshotToText -Snapshot $snapshot
        Set-Status -Message ('Secili snapshot yuklendi: {0}' -f $selected.SnapshotId)
    }

    $btnScan.Add_Click({
        Invoke-UiAction -Form $form -StatusMessage 'Canli tarama yenileniyor...' -Action $refreshCurrentView
    })

    $btnSaveSnapshot.Add_Click({
        Invoke-UiAction -Form $form -StatusMessage 'Snapshot kaydediliyor...' -Action {
            if ($null -eq $script:CurrentSnapshot) {
                & $refreshCurrentView
            }

            $result = Save-SnapshotPackage -Snapshot $script:CurrentSnapshot
            $script:CurrentTextReport = $result.TextReport
            $script:CurrentHtmlReport = $result.HtmlReport
            $rtbLive.Text = $result.TextReport
            $txtQuickSummary.Text = Get-SnapshotQuickSummary -Snapshot $script:CurrentSnapshot

            Update-ListViewAndCombos -ListView $listSnapshots -BaselineCombo $cmbBaseline -TargetCombo $cmbTarget
            Set-Status -Message ('Snapshot kaydedildi: {0}' -f $result.JsonPath)

            [System.Windows.Forms.MessageBox]::Show(
                "Snapshot kaydedildi.`r`n`r`nJSON: $($result.JsonPath)`r`nTXT : $($result.TextPath)`r`nHTML: $($result.HtmlPath)",
                $script:AppName,
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        }
    })

    $btnOpenFolder.Add_Click({
        Start-Process $script:BaseFolder
    })

    $btnRefreshArchive.Add_Click({
        Invoke-UiAction -Form $form -StatusMessage 'Snapshot listesi yenileniyor...' -Action {
            Update-ListViewAndCombos -ListView $listSnapshots -BaselineCombo $cmbBaseline -TargetCombo $cmbTarget
            Set-Status -Message 'Snapshot listesi guncellendi'
        }
    })

    $listSnapshots.Add_SelectedIndexChanged($loadSelectedSnapshot)
    $listSnapshots.Add_DoubleClick($loadSelectedSnapshot)

    $btnOpenSelectedHtml.Add_Click({
        if ($listSnapshots.SelectedItems.Count -eq 0) {
            return
        }

        $selected = $listSnapshots.SelectedItems[0].Tag
        if ($selected.HtmlPath -and (Test-Path -LiteralPath $selected.HtmlPath)) {
            Start-Process $selected.HtmlPath
        }
    })

    $btnOpenSelectedJson.Add_Click({
        if ($listSnapshots.SelectedItems.Count -eq 0) {
            return
        }

        $selected = $listSnapshots.SelectedItems[0].Tag
        if ($selected.JsonPath -and (Test-Path -LiteralPath $selected.JsonPath)) {
            Start-Process $selected.JsonPath
        }
    })

    $btnCompare.Add_Click({
        Invoke-UiAction -Form $form -StatusMessage 'Snapshotlar karsilastiriliyor...' -Action {
            if ($cmbBaseline.SelectedItem -eq $null -or $cmbTarget.SelectedItem -eq $null) {
                throw 'Karsilastirma icin iki snapshot secmelisiniz.'
            }

            $baselineItem = [object]$cmbBaseline.SelectedItem
            $targetItem = [object]$cmbTarget.SelectedItem

            $baselineSnapshot = Load-SnapshotFromFile -Path $baselineItem.JsonPath
            $targetSnapshot = Load-SnapshotFromFile -Path $targetItem.JsonPath

            $script:LastCompareResult = Compare-Snapshots -Baseline $baselineSnapshot -Target $targetSnapshot
            $rtbCompare.Text = Convert-CompareResultToText -CompareResult $script:LastCompareResult
            $tabs.SelectedTab = $tabCompare
            Set-Status -Message 'Karsilastirma tamamlandi'
        }
    })

    $btnSaveCompare.Add_Click({
        Invoke-UiAction -Form $form -StatusMessage 'Karsilastirma raporu kaydediliyor...' -Action {
            if ($null -eq $script:LastCompareResult) {
                throw 'Kaydetmeden once bir karsilastirma calistirin.'
            }

            $result = Save-ComparePackage -CompareResult $script:LastCompareResult
            Set-Status -Message ('Karsilastirma kaydedildi: {0}' -f $result.TextPath)

            [System.Windows.Forms.MessageBox]::Show(
                "Karsilastirma raporu kaydedildi.`r`n`r`nTXT : $($result.TextPath)`r`nHTML: $($result.HtmlPath)",
                $script:AppName,
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
        }
    })

    $form.Add_Shown({
        $availableWidth = $archiveSplit.ClientSize.Width
        $archiveSplit.Panel1MinSize = 320
        $archiveSplit.Panel2MinSize = 420

        if ($availableWidth -gt ($archiveSplit.Panel1MinSize + $archiveSplit.Panel2MinSize)) {
            $desired = 430
            $maxAllowed = $availableWidth - $archiveSplit.Panel2MinSize
            $archiveSplit.SplitterDistance = [Math]::Max($archiveSplit.Panel1MinSize, [Math]::Min($desired, $maxAllowed))
        }
    })

    Invoke-UiAction -Form $form -StatusMessage 'Ilk tarama baslatiliyor...' -Action {
        & $refreshCurrentView
        Update-ListViewAndCombos -ListView $listSnapshots -BaselineCombo $cmbBaseline -TargetCombo $cmbTarget
        if ($listSnapshots.Items.Count -gt 0) {
            $listSnapshots.Items[0].Selected = $true
        }
    }

    [void]$form.ShowDialog()
}

Initialize-Storage

if ($NoGui) {
    if ($BaselineSnapshotPath -and $TargetSnapshotPath) {
        $baselineSnapshot = Load-SnapshotFromFile -Path $BaselineSnapshotPath
        $targetSnapshot = Load-SnapshotFromFile -Path $TargetSnapshotPath
        $compareResult = Compare-Snapshots -Baseline $baselineSnapshot -Target $targetSnapshot
        $compareText = Convert-CompareResultToText -CompareResult $compareResult
        Write-Host $compareText
        $savedCompare = Save-ComparePackage -CompareResult $compareResult
        Write-Host ''
        Write-Host 'Karsilastirma kaydedildi:'
        Write-Host ('TXT : {0}' -f $savedCompare.TextPath)
        Write-Host ('HTML: {0}' -f $savedCompare.HtmlPath)
        return
    }

    $snapshot = Get-InventorySnapshot

    if ($SaveSnapshot) {
        $savedSnapshot = Save-SnapshotPackage -Snapshot $snapshot
        Write-Host ''
        Write-Host 'Snapshot kaydedildi:'
        Write-Host ('JSON : {0}' -f $savedSnapshot.JsonPath)
        Write-Host ('TXT  : {0}' -f $savedSnapshot.TextPath)
        Write-Host ('HTML : {0}' -f $savedSnapshot.HtmlPath)
        if ($savedSnapshot.BatteryReportPath) {
            Write-Host ('BAT  : {0}' -f $savedSnapshot.BatteryReportPath)
        }
        return
    }

    Write-Host (Convert-SnapshotToText -Snapshot $snapshot)
    return
}

Show-MainForm
