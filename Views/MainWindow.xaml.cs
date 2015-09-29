// --------------------------------------------------------------------------------------------------------------------
// <copyright file="MainWindow.xaml.cs" company="">
//
// </copyright>
// --------------------------------------------------------------------------------------------------------------------

namespace UpgradeServer
{
    using System;
    using System.IO;
    using System.Management.Automation;
    using System.Text.RegularExpressions;
    using System.Windows;
    using System.Windows.Controls;

    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        /// <summary>
        /// The powershell host.
        /// </summary>
        private PowerShell powershellHost;

        /// <summary>
        /// The utility.
        /// </summary>
        private Utility utility;

        /// <summary>
        /// Initializes a new instance of the <see cref="MainWindow"/> class.
        /// </summary>
        public MainWindow()
        {
            InitializeComponent();

        }

        /// <summary>
        /// The production_run script_button_ click.
        /// </summary>
        /// <param name="sender">
        /// The sender.
        /// </param>
        /// <param name="e">
        /// The e.
        /// </param>
        private void production_runScript_button_Click(object sender, RoutedEventArgs e)
        {
            var host = Utility.PowershellHost;

            var article = this.utility.GetArtifactFiles();

            this.utility.UpdateServer(sender);

            /*
                currentEnvironment = [string]::Empty;
                

                if( !($this.Name -match '^[^_]+(?=_)'))
                {
                  return 
                }

                $currentEnvironment = $Matches.Values[0]

                $server_combobox =  (Get-Variable "$($currentEnvironment)_server_combobox" -ValueOnly)

                Update-Server -Server $server_combobox.SelectedItem -sourceIPAddress $Script:upgradeConfig.SourceIPAddress -artifactFile $Script:artifactFiles[$server_combobox.SelectedItem.PackageName].FilePath 

            */
        }

        /// <summary>
        /// The main window_ on loaded.
        /// </summary>
        /// <param name="sender">
        /// The sender.
        /// </param>
        /// <param name="e">
        /// The e.
        /// </param>
        private void MainWindow_OnLoaded(object sender, RoutedEventArgs e)
        {
            this.utility = new Utility(this);
            File.Create(Utility.TempLogFilePath);
            this.utility.AddServersToCombox();

            this.utility.StartFileWmiEvent();

            // result.ToList().ForEach(item => this.production_server_combobox.Items.Add(item));
        }



        /// <summary>
        /// The production_server_combobox_ selection changed.
        /// </summary>
        /// <param name="sender">
        /// The sender.
        /// </param>
        /// <param name="e">
        /// The e.
        /// </param>
        private void ServerCombobox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            var serverCombobox = sender as ComboBox;
            if (serverCombobox == null)
            {
                return;
            }
            var pattern = "^[^_]+(?=_)";
            var matches = Regex.Match(serverCombobox.Name, pattern);
            if (matches.Success)
            {
                if (matches.Value.Equals(Utility.Test))
                {
                    dynamic selectedItem = serverCombobox.SelectedItem;
                    this.test_IPAdress_value_label.Content = selectedItem.IPAddress;
                    this.test_formflextpart_value_label.Content = selectedItem.FormFlexPart;
                    this.test_include_toggle.IsChecked = selectedItem.IncludedInUpdate;
                    this.test_packageName_value_label.Content = selectedItem.PackageName;
                }
                else if (matches.Value.Equals(Utility.Production))
                {
                    dynamic selectedItem = serverCombobox.SelectedItem;
                    this.production_IPAdress_value_label.Content = selectedItem.IPAddress;
                    this.production_formflextpart_value_label.Content = selectedItem.FormFlexPart;
                    this.production_include_toggle.IsChecked = selectedItem.IncludedInUpdate;
                    this.production_packageName_value_label.Content = selectedItem.PackageName;
                }
            }

        }

        /// <summary>
        /// The window_ closed.
        /// </summary>
        /// <param name="sender">
        /// The sender.
        /// </param>
        /// <param name="e">
        /// The e.
        /// </param>
        private void Window_Closed(object sender, EventArgs e)
        {
            var fileContent = File.ReadAllText(Utility.TempLogFilePath);
            File.WriteAllText(Utility.LogFilePath, fileContent);
            File.Delete(Utility.TempLogFilePath);
        }

        /// <summary>
        /// The test_include_toggle_ checked.
        /// </summary>
        /// <param name="sender">
        /// The sender.
        /// </param>
        /// <param name="e">
        /// The e.
        /// </param>
        private void IncludeToggle_Checked(object sender, RoutedEventArgs e)
        {
            this.utility.CheckUnckeckIncludeInUpdate(sender, true);
        }

        /// <summary>
        /// The test_run script_button_ click.
        /// </summary>
        /// <param name="sender">
        /// The sender.
        /// </param>
        /// <param name="e">
        /// The e.
        /// </param>
        private void test_runScript_button_Click(object sender, RoutedEventArgs e)
        {
        }

        /// <summary>
        /// The test_run all_button_ click.
        /// </summary>
        /// <param name="sender">
        /// The sender.
        /// </param>
        /// <param name="e">
        /// The e.
        /// </param>
        private void test_runAll_button_Click(object sender, RoutedEventArgs e)
        {

        }

        private void IncludeToggle_Unchecked(object sender, RoutedEventArgs e)
        {
            this.utility.CheckUnckeckIncludeInUpdate(sender, false);

        }
    }
}