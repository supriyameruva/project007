# Variables
$resourceGroupName = "MyTestResourceGroup"
$location = "EastUS"
$vmName = "MyTestVM"
$vnetName = "MyTestVNet"
$subnetName = "MyTestSubnet"
$publicIpName = "MyTestPublicIP"
$nicName = "MyTestNIC"

# Step 1: Check if Resource Group Exists or Create a New One
if (!(Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating resource group..."
    New-AzResourceGroup -Name $resourceGroupName -Location $location
} else {
    Write-Host "Resource group already exists. Skipping creation."
}

# Step 2: Create Virtual Network and Subnet
Write-Host "Creating virtual network..."
$vnet = New-AzVirtualNetwork -ResourceGroupName $resourceGroupName `
  -Location $location `
  -Name $vnetName `
  -AddressPrefix "10.0.0.0/16"

if ($vnet -ne $null) {
    Write-Host "Creating subnet..."
    $subnet = Add-AzVirtualNetworkSubnetConfig -Name $subnetName `
      -AddressPrefix "10.0.1.0/24" `
      -VirtualNetwork $vnet
    Set-AzVirtualNetwork -VirtualNetwork $vnet
} else {
    Write-Host "Virtual network creation failed."
    exit
}

# Fetch the subnet ID for the created subnet
$subnetId = (Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName).Subnets[0].Id

# Step 3: Create Public IP Address
Write-Host "Creating public IP address..."
$publicIp = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName `
  -Location $location `
  -Name $publicIpName `
  -AllocationMethod Static `
  -Sku "Standard"

# Step 4: Create Network Interface
Write-Host "Creating network interface..."
$nic = New-AzNetworkInterface -ResourceGroupName $resourceGroupName `
  -Location $location `
  -Name $nicName `
  -SubnetId $subnetId `
  -PublicIpAddressId $publicIp.Id

if ($nic -eq $null) {
    Write-Host "Failed to create network interface."
    exit
}

# Step 5: Create Virtual Machine Configuration
Write-Host "Creating virtual machine configuration..."
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize "Standard_DS1_v2"

# Set OS and credentials with validation
$cred = Get-Credential -Message "Enter your VM admin username and password"

# Ensure the username follows Azure's rules (lowercase and no reserved names)
$vmUsername = $cred.UserName
if ($vmUsername -match "^[a-z0-9]+$") {
    Write-Host "Valid username: $vmUsername"
} else {
    Write-Host "Invalid username. Ensure it is lowercase and does not contain special characters."
    exit
}

# Correct Linux configuration, ensuring password authentication is enabled
$vmConfig = Set-AzVMOperatingSystem -VM $vmConfig `
  -Linux `
  -ComputerName $vmName `
  -Credential $cred `
  -DisablePasswordAuthentication $false # Set to true if using SSH keys only

# Attach the network interface
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

# Step 6: Create the Virtual Machine
Write-Host "Creating virtual machine..."
New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig

Write-Host "Virtual machine created successfully."

