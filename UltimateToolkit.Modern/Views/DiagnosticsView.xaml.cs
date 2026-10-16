using System.Windows;
using System.Windows.Controls;
using UltimateToolkit.Modern.Services;

namespace UltimateToolkit.Modern.Views
{
    public partial class DiagnosticsView : UserControl
    {
        public DiagnosticsView()
        {
            InitializeComponent();
            Loaded += DiagnosticsView_Loaded;
        }

        private async void DiagnosticsView_Loaded(object sender, RoutedEventArgs e)
        {
            await RunDiagnosisAsync();
        }

        private async System.Threading.Tasks.Task RunDiagnosisAsync()
        {
            var results = await ToolkitEngine.Instance.RunFullDiagnosisAsync();
            DgDiag.ItemsSource = results;
        }

        private async void BtnRunDiag_Click(object sender, RoutedEventArgs e)
        {
            await RunDiagnosisAsync();
        }

        private async void BtnAutoRemediate_Click(object sender, RoutedEventArgs e)
        {
            await ToolkitEngine.Instance.RunSmartAutoWorkflowAsync();
            await RunDiagnosisAsync();
            MessageBox.Show("Otomatik çözüm uygulandı ve teşhis güncellendi.", "Başarılı", MessageBoxButton.OK, MessageBoxImage.Information);
        }
    }
}
