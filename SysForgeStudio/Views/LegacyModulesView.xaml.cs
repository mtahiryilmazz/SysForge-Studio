using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using SysForgeStudio.Models;
using SysForgeStudio.Services;

namespace SysForgeStudio.Views
{
    public partial class LegacyModulesView : UserControl
    {
        public event Action? NavigateToPrintersRequested;
        private List<ModuleCategory> _allCategories = new();
        private ModuleCategory? _selectedCategory;

        public LegacyModulesView()
        {
            InitializeComponent();
            Loaded += LegacyModulesView_Loaded;
            ITWebDashboardService.Instance.StateChanged += _ =>
            {
                Dispatcher.Invoke(RefreshV6Status);
            };
        }

        private void LegacyModulesView_Loaded(object sender, RoutedEventArgs e)
        {
            LoadCategories();
            RefreshV6Status();
            RefreshSandboxPaths();
        }

        private void LoadCategories()
        {
            _allCategories = ModuleCatalogService.Instance.GetAllCategories();
            LstCategories.ItemsSource = null;
            LstCategories.ItemsSource = _allCategories;

            if (_allCategories.Count > 0)
            {
                LstCategories.SelectedIndex = 0;
            }
        }

        private void EngineTab_Checked(object sender, RoutedEventArgs e)
        {
            if (PnlV5View == null || PnlV6View == null || PnlPrinterView == null || PnlSandboxView == null) return;

            PnlV5View.Visibility = Visibility.Collapsed;
            PnlV6View.Visibility = Visibility.Collapsed;
            PnlPrinterView.Visibility = Visibility.Collapsed;
            PnlSandboxView.Visibility = Visibility.Collapsed;

            if (TabV5Modules.IsChecked == true)
            {
                PnlV5View.Visibility = Visibility.Visible;
            }
            else if (TabV6Web.IsChecked == true)
            {
                PnlV6View.Visibility = Visibility.Visible;
                RefreshV6Status();
            }
            else if (TabPrinterAnalyzer.IsChecked == true)
            {
                PnlPrinterView.Visibility = Visibility.Visible;
            }
            else if (TabSandbox.IsChecked == true)
            {
                PnlSandboxView.Visibility = Visibility.Visible;
                RefreshSandboxPaths();
            }
        }

        private void LstCategories_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (LstCategories.SelectedItem is ModuleCategory cat)
            {
                _selectedCategory = cat;
                TxtCurrentCatIcon.Text = cat.Icon;
                TxtCurrentCatTitle.Text = $"[{cat.Code}] {cat.Name}";
                TxtCurrentCatDesc.Text = cat.Description;
                TxtCurrentCatCount.Text = $"{cat.Actions.Count} Araç";

                IcActions.ItemsSource = null;
                IcActions.ItemsSource = cat.Actions;
            }
        }

        private void TxtSearchCategories_TextChanged(object sender, TextChangedEventArgs e)
        {
            string q = TxtSearchCategories.Text.Trim().ToLowerInvariant();
            if (string.IsNullOrEmpty(q))
            {
                LstCategories.ItemsSource = _allCategories;
            }
            else
            {
                var filtered = _allCategories.Where(c =>
                    c.Name.ToLowerInvariant().Contains(q) ||
                    c.Code.ToLowerInvariant().Contains(q) ||
                    c.Group.ToLowerInvariant().Contains(q) ||
                    c.Actions.Any(a => a.Title.ToLowerInvariant().Contains(q) || a.Description.ToLowerInvariant().Contains(q))).ToList();

                LstCategories.ItemsSource = filtered;
            }

            if (LstCategories.Items.Count > 0 && LstCategories.SelectedIndex == -1)
            {
                LstCategories.SelectedIndex = 0;
            }
        }

        private async void BtnExecuteAction_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.DataContext is ModuleAction action)
            {
                btn.IsEnabled = false;
                TxtTerminalOutput.AppendText($"\n>>> [{DateTime.Now:HH:mm:ss}] {action.Title} başlatılıyor...\n");
                TxtTerminalOutput.ScrollToEnd();

                try
                {
                    await ModuleCatalogService.Instance.ExecuteActionAsync(action, line =>
                    {
                        Dispatcher.Invoke(() =>
                        {
                            TxtTerminalOutput.AppendText(line + "\n");
                            TxtTerminalOutput.ScrollToEnd();
                        });
                    });
                }
                finally
                {
                    btn.IsEnabled = true;
                    // Refresh bindings to show updated status
                    if (_selectedCategory != null)
                    {
                        var actions = _selectedCategory.Actions;
                        IcActions.ItemsSource = null;
                        IcActions.ItemsSource = actions;
                    }
                }
            }
        }

        private void BtnCopyOutput_Click(object sender, RoutedEventArgs e)
        {
            Clipboard.SetText(TxtTerminalOutput.Text);
            MessageBox.Show("Terminal çıktısı panoya kopyalandı.", "Kopyalandı", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void BtnClearOutput_Click(object sender, RoutedEventArgs e)
        {
            TxtTerminalOutput.Text = $"[Temizlendi] {DateTime.Now:HH:mm:ss}\n";
        }

        #region V6 & Printer & Sandbox Controls

        private void RefreshV6Status()
        {
            bool running = ToolkitEngine.Instance.IsV6Running();
            TxtV6StatusIndicator.Text = running ? "Sunucu Durumu: AKTİF (Port 9999 Dinleniyor)" : "Sunucu Durumu: KAPALI";
            TxtV6StatusIndicator.Foreground = running ? (Brush)FindResource("PtSuccess") : new SolidColorBrush(Color.FromRgb(148, 163, 184));
            if (TxtV6Url != null)
            {
                TxtV6Url.Text = "http://localhost:9999/dashboard.html";
            }
        }

        private async void BtnStartV6_Click(object sender, RoutedEventArgs e)
        {
            BtnStartV6.IsEnabled = false;
            try
            {
                await ToolkitEngine.Instance.StartV6WebDashboardAsync();
                RefreshV6Status();
            }
            finally
            {
                BtnStartV6.IsEnabled = true;
            }
        }

        private void BtnStopV6_Click(object sender, RoutedEventArgs e)
        {
            ToolkitEngine.Instance.StopV6WebDashboard();
            RefreshV6Status();
        }

        private void BtnLaunchPrinterAnalyzer_Click(object sender, RoutedEventArgs e)
        {
            ToolkitEngine.Instance.LaunchPrinterAnalyzer();
        }

        private void BtnGoPrinters_Click(object sender, RoutedEventArgs e)
        {
            NavigateToPrintersRequested?.Invoke();
        }

        private void RefreshSandboxPaths()
        {
            var paths = ToolkitEngine.Instance.DetectSandboxDirectories();
            LstSandboxPaths.ItemsSource = null;
            LstSandboxPaths.ItemsSource = paths;
        }

        private void BtnCleanSandbox_Click(object sender, RoutedEventArgs e)
        {
            var res = MessageBox.Show(
                "Sandbox ve geçici klasörlerdeki kalıntılar temizlenecek.\n\nOnaylıyor musunuz?",
                "Geçici Kalıntı Temizliği",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);

            if (res == MessageBoxResult.Yes)
            {
                ToolkitEngine.Instance.CleanSandboxDirectories();
                RefreshSandboxPaths();
                MessageBox.Show("Geçici kalıntılar temizlendi.", "Bilgi", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        #endregion
    }
}
