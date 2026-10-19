using System;
using System.IO;
using System.Text;
using System.Threading.Tasks;

namespace SysForgeStudio
{
    /// <summary>
    /// .NET Framework 4.8 uyumluluk yardimcilari (Windows 7 - 11, x86/x64).
    /// .NET 5+ ile gelen ama Framework'te bulunmayan API'ler icin ince katman.
    /// </summary>
    public static class FileCompat
    {
        public static Task WriteAllTextAsync(string path, string contents, Encoding encoding)
            => Task.Run(() => File.WriteAllText(path, contents, encoding));

        public static Task<string> ReadAllTextAsync(string path, Encoding encoding)
            => Task.Run(() => File.ReadAllText(path, encoding));
    }

    public static class StringCompatExtensions
    {
        public static bool Contains(this string source, string value, StringComparison comparison)
            => source.IndexOf(value, comparison) >= 0;

        public static bool Contains(this string source, char value)
            => source.IndexOf(value) >= 0;

        public static string[] Split(this string source, char separator, StringSplitOptions options)
            => source.Split(new[] { separator }, options);
    }
}
