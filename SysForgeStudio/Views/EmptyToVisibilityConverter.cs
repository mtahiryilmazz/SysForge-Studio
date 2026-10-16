using System;
using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace SysForgeStudio.Views
{
    public class EmptyToVisibilityConverter : IValueConverter
    {
        public static EmptyToVisibilityConverter Instance { get; } = new EmptyToVisibilityConverter();

        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            if (value == null)
                return Visibility.Visible;
            if (value is bool b)
                return b ? Visibility.Visible : Visibility.Collapsed;
            if (value is string s)
                return string.IsNullOrEmpty(s) ? Visibility.Visible : Visibility.Collapsed;
            string str = value.ToString() ?? "";
            return string.IsNullOrEmpty(str) ? Visibility.Visible : Visibility.Collapsed;
        }

        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        {
            throw new NotImplementedException();
        }
    }
}