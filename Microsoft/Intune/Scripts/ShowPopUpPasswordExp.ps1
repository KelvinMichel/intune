#Ajuste as seguintes linhas 15 (Coloque uma URL com uma imagem publica para servir de logo da sua empresa) e 22(ajuste o nome do botão da janela).

# Define o XAML para a janela do WPF
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Aviso de redefinição de senha" Height="150" Width="400" WindowStartupLocation="CenterScreen" Topmost="True" ResizeMode="NoResize" WindowStyle="none">
    <Grid>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto" /> <!-- Coluna para a imagem -->
            <ColumnDefinition Width="*" />    <!-- Coluna para o texto -->
        </Grid.ColumnDefinitions>
        
        <!-- Logo da URL pública -->
        <Image Source="Coloque uma logo com URL pública aqui" Width="80" Height="80" VerticalAlignment="Top" Margin="10"/>

        <!-- Texto da mensagem -->
        <TextBlock Grid.Column="1" Text="A senha do seu computador está próxima do vencimento! Não perca seu acesso, por favor, atualize-a acessando o portal abaixo." HorizontalAlignment="Center" VerticalAlignment="top" Margin="10" FontSize="16" TextWrapping="Wrap" />

        
        <!-- Botão para acessar o site -->
        <Button Name="btnAcessarSite" Content="Coloque o Nome do Botão Aqui" Grid.ColumnSpan="2" HorizontalAlignment="Center" VerticalAlignment="Bottom" Width="150" Height="40" Margin="10,5,10,10" /> <!-- Reduzido o Margin -->
    </Grid>
</Window>
"@

# Cria a função para abrir o site ao clicar no botão e fechar a janela
$scriptBlock = {
    Start-Process ""  # Substitua pelo seu link
    $window.Close()
}

# Carrega o XAML e cria a interface gráfica
Add-Type -AssemblyName PresentationFramework
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Conecta o evento ao botão
$btnAcessarSite = $window.FindName("btnAcessarSite")
$btnAcessarSite.Add_Click($scriptBlock)

# Exibe a janela
$window.ShowDialog()
