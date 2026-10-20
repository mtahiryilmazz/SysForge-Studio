using System;
using System.Diagnostics;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using SysForgeStudio.Models;
using SysForgeStudio.Services;

namespace SysForgeStudio.Views
{
    public partial class ITTechServiceView : UserControl
    {
        private System.Windows.Threading.DispatcherTimer? _syncTimer;
        private InventoryItem? _liveMachineItem;

        public ITTechServiceView()
        {
            InitializeComponent();
            Loaded += async (s, e) =>
            {
                RefreshData();
                await LoadEnterprisePrintersAsync();
                UpdateWebStatus();
                StartSyncTimer();
            };

            Unloaded += (s, e) =>
            {
                _syncTimer?.Stop();
            };

            ITWebDashboardService.Instance.StateChanged += isRunning =>
            {
                Dispatcher.Invoke(UpdateWebStatus);
            };

            ITServiceDatabase.Instance.DataChanged += () =>
            {
                Dispatcher.InvokeAsync(RefreshData);
            };
        }

        private void StartSyncTimer()
        {
            if (_syncTimer == null)
            {
                _syncTimer = new System.Windows.Threading.DispatcherTimer
                {
                    Interval = TimeSpan.FromSeconds(2.5)
                };
                _syncTimer.Tick += (s, e) => RefreshData();
            }
            _syncTimer.Start();
        }

        private void UpdateWebStatus()
        {
            bool isRunning = ITWebDashboardService.Instance.IsRunning;
            if (isRunning)
            {
                TxtWebStatus.Text = $"🟢 Web Konsolu ÇALIŞIYOR: http://localhost:{ITWebDashboardService.Instance.Port}/ (Ağdaki cihazlar erişebilir)";
                BtnToggleWeb.Content = "⏹️ Web Panelini Durdur";
                BtnOpenBrowser.IsEnabled = true;
            }
            else
            {
                TxtWebStatus.Text = "⚪ Web sunucusu kapalı. Başlatıldığında ağdaki cihazlar web üzerinden arıza kaydı bırakabilir.";
                BtnToggleWeb.Content = "▶️ Web Panelini Başlat";
                BtnOpenBrowser.IsEnabled = false;
            }
        }

        private void BtnToggleWeb_Click(object sender, RoutedEventArgs e)
        {
            if (ITWebDashboardService.Instance.IsRunning)
            {
                ITWebDashboardService.Instance.Stop();
            }
            else
            {
                ITWebDashboardService.Instance.Start(5000);
            }
            UpdateWebStatus();
        }

        private void BtnOpenBrowser_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = $"http://localhost:{ITWebDashboardService.Instance.Port}/",
                    UseShellExecute = true
                });
            }
            catch { }
        }

        private void BtnRefresh_Click(object sender, RoutedEventArgs e)
        {
            RefreshData();
        }

        private async void BtnRefreshPrinters_Click(object sender, RoutedEventArgs e) => await LoadEnterprisePrintersAsync();

        private async System.Threading.Tasks.Task LoadEnterprisePrintersAsync()
        {
            try
            {
                var previous = (CmbEnterprisePrinters.SelectedItem as PrinterItem)?.Name;
                var printers = await ToolkitEngine.Instance.GetPrintersAsync();
                CmbEnterprisePrinters.ItemsSource = printers;
                CmbEnterprisePrinters.SelectedItem = printers.FirstOrDefault(p => p.Name == previous) ?? printers.FirstOrDefault();
                TxtEnterprisePrinterStatus.Text = printers.Count == 0
                    ? $"Yazıcı bulunamadı. Spooler: {ToolkitEngine.Instance.GetSpoolerStatus()}"
                    : $"{printers.Count} yazıcı bulundu. Spooler: {ToolkitEngine.Instance.GetSpoolerStatus()}";
            }
            catch (Exception ex)
            {
                TxtEnterprisePrinterStatus.Text = $"Yazıcı listesi alınamadı: {ex.Message}";
            }
        }

        private async void BtnPrinterDiagnosis_Click(object sender, RoutedEventArgs e)
        {
            var results = await ToolkitEngine.Instance.RunFullDiagnosisAsync();
            int issues = results.Count(item => item.Status != "OK");
            TxtEnterprisePrinterStatus.Text = $"Tanılama tamamlandı: {results.Count} kontrol, {issues} uyarı/hata. Ayrıntılar Canlı Kayıtlar bölümünde.";
        }

        private async void BtnPrinterRpcFix_Click(object sender, RoutedEventArgs e)
        {
            if (!ConfirmPrinterRepair("RPC 0x11b/709 kayıt defteri ayarları değiştirilecek. Devam edilsin mi?")) return;
            await ToolkitEngine.Instance.FixRpc11bAnd709Async();
            TxtEnterprisePrinterStatus.Text = "RPC / 0x11b / 709 onarımı tamamlandı. Gerekirse bilgisayarı yeniden başlatın.";
        }

        private async void BtnPointPrintFix_Click(object sender, RoutedEventArgs e)
        {
            if (!ConfirmPrinterRepair("Point & Print güvenlik ilkeleri değiştirilecek ve sürücü yükleme izinleri gevşetilecek. Devam edilsin mi?")) return;
            await ToolkitEngine.Instance.FixPointAndPrintAsync();
            TxtEnterprisePrinterStatus.Text = "Point & Print ayarları uygulandı.";
        }

        private async void BtnSpoolerReset_Click(object sender, RoutedEventArgs e)
        {
            if (!ConfirmPrinterRepair("Yazdırma kuyruğu durdurulup bekleyen işler temizlenecek. Devam edilsin mi?")) return;
            await ToolkitEngine.Instance.ResetSpoolerAsync();
            TxtEnterprisePrinterStatus.Text = $"Spooler: {ToolkitEngine.Instance.GetSpoolerStatus()}";
        }

        private async void BtnPrinterFirewall_Click(object sender, RoutedEventArgs e)
        {
            if (!ConfirmPrinterRepair("Dosya ve yazıcı paylaşımı için güvenlik duvarı kuralları etkinleştirilecek, ağ profili Özel yapılacak. Devam edilsin mi?")) return;
            await ToolkitEngine.Instance.FixFirewallAsync();
            TxtEnterprisePrinterStatus.Text = "Yazıcı paylaşım güvenlik duvarı ayarları uygulandı.";
        }

        private async void BtnPrintTestPage_Click(object sender, RoutedEventArgs e)
        {
            if (CmbEnterprisePrinters.SelectedItem is not PrinterItem printer) { TxtEnterprisePrinterStatus.Text = "Önce listeden bir yazıcı seçin."; return; }
            await ToolkitEngine.Instance.PrintTestPageAsync(printer.Name);
            TxtEnterprisePrinterStatus.Text = $"Sınama sayfası gönderildi: {printer.Name}";
        }

        private void BtnOpenPrinterQueue_Click(object sender, RoutedEventArgs e)
        {
            if (CmbEnterprisePrinters.SelectedItem is not PrinterItem printer) { TxtEnterprisePrinterStatus.Text = "Önce listeden bir yazıcı seçin."; return; }
            ToolkitEngine.Instance.OpenQueue(printer.Name);
        }

        private bool ConfirmPrinterRepair(string message) =>
            MessageBox.Show(message, "PRN Kurumsal Onarım", MessageBoxButton.YesNo, MessageBoxImage.Warning) == MessageBoxResult.Yes;

        public void RefreshData()
        {
            try
            {
                // Departments
                var depts = ITServiceDatabase.Instance.GetDepartments();
                ListDepartments.ItemsSource = depts;

                // Explicit target department combo for adding units
                var prevTargetDeptId = (CmbUnitTargetDept.SelectedItem as DepartmentItem)?.Id;
                CmbUnitTargetDept.ItemsSource = null;
                CmbUnitTargetDept.ItemsSource = depts;
                if (prevTargetDeptId.HasValue && depts.Any(d => d.Id == prevTargetDeptId.Value))
                {
                    CmbUnitTargetDept.SelectedItem = depts.FirstOrDefault(d => d.Id == prevTargetDeptId.Value);
                }
                else if (depts.Count > 0)
                {
                    CmbUnitTargetDept.SelectedIndex = 0;
                }

                // Ticket form department combo
                var prevDeptId = (CmbDepts.SelectedItem as DepartmentItem)?.Id;
                CmbDepts.ItemsSource = null;
                CmbDepts.ItemsSource = depts;
                if (prevDeptId.HasValue && depts.Any(d => d.Id == prevDeptId.Value))
                {
                    CmbDepts.SelectedItem = depts.FirstOrDefault(d => d.Id == prevDeptId.Value);
                }
                else if (depts.Count > 0)
                {
                    CmbDepts.SelectedIndex = 0;
                }

                // Tickets
                var tickets = ITServiceDatabase.Instance.GetTickets();
                ListTickets.ItemsSource = tickets;
                TxtOpenTicketsCount.Text = tickets.Count(t => t.Status != "Çözüldü").ToString();
                TxtResolvedTicketsCount.Text = tickets.Count(t => t.Status == "Çözüldü").ToString();

                // Inventory
                var inventory = ITServiceDatabase.Instance.GetInventory();
                ListInventory.ItemsSource = inventory;
                TxtInventoryCount.Text = inventory.Count.ToString();
                PnlEmptyInventory.Visibility = inventory.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
                ListInventory.Visibility = inventory.Count > 0 ? Visibility.Visible : Visibility.Collapsed;

                LoadLiveMachineSpecsAsync();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Veritabanı okuma hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BtnAddDept_Click(object sender, RoutedEventArgs e)
        {
            string name = TxtNewDeptName.Text.Trim();
            if (string.IsNullOrWhiteSpace(name))
            {
                MessageBox.Show("Lütfen eklenecek müdürlük adını yazın.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            try
            {
                ITServiceDatabase.Instance.AddDepartment(name);
                TxtNewDeptName.Text = "";
                RefreshData();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Müdürlük eklenemedi: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BtnDeleteDept_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is int deptId)
            {
                if (MessageBox.Show("Bu müdürlüğü ve bağlı tüm alt birimlerini silmek istiyor musunuz?", "Onay", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes)
                {
                    ITServiceDatabase.Instance.DeleteDepartment(deptId);
                    RefreshData();
                }
            }
        }

        private void BtnAddUnit_Click(object sender, RoutedEventArgs e)
        {
            if (CmbUnitTargetDept.SelectedItem is not DepartmentItem selDept)
            {
                MessageBox.Show("Lütfen alt birimin ekleneceği hedef müdürlüğü açılır kutudan seçin.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            string unitName = TxtNewUnitName.Text.Trim();
            if (string.IsNullOrWhiteSpace(unitName))
            {
                MessageBox.Show("Lütfen alt birim adını yazın.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            try
            {
                ITServiceDatabase.Instance.AddUnit(selDept.Id, unitName);
                TxtNewUnitName.Text = "";
                int savedDeptId = selDept.Id;
                RefreshData();
                // Retain selected department in target combo
                var reloaded = ITServiceDatabase.Instance.GetDepartments();
                CmbUnitTargetDept.SelectedItem = reloaded.FirstOrDefault(d => d.Id == savedDeptId);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Birim eklenemedi: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BtnDeleteUnit_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is int unitId)
            {
                if (MessageBox.Show("Bu alt birimi silmek istediğinizden emin misiniz?", "Onay", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes)
                {
                    ITServiceDatabase.Instance.DeleteUnit(unitId);
                    RefreshData();
                }
            }
        }

        private void BtnAddTicket_Click(object sender, RoutedEventArgs e)
        {
            string person = TxtNewPerson.Text.Trim();
            string desc = TxtNewDesc.Text.Trim();
            string deptName = (CmbDepts.SelectedItem as DepartmentItem)?.Name ?? "Genel";
            string internalNum = TxtNewInternal.Text.Trim();
            string issueType = (CmbNewIssueType.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? "Genel";

            if (string.IsNullOrWhiteSpace(person) || string.IsNullOrWhiteSpace(desc))
            {
                MessageBox.Show("Lütfen Personel Adı ve Açıklama alanlarını doldurun.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            try
            {
                ITServiceDatabase.Instance.AddTicket(new TicketItem
                {
                    PersonnelName = person,
                    Department = deptName,
                    Unit = "-",
                    InternalNumber = string.IsNullOrWhiteSpace(internalNum) ? "-" : internalNum,
                    IssueType = issueType,
                    Priority = "Normal",
                    Description = desc,
                    Status = "Açık"
                });

                TxtNewPerson.Text = "";
                TxtNewInternal.Text = "";
                TxtNewDesc.Text = "";

                RefreshData();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Kayıt eklenemedi: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BtnResolveTicket_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is int ticketId)
            {
                string? note = ShowResolutionPrompt();
                if (note == null)
                {
                    // İptal edildi
                    return;
                }

                ITServiceDatabase.Instance.ResolveTicket(ticketId, note);
                RefreshData();
            }
        }

        private string? ShowResolutionPrompt()
        {
            var promptWin = new Window
            {
                Title = "Arıza Çözüm Açıklaması",
                Width = 460,
                Height = 260,
                WindowStartupLocation = WindowStartupLocation.CenterScreen,
                Background = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(30, 30, 30)),
                Foreground = System.Windows.Media.Brushes.White,
                ResizeMode = ResizeMode.NoResize,
                WindowStyle = WindowStyle.ToolWindow
            };

            var grid = new Grid { Margin = new Thickness(16) };
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
            grid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
            grid.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

            var lbl = new TextBlock
            {
                Text = "Yapılan müdahale ve çözüm açıklamasını giriniz (İsteğe bağlı):",
                FontSize = 13,
                Foreground = System.Windows.Media.Brushes.LightGray,
                Margin = new Thickness(0, 0, 0, 10),
                TextWrapping = TextWrapping.Wrap
            };
            Grid.SetRow(lbl, 0);

            var txt = new TextBox
            {
                AcceptsReturn = true,
                TextWrapping = TextWrapping.Wrap,
                VerticalContentAlignment = VerticalAlignment.Top,
                HorizontalContentAlignment = HorizontalAlignment.Left,
                TextAlignment = TextAlignment.Left,
                Background = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(42, 42, 42)),
                Foreground = System.Windows.Media.Brushes.White,
                BorderBrush = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(65, 65, 65)),
                Padding = new Thickness(8),
                FontSize = 13
            };
            Grid.SetRow(txt, 1);

            var btnPanel = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                HorizontalAlignment = HorizontalAlignment.Right,
                Margin = new Thickness(0, 12, 0, 0)
            };
            Grid.SetRow(btnPanel, 2);

            var btnCancel = new Button
            {
                Content = "İptal",
                Width = 80,
                Height = 32,
                Margin = new Thickness(0, 0, 8, 0),
                Background = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(55, 55, 55)),
                Foreground = System.Windows.Media.Brushes.White,
                BorderThickness = new Thickness(0)
            };
            btnCancel.Click += (s, e) => promptWin.DialogResult = false;

            var btnOk = new Button
            {
                Content = "Arızayı Kapat",
                Width = 110,
                Height = 32,
                Background = new System.Windows.Media.SolidColorBrush(System.Windows.Media.Color.FromRgb(16, 124, 65)),
                Foreground = System.Windows.Media.Brushes.White,
                FontWeight = FontWeights.Bold,
                BorderThickness = new Thickness(0)
            };
            btnOk.Click += (s, e) => promptWin.DialogResult = true;

            btnPanel.Children.Add(btnCancel);
            btnPanel.Children.Add(btnOk);

            grid.Children.Add(lbl);
            grid.Children.Add(txt);
            grid.Children.Add(btnPanel);

            promptWin.Content = grid;
            promptWin.Loaded += (s, e) => txt.Focus();

            if (promptWin.ShowDialog() == true)
            {
                return txt.Text.Trim();
            }
            return null;
        }

        private void BtnDeleteTicket_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is int ticketId)
            {
                if (MessageBox.Show("Bu destek kaydını silmek istediğinizden emin misiniz?", "Onay", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes)
                {
                    ITServiceDatabase.Instance.DeleteTicket(ticketId);
                    RefreshData();
                }
            }
        }

        private async void LoadLiveMachineSpecsAsync()
        {
            try
            {
                if (_liveMachineItem == null)
                {
                    _liveMachineItem = await System.Threading.Tasks.Task.Run(() =>
                        ITServiceDatabase.CollectLiveMachineSpecs());
                }
                UpdateLiveMachineInfoBox(_liveMachineItem);
            }
            catch
            {
                // Ignore collection errors in background
            }
        }

        private void UpdateLiveMachineInfoBox(InventoryItem item)
        {
            if (item == null) return;

            TxtLiveMachineHeader.Text = $"Cihaz: {item.DeviceName} | IP: {item.IpAddress} | Domain: {item.DomainWorkgroup}";
            TxtLiveBrandModel.Text = $"{item.Brand} {item.Model}";
            TxtLiveCpuRam.Text = $"CPU: {item.Processor} | RAM: {item.Ram}";
            TxtLiveMotherboard.Text = $"Anakart: {item.Motherboard} | Disk: {item.Disk}";
            TxtLiveOsBuild.Text = $"{item.OperatingSystem} (Build: {item.WindowsBuild})";
            TxtLiveSecurity.Text = $"Güvenlik: {item.SecuritySoftware} | Uptime: {item.Uptime}";
            TxtLiveBios.Text = $"BIOS: {item.BiosVersion}";
            TxtLiveIpMac.Text = $"IP: {item.IpAddress} | MAC: {item.MacAddress}";
            TxtLiveUser.Text = $"Kullanıcı: {item.AssignedPersonnel} ({item.Department})";
            TxtLiveSerial.Text = $"Seri: {item.SerialNumber} | HWID: {item.HardwareId}";
        }

        private void BtnShowLiveSpecsPopup_Click(object sender, RoutedEventArgs e)
        {
            var targetItem = _liveMachineItem ?? ITServiceDatabase.CollectLiveMachineSpecs();
            var win = new InventoryDetailWindow(targetItem)
            {
                Owner = Window.GetWindow(this)
            };
            win.ShowDialog();
        }

        private void BtnAutoRegisterPc_Click(object sender, RoutedEventArgs e)
        {
            string dept = (CmbDepts.SelectedItem as DepartmentItem)?.Name ?? "Bilgi İşlem";
            try
            {
                ITServiceDatabase.Instance.AutoRegisterCurrentMachine(dept);
                _liveMachineItem = null;
                RefreshData();
                MessageBox.Show("Bu bilgisayarın detaylı donanım ve yazılım bilgileri (Marka, Model, BIOS Seri No, HWID, Anakart, CPU, RAM, OS Build, Ağ) başarıyla envantere eklendi!", "Başarılı", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Kayıt hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BtnShowInventoryDetail_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is InventoryItem item)
            {
                var win = new InventoryDetailWindow(item)
                {
                    Owner = Window.GetWindow(this)
                };
                win.ShowDialog();
            }
        }

        private void BtnDeleteInventory_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is int itemId)
            {
                if (MessageBox.Show("Bu envanter kaydını silmek istediğinizden emin misiniz?", "Onay", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes)
                {
                    ITServiceDatabase.Instance.DeleteInventory(itemId);
                    RefreshData();
                }
            }
        }
    }
}
