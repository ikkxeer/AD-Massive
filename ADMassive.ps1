Clear-Host

# Elevación a Administrador
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))  
{  
  $arguments = "& '" +$myinvocation.mycommand.definition + "'"
  Start-Process powershell.exe -Verb runAs -ArgumentList $arguments
  Break
}

# Change Window Name
$host.ui.RawUI.WindowTitle = "AD Massive"

# Function to create space in terminal
function Space {
    Write-Host ""
}

function SelectADPath {
    function Add-Node { 
        param ( 
            $selectedNode, 
            $name
        ) 
        $newNode = New-Object System.Windows.Forms.TreeNode  
        $newNode.Name = $name 
        $newNode.Text = $name 
        $selectedNode.Nodes.Add($newNode) | Out-Null 
        return $newNode 
    } 
    
    function Get-NextLevel {
        param (
            $selectedNode,
            $dn
        )
    
        $OUs = Get-ADObject -Filter 'ObjectClass -eq "organizationalUnit" -or ObjectClass -eq "container"' -SearchScope OneLevel -SearchBase $dn
    
        if ($OUs -eq $null) {
            $node = Add-Node $selectedNode $dn
        } else {
            $node = Add-Node $selectedNode $dn
            
            $OUs | ForEach-Object {
                Get-NextLevel $node $_.distinguishedName
            }
        }
    }
    
    function Build-TreeView { 
        if ($treeNodes) {  
            $treeview1.Nodes.remove($treeNodes) 
            $form1.Refresh() 
        } 
        
        $treeNodes = New-Object System.Windows.Forms.TreeNode 
        $treeNodes.text = "Active Directory Hierarchy" 
        $treeNodes.Name = "Active Directory Hierarchy" 
        $treeNodes.Tag = "root" 
        $treeView1.Nodes.Add($treeNodes) | Out-Null 
        
        $treeView1.add_AfterSelect({ 
            $textbox1.Text = $this.SelectedNode.Name
        }) 
        
        # Generar nodos de las unidades organizativas
        $OUs = Get-NextLevel $treeNodes $strDomainDN
        
        $treeNodes.Expand() 
    } 
    
    # Función para seleccionar la ruta
    function Select-OUPath {
        $selectedOUPath = $textbox1.Text
        $form1.Close()
        return $selectedOUPath
    }
    
    # Función para generar el formulario principal
    function GenerateForm { 
        # Importar las Assemblies
        Import-Module ActiveDirectory
        [reflection.assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null 
        [reflection.assembly]::LoadWithPartialName("System.Drawing") | Out-Null 
        $objIPProperties = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
        $strDNSDomain = $objIPProperties.DomainName.ToLower()
        $strDomainDN = $strDNSDomain.toString().split('.'); foreach ($strVal in $strDomainDN) {$strTemp += "dc=$strVal,"}; $strDomainDN = $strTemp.TrimEnd(",").toLower()
        
        # Generated Form Objects 
        $form1 = New-Object System.Windows.Forms.Form 
        $treeView1 = New-Object System.Windows.Forms.TreeView 
        $label1 = New-Object System.Windows.Forms.Label
        $textbox1 = New-Object System.Windows.Forms.TextBox
        $buttonSelectOU = New-Object System.Windows.Forms.Button
        
        # Generated Event Script Blocks 
        $buttonSelectOU_OnClick = { 
            $global:selectedOUPath = Select-OUPath
        } 
        
        $OnLoadForm_StateCorrection= { 
            Build-TreeView 
        } 
        
        # Generated Form Code 
        $form1.Text = "AD Massive" 
        $form1.Name = "form1" 
        $form1.DataBindings.DefaultDataSourceUpdateMode = 0 
        $form1.ClientSize = New-Object System.Drawing.Size(400,500) 
        
        $treeView1.Size = New-Object System.Drawing.Size(350,375)
        $treeView1.Name = "treeView1" 
        $treeView1.Location = New-Object System.Drawing.Size(15,15)
        $treeView1.DataBindings.DefaultDataSourceUpdateMode = 0 
        $treeView1.TabIndex = 0 
        $form1.Controls.Add($treeView1)
        
        $label1.Name = "label1" 
        $label1.Location = New-Object System.Drawing.Size(15,400)
        $label1.Size = New-Object System.Drawing.Size(350,20)
        $label1.Text = "Selected Value:"
        $form1.Controls.Add($label1) 
        
        $textbox1.Name = "textbox1" 
        $textbox1.Location = New-Object System.Drawing.Size(15,425)
        $textbox1.Size = New-Object System.Drawing.Size(350,20)
        $textbox1.Text = ""
        $form1.Controls.Add($textbox1) 
        
        $buttonSelectOU.Name = "buttonSelectOU"
        $buttonSelectOU.Location = New-Object System.Drawing.Point(15, 450)
        $buttonSelectOU.Size = New-Object System.Drawing.Size(100, 30)
        $buttonSelectOU.Text = "Select Path"
        $buttonSelectOU.Add_Click($buttonSelectOU_OnClick)
        $form1.Controls.Add($buttonSelectOU)
        
        #endregion Generated Form Code 
        
        # Save the initial state of the form 
        $InitialFormWindowState = $form1.WindowState 
        # Init the OnLoad event to correct the initial state of the form 
        $form1.add_Load($OnLoadForm_StateCorrection) 
        # Show the Form 
        $form1.ShowDialog()| Out-Null 
    } 
    
    # Call the Function 
    GenerateForm    
}

# Function Organizational Unit Creation
function CreateOUMassive {
    Clear-Host
    $NumberOfOU = Read-Host "How many Organizational Units you want to create"
    $RangeOU = 1..$NumberOfOU
    Space
    foreach($i in $RangeOU) {
    try {
        $OU = Read-Host "Write here the name of the OU number $i"
        Space
        Write-Host "Select the path to the Organizational Unit in the following Window..." -ForegroundColor Yellow
        Space
        SelectADPath
        Write-Host "The Path selected is $global:selectedOUPath"
        Space
        $Path = $selectedOUPath
        New-ADOrganizationalUnit -name $OU -Path $Path
        Write-Host "$OU was created correctlly!" -ForegroundColor Green
        Space
    }
    catch {
        Write-Host "An error occurred trying to create $OU" -ForegroundColor Red
        Space
    }
    }
Pause
}

# Function Users Creation
function CreateUsersMassive {
    Clear-Host
    $NumberOfUsers = Read-Host "How many users you want to create in this new OU"
    Space
    $RangeUsers = 1..$NumberOfUsers
    
    # Getting User Information
    $Name = Read-Host "Name for all the Users"
    Space
    $AccountPassword = Read-Host "Password for the Users" -AsSecureString
    Space
    $Description = Read-Host "Description for the Users"
    Space
    $Group = Read-Host "Name of the group for the Users"
    Space
    Write-Host "Select the path to the users in the following Window..." -ForegroundColor Yellow
    Space
    SelectADPath
    Write-Host "The Path selected is $global:selectedOUPath"
    Space
    $Path = $selectedOUPath
    $Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain() | Select-Object -expandproperty Forest | Select-Object -ExpandProperty Name

    foreach($i in $RangeUsers) {
        $NewName = $Name + "_$i"
        Write-Host "User created $NewName!" -ForegroundColor Green
        Space
        New-ADUser -GivenName $NewName -DisplayName $NewName -Name $NewName -SamAccountName $NewName -Description $Description -AccountPassword $AccountPassword -Path $Path -UserPrincipalName ($NewName + '@' + $Domain) -Enabled $true -PasswordNeverExpires $true
        Add-ADGroupMember -Identity $Group -Members $NewName
    }
Pause
}

# Function Group Creation
function CreateADGroup {
    Clear-Host
    $NumberOfGroups = Read-Host "How many Groups you want to create"
    $RangeGroups = 1..$NumberOfGroups
    Space
    foreach($i in $RangeGroups) {
    try {
        $GroupName = Read-Host "Write here the name of the Group number $i"
        Space
        $Scope = Read-Host "Write here the scope: 0 DomainLocal, 1 Global, 2 Universal"
        Space
        Write-Host "Select the path to the Group in the following Window..." -ForegroundColor Yellow
        Space
        SelectADPath
        Write-Host "The Path selected is $global:selectedOUPath"
        Space
        $Path = $selectedOUPath
        New-ADGroup -Name $GroupName -DisplayName $GroupName -GroupScope $Scope -Path $Path
        Write-Host "$GroupName was created correctlly!" -ForegroundColor Green
        Space
    }
    catch {
        Write-Host "An error occurred trying to create $GroupName" -ForegroundColor Red
        Space
    }
    }
Pause
}

function MassiveGroupAdd {
Add-Type -AssemblyName System.Windows.Forms

$form = New-Object System.Windows.Forms.Form
$form.Text = "AD Massive"
$form.Size = New-Object System.Drawing.Size(400,400)
$form.StartPosition = "CenterScreen"

# CheckedListBox para seleccionar usuarios
$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Location = New-Object System.Drawing.Point(10,10)
$checkedListBox.Size = New-Object System.Drawing.Size(300,200)

# Obtener todos los usuarios
$Usuarios = Get-ADUser -Filter * | Select-Object -ExpandProperty SamAccountName

foreach ($Usuario in $Usuarios) {
    [void]$checkedListBox.Items.Add($Usuario)
}

$buttonAgregar = New-Object System.Windows.Forms.Button
$buttonAgregar.Location = New-Object System.Drawing.Point(10,220)
$buttonAgregar.Size = New-Object System.Drawing.Size(120,30)
$buttonAgregar.Text = "Add Users"
$buttonAgregar.Add_Click({
    $UsuariosSeleccionados = $checkedListBox.CheckedItems
    $Grupo = $comboBox.SelectedItem

    foreach ($Usuario in $UsuariosSeleccionados) {
        Add-ADGroupMember -Identity $Grupo -Members $Usuario
    }

    [System.Windows.Forms.MessageBox]::Show("Users added to group successfully!")
})

$comboBox = New-Object System.Windows.Forms.ComboBox
$comboBox.Location = New-Object System.Drawing.Point(150,220)
$comboBox.Size = New-Object System.Drawing.Size(200,30)

# Obtener todos los grupos
$Grupos = Get-ADGroup -Filter * | Select-Object -ExpandProperty Name

# Agregar grupos al cuadro
foreach ($Grupo in $Grupos) {
    [void]$comboBox.Items.Add($Grupo)
}

$form.Controls.Add($checkedListBox)
$form.Controls.Add($buttonAgregar)
$form.Controls.Add($comboBox)
$form.ShowDialog() | Out-Null
}

# Mostrar el menú de opciones
do {
    Clear-Host
    Write-Host @"
    _      ___                        _           
    /_\    /   \   /\/\   __ _ ___ ___(_)_   _____ 
   //_\\  / /\ /  /    \ / _` / __/ __| \ \ / / _ \
  /  _  \/ /_//  / /\/\ \ (_| \__ \__ \ |\ V /  __/
  \_/ \_/___,'   \/    \/\__,_|___/___/_| \_/ \___|
                                                   
"@ -ForegroundColor Yellow
Space
    Write-Host "--------------------------------------------------" -ForegroundColor Yellow
    Space
    Write-Host "1. Create AD Users Massively" -ForegroundColor Yellow
    Space
    Write-Host "2. Create Organizational Units Massively" -ForegroundColor Yellow
    Space
    Write-Host "3. Create AD Groups Massively" -ForegroundColor Yellow
    Space
    Write-Host "4. Add Massive Users to Group" -ForegroundColor Yellow
    Space
    Write-Host "5. Exit" -ForegroundColor Yellow
    Space
    $opcion = Read-Host "Select an option (1-5)"

    switch ($opcion) {
        1 { CreateUsersMassive }
        2 { CreateOUMassive }
        3 { CreateADGroup }
        4 { MassiveGroupAdd }
        5 { break }
        default { Write-Host "Invalid option. Please select a valid option." -ForegroundColor Red }
    }
} while ($opcion -ne "5")