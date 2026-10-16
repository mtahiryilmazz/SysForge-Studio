using System;
using System.Diagnostics;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using UltimateToolkit.Modern.Models;
using UltimateToolkit.Modern.Services;

namespace UltimateToolkit.Modern.Views
{
    public partial class ITTechServiceView : UserControl
    {
        public ITTechServiceView()
        {
            InitializeComponent();
            Loaded += (s, e) =>
            {
                RefreshData();
                UpdateWebStatus();
            };

            ITWebDashboardService.Instance.StateChanged += isRunning =>
            {
                Dispatcher.Invoke(UpdateWebStatus);
            };
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

        public void RefreshData()
        {
            try
            {
                // Departments
                var depts = ITServiceDatabase.Instance.GetDepartments();
                ListDepartments.ItemsSource = depts;
                CmbDepts.ItemsSource = depts;
                if (depts.Count > 0 && CmbDepts.SelectedIndex < 0)
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
                if (MessageBox.Show("Bu müdürlüğü ve bağlı alt birimlerini silmek istiyor musunuz?", "Onay", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes)
                {
                    ITServiceDatabase.Instance.DeleteDepartment(deptId);
                    RefreshData();
                }
            }
        }

        private void BtnAddUnit_Click(object sender, RoutedEventArgs e)
        {
            if (CmbDepts.SelectedItem is not DepartmentItem selDept)
            {
                MessageBox.Show("Lütfen önce sol açılır kutudan bir müdürlük seçin.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
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
                RefreshData();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Birim eklenemedi: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
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
                ITServiceDatabase.Instance.UpdateTicketStatus(ticketId, "Çözüldü");
                RefreshData();
            }
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

        private void BtnAutoRegisterPc_Click(object sender, RoutedEventArgs e)
        {
            string dept = (CmbDepts.SelectedItem as DepartmentItem)?.Name ?? "Bilgi İşlem";
            try
            {
                ITServiceDatabase.Instance.AutoRegisterCurrentMachine(dept);
                RefreshData();
                MessageBox.Show("Bu bilgisayarın donanım kimliği (Marka, Model, BIOS Seri No, IP) başarıyla envantere eklendi!", "Başarılı", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Kayıt hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
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