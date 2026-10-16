import subprocess

import subprocess
import logging

class PrintersModule:
    def get_installed_printers(self):
        try:
            # PowerShell çıktısı Türkçe karakter içerebilir (CP857/1254). errors='replace' ile çökme önlenir.
            cmd = ['powershell', '-Command', 'Get-Printer | Select-Object Name, PortName, DriverName, PrinterStatus | ConvertTo-Json']
            result = subprocess.run(cmd, capture_output=True, text=True, errors='replace')
            
            if result.returncode == 0 and result.stdout and result.stdout.strip():
                import json
                try:
                    printers = json.loads(result.stdout)
                    if isinstance(printers, list):
                        return printers
                    if isinstance(printers, dict):
                        return [printers]
                    return []
                except Exception as je:
                    logging.error(f"JSON Ayrıştırma Hatası: {je}")
                    return []
            return []
        except Exception as e:
            logging.error(f"Yazici listesi alinamadi: {e}")
            return []

    def run_ps(self, command):
        try:
            # -NoProfile ve -ExecutionPolicy Bypass ile en temiz PS ortamı
            proc = subprocess.run(
                ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command],
                capture_output=True, text=True, errors="replace"
            )
            stdout = proc.stdout.strip() if proc.stdout else ""
            stderr = proc.stderr.strip() if proc.stderr else ""
            return proc.returncode == 0, stdout, stderr
        except Exception as e:
            logging.error(f"PowerShell hatasi: {e}")
            return False, "", str(e)

    def fix_rpc(self):
        script = r"""
        $path = 'HKLM:\System\CurrentControlSet\Control\Print'
        if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name 'RpcAuthnLevelPrivacyEnabled' -Value 0 -Type DWord -Force
        $path2 = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC'
        if (!(Test-Path $path2)) { New-Item -Path $path2 -Force | Out-Null }
        Set-ItemProperty -Path $path2 -Name 'RpcUseNamedPipeProtocol' -Value 1 -Type DWord -Force
        """
        return self.run_ps(script)

    def fix_point_and_print(self):
        script = r"""
        $pnp = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint'
        if (!(Test-Path $pnp)) { New-Item -Path $pnp -Force | Out-Null }
        Set-ItemProperty -Path $pnp -Name 'RestrictDriverInstallationToAdministrators' -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $pnp -Name 'NoWarningNoElevationOnInstall' -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $pnp -Name 'UpdatePromptSettings' -Value 0 -Type DWord -Force
        """
        return self.run_ps(script)

    def fix_spooler(self):
        script = r"""
        Stop-Service Spooler -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Get-ChildItem "$env:SystemRoot\System32\spool\PRINTERS" -Include *.spl,*.shd -Recurse -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
        Start-Service Spooler -ErrorAction SilentlyContinue
        """
        return self.run_ps(script)

    def fix_network(self):
        script = r"""
        netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes | Out-Null
        Enable-NetFirewallRule -DisplayGroup 'File and Printer Sharing' -ErrorAction SilentlyContinue
        """
        return self.run_ps(script)

    def fix_services(self):
        script = r"""
        foreach ($svcName in 'RpcSs','RpcEptMapper','LanmanServer','LanmanWorkstation','FDPHost','FDResPub','Spooler') {
            Set-Service -Name $svcName -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name $svcName -ErrorAction SilentlyContinue
        }
        """
        return self.run_ps(script)

    def fix_709(self):
        script = r"""
        $lsa = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
        Set-ItemProperty -Path $lsa -Name 'restrictanonymous' -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $lsa -Name 'restrictanonymoussam' -Value 0 -Type DWord -Force
        Set-ItemProperty -Path $lsa -Name 'LmCompatibilityLevel' -Value 3 -Type DWord -Force
        Set-ItemProperty -Path $lsa -Name 'NoLMHash' -Value 1 -Type DWord -Force
        """
        return self.run_ps(script)

    def run_auto_fix(self, role="Belirsiz"):
        res = []
        res.append(("RPC Fix", self.fix_rpc()[0]))
        res.append(("Point & Print", self.fix_point_and_print()[0]))
        res.append(("Spooler", self.fix_spooler()[0]))
        res.append(("Ağ Güvenlik Duvarı", self.fix_network()[0]))
        res.append(("Windows Servisleri", self.fix_services()[0]))
        res.append(("0x00000709 & Uyumluluk", self.fix_709()[0]))
        return res
