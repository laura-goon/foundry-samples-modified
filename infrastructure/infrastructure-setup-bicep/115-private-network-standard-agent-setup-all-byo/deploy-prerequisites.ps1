# Deploy Prerequisites Script
# This script deploys the prerequisites (VNet, Storage, Cosmos DB, AI Search)
# and then updates the main.bicepparam file with the resource IDs

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-ai-foundry-prereqs",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus2",
    
    [Parameter(Mandatory=$false)]
    [string]$PrereqDeploymentName = "prereqs-deployment",
    
    [Parameter(Mandatory=$false)]
    [string]$MainDeploymentName = "main-deployment"
)

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "AI Foundry BYO Resources Deployment" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create Resource Group
Write-Host "Step 1: Creating resource group '$ResourceGroupName'..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create resource group"
    exit 1
}
Write-Host "✓ Resource group created successfully" -ForegroundColor Green
Write-Host ""

# Step 2: Deploy Prerequisites
Write-Host "Step 2: Deploying prerequisites (VNet, Storage, Cosmos DB, AI Search)..." -ForegroundColor Yellow
Write-Host "This may take 5-10 minutes..." -ForegroundColor Gray

$prereqDeployment = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file prerequisites.bicep `
    --parameters prerequisites.bicepparam `
    --name $PrereqDeploymentName `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to deploy prerequisites"
    exit 1
}
Write-Host "✓ Prerequisites deployed successfully" -ForegroundColor Green
Write-Host ""

# Step 3: Extract Outputs
Write-Host "Step 3: Extracting deployment outputs..." -ForegroundColor Yellow

$outputs = az deployment group show `
    --resource-group $ResourceGroupName `
    --name $PrereqDeploymentName `
    --query properties.outputs `
    --output json | ConvertFrom-Json

$vnetResourceId = $outputs.vnetResourceId.value
$vnetName = $outputs.vnetName.value
$agentSubnetName = $outputs.agentSubnetName.value
$peSubnetName = $outputs.peSubnetName.value
$storageResourceId = $outputs.storageAccountResourceId.value
$aiSearchResourceId = $outputs.aiSearchResourceId.value
$cosmosDBResourceId = $outputs.cosmosDBResourceId.value
$vnetAddressPrefix = $outputs.vnetAddressPrefix.value
$agentSubnetPrefix = $outputs.agentSubnetPrefix.value
$peSubnetPrefix = $outputs.peSubnetPrefix.value

Write-Host "✓ Outputs extracted successfully" -ForegroundColor Green
Write-Host ""

# Display the outputs
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Prerequisite Resource IDs" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "VNet Resource ID:     $vnetResourceId" -ForegroundColor White
Write-Host "VNet Name:            $vnetName" -ForegroundColor White
Write-Host "Agent Subnet:         $agentSubnetName" -ForegroundColor White
Write-Host "PE Subnet:            $peSubnetName" -ForegroundColor White
Write-Host "Storage Resource ID:  $storageResourceId" -ForegroundColor White
Write-Host "AI Search Resource ID: $aiSearchResourceId" -ForegroundColor White
Write-Host "Cosmos DB Resource ID: $cosmosDBResourceId" -ForegroundColor White
Write-Host ""

# Step 4: Create updated parameter file for main.bicep
Write-Host "Step 4: Creating main-with-prereqs.bicepparam..." -ForegroundColor Yellow

$paramFileContent = @"
using './main.bicep'

// Location for all resources
param location = '$Location'

// AI Services configuration
param aiServices = 'aiservices'

// Model deployment parameters
param modelName = 'gpt-4o'
param modelFormat = 'OpenAI'
param modelVersion = '2024-11-20'
param modelSkuName = 'GlobalStandard'
param modelCapacity = 30

// Project configuration
param firstProjectName = 'project'
param projectDescription = 'A project for the AI Foundry account with network secured deployed Agent'
param displayName = 'network secured agent project'

// Existing Virtual Network parameters (from prerequisites deployment)
param existingVnetResourceId = '$vnetResourceId'
param vnetName = '$vnetName'
param agentSubnetName = '$agentSubnetName'
param peSubnetName = '$peSubnetName'

// Network configuration (must match the prerequisites deployment)
param vnetAddressPrefix = '$vnetAddressPrefix'
param agentSubnetPrefix = '$agentSubnetPrefix'
param peSubnetPrefix = '$peSubnetPrefix'

// Existing resource IDs (from prerequisites deployment)
param aiSearchResourceId = '$aiSearchResourceId'
param azureStorageAccountResourceId = '$storageResourceId'
param azureCosmosDBAccountResourceId = '$cosmosDBResourceId'

// Project capability host
param projectCapHost = 'caphostproj'

// DNS Zones configuration - using empty strings means new zones will be created
param existingDnsZones = {
  'privatelink.services.ai.azure.com': ''
  'privatelink.openai.azure.com': ''
  'privatelink.cognitiveservices.azure.com': ''
  'privatelink.search.windows.net': ''
  'privatelink.blob.core.windows.net': ''
  'privatelink.documents.azure.com': ''
}
"@

$paramFileContent | Out-File -FilePath "main-with-prereqs.bicepparam" -Encoding UTF8
Write-Host "✓ Created main-with-prereqs.bicepparam" -ForegroundColor Green
Write-Host ""

# Step 5: Prompt to deploy main.bicep
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "Next Steps" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Prerequisites have been deployed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "To deploy the main AI Foundry infrastructure, run:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  az deployment group create ``" -ForegroundColor White
Write-Host "    --resource-group $ResourceGroupName ``" -ForegroundColor White
Write-Host "    --template-file main.bicep ``" -ForegroundColor White
Write-Host "    --parameters main-with-prereqs.bicepparam ``" -ForegroundColor White
Write-Host "    --name $MainDeploymentName" -ForegroundColor White
Write-Host ""
Write-Host "Or run this script to deploy automatically:" -ForegroundColor Yellow
Write-Host "  .\deploy-prerequisites.ps1 -DeployMain" -ForegroundColor White
Write-Host ""

# Check if -DeployMain was specified (for future enhancement)
if ($args -contains "-DeployMain") {
    Write-Host "Step 5: Deploying main infrastructure..." -ForegroundColor Yellow
    Write-Host "This may take 10-15 minutes..." -ForegroundColor Gray
    
    az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file main.bicep `
        --parameters main-with-prereqs.bicepparam `
        --name $MainDeploymentName
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to deploy main infrastructure"
        exit 1
    }
    Write-Host "✓ Main infrastructure deployed successfully" -ForegroundColor Green
}
