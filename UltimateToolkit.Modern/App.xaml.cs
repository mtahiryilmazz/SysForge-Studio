using System;
using System.Diagnostics;
using System.IO;
using System.Security.Principal;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Threading;

namespace UltimateToolkit.Modern
{
    public partial class App : Application
    {
        public static string LogDirectory { get; private set; } = string.Empty;
        public static string CrashLogFile { get; private set; } = string.Empty;

        protected override void OnStartup(StartupEventArgs e)
        {
            SetupCrashLogger();
            base.OnStartup(e);
        }

        private void SetupCrashLogger()
        {
            try
            {
                string baseDir = AppDomain.CurrentDomain.BaseDirectory;
                LogDirectory = Path.Combine(baseDir, "logs");
                Directory.CreateDirectory(LogDirectory);

                CrashLogFile = Path.Combine(LogDirectory, $"crash_log_{DateTime.Now:yyyyMMdd}.log");
            }
            catch
            {
                // Fallback to TEMP folder if base directory is write-protected
                LogDirectory = Path.Combine(Path.GetTempPath(), "UltimateToolkit_Logs");
                Directory.CreateDirectory(LogDirectory);
                CrashLogFile = Path.Combine(LogDirectory, $"crash_log_{DateTime.Now:yyyyMMdd}.log");
            }

            // 1. UI Thread Exceptions
            DispatcherUnhandledException += App_DispatcherUnhandledException;

            // 2. Non-UI / Background Thread Exceptions
            AppDomain.CurrentDomain.UnhandledException += CurrentDomain_UnhandledException;

            // 3. Unobserved Asynchronous Task Exceptions
            TaskScheduler.UnobservedTaskException += TaskScheduler_UnobservedTaskException;
        }

        private void App_DispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
        {
            LogFatalError("UI Dispatcher Hatası", e.Exception);

            // Display informative dialog
            MessageBox.Show(
                $"Program çalışırken beklenmeyen bir hata oluştu:\n\n{e.Exception.Message}\n\nHata detayları günlüğe kaydedildi:\n{CrashLogFile}",
                "Uygulama Hatası Yakalandı",
                MessageBoxButton.OK,
                MessageBoxImage.Error);

            // Prevent crash if possible
            e.Handled = true;
        }

        private void CurrentDomain_UnhandledException(object sender, UnhandledExceptionEventArgs e)
        {
            if (e.ExceptionObject is Exception ex)
            {
                LogFatalError("AppDomain Kritik Hatası (Fatal)", ex);
            }
            else
            {
                LogRawError("AppDomain Bilinmeyen Nesne Hatası: " + e.ExceptionObject?.ToString());
            }
        }

        private void TaskScheduler_UnobservedTaskException(object? sender, UnobservedTaskExceptionEventArgs e)
        {
            LogFatalError("Asenkron Görev (Task) Hatası", e.Exception);
            e.SetObserved(); // Prevent task exception from killing process
        }

        public static void LogFatalError(string source, Exception ex)
        {
            try
            {
                bool isAdmin = false;
                try
                {
                    using var id = WindowsIdentity.GetCurrent();
                    isAdmin = new WindowsPrincipal(id).IsInRole(WindowsBuiltInRole.Administrator);
                }
                catch { }

                var sb = new StringBuilder();
                sb.AppendLine("================================================================================");
                sb.AppendLine($"[HATA ZAMANI]  : {DateTime.Now:yyyy-MM-dd HH:mm:ss.fff}");
                sb.AppendLine($"[KAYNAK]       : {source}");
                sb.AppendLine($"[HATA TÜRÜ]    : {ex.GetType().FullName}");
                sb.AppendLine($"[HATA MESAJI]  : {ex.Message}");
                sb.AppendLine($"[YÖNETİCİ Mİ?] : {(isAdmin ? "Evet (Administrator)" : "Hayır (Standard User)")}");
                sb.AppendLine($"[İŞLETİM SİST.]: {Environment.OSVersion} ({(Environment.Is64BitOperatingSystem ? "64-bit" : "32-bit")})");
                sb.AppendLine($"[.NET SÜRÜMÜ]  : {Environment.Version}");
                sb.AppendLine($"[BELLEK (RAM)] : {Process.GetCurrentProcess().WorkingSet64 / (1024 * 1024)} MB");
                sb.AppendLine("--------------------------------------------------------------------------------");
                sb.AppendLine("[ÇAĞRI YIĞINI (STACK TRACE)]:");
                sb.AppendLine(ex.StackTrace ?? "Stack trace bulunamadı.");

                if (ex.InnerException != null)
                {
                    sb.AppendLine("--------------------------------------------------------------------------------");
                    sb.AppendLine($"[İÇ HATA (INNER EXCEPTION)] : {ex.InnerException.GetType().FullName}");
                    sb.AppendLine($"[İÇ HATA MESAJI]           : {ex.InnerException.Message}");
                    sb.AppendLine(ex.InnerException.StackTrace ?? "");
                }

                sb.AppendLine("================================================================================");
                sb.AppendLine();

                File.AppendAllText(CrashLogFile, sb.ToString(), Encoding.UTF8);
            }
            catch { }
        }

        public static void LogRawError(string message)
        {
            try
            {
                string text = $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] [RAW ERR] {message}{Environment.NewLine}";
                File.AppendAllText(CrashLogFile, text, Encoding.UTF8);
            }
            catch { }
        }
    }
}
