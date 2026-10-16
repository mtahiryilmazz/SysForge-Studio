using System;
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
            Loaded += (s, e) => RefreshData();
        }

        private void BtnRefresh_Click(object sender, RoutedEventArgs e)
        {
            RefreshData();
        }

        public void RefreshData()
        {
            try
            {
                var tickets = ITServiceDatabase.Instance.GetTickets();
                ListTickets.ItemsSource = tickets;

                int openCount = tickets.Count(t => t.Status != "Çözüldü");
                int resolvedCount = tickets.Count(t => t.Status == "Çözüldü");

                TxtOpenTicketsCount.Text = openCount.ToString();
                TxtResolvedTicketsCount.Text = resolvedCount.ToString();

                var inventory = ITServiceDatabase.Instance.GetInventory();
                ListInventory.ItemsSource = inventory;
                TxtInventoryCount.Text = inventory.Count.ToString();
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Veritabanı okuma hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private void BtnAddTicket_Click(object sender, RoutedEventArgs e)
        {
            string person = TxtNewPerson.Text.Trim();
            string dept = TxtNewDept.Text.Trim();
            string internalNum = TxtNewInternal.Text.Trim();
            string desc = TxtNewDesc.Text.Trim();
            string issueType = (CmbNewIssueType.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? "Genel";

            if (string.IsNullOrWhiteSpace(person) || string.IsNullOrWhiteSpace(desc))
            {
                MessageBox.Show("Lütfen en azından Personel Adı ve Açıklama alanlarını doldurun.", "Uyarı", MessageBoxButton.OK, MessageBoxImage.Warning);
                return;
            }

            try
            {
                ITServiceDatabase.Instance.AddTicket(new TicketItem
                {
                    PersonnelName = person,
                    Department = string.IsNullOrWhiteSpace(dept) ? "Genel" : dept,
                    InternalNumber = string.IsNullOrWhiteSpace(internalNum) ? "-" : internalNum,
                    IssueType = issueType,
                    Priority = "Normal",
                    Description = desc,
                    Status = "Açık"
                });

                TxtNewPerson.Text = "";
                TxtNewDept.Text = "";
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
                try
                {
                    ITServiceDatabase.Instance.UpdateTicketStatus(ticketId, "Çözüldü");
                    RefreshData();
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Güncelleme hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
        }

        private void BtnDeleteTicket_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button btn && btn.Tag is int ticketId)
            {
                if (MessageBox.Show("Bu destek kaydını silmek istediğinizden emin misiniz?", "Onay", MessageBoxButton.YesNo, MessageBoxImage.Question) == MessageBoxResult.Yes)
                {
                    try
                    {
                        ITServiceDatabase.Instance.DeleteTicket(ticketId);
                        RefreshData();
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Silme hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
                    }
                }
            }
        }

        private void BtnAutoRegisterPc_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                ITServiceDatabase.Instance.AutoRegisterCurrentMachine();
                RefreshData();
                MessageBox.Show("Bu bilgisayarın donanım kimliği (Marka, Model, BIOS Seri No ve IP) başarıyla envantere kaydedildi!", "Başarılı", MessageBoxButton.OK, MessageBoxImage.Information);
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
                    try
                    {
                        ITServiceDatabase.Instance.DeleteInventory(itemId);
                        RefreshData();
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show($"Silme hatası: {ex.Message}", "Hata", MessageBoxButton.OK, MessageBoxImage.Error);
                    }
                }
            }
        }
    }
}