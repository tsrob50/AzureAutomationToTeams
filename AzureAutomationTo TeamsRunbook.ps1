<#
.SYNOPSIS
  This runbook sends a message to a Teams channel when a resource group is added to an Azure subscription.
.DESCRIPTION
  Event Grid sends an Azure Automation webhook when a resource Group is added to a subscription.  Advanced filters in Event Grid limit the alert to new or modified Resource Groups.
  The Azure Automation runbook formats the message using static entries and dynamic content from the input JSON.
  Azure Automation runbook sends a second webhook with the message for the Teams Channel.
.INPUTS
  JSON data passed by the webhook from Event Grid
.OUTPUTS
  Errors write to the Error output stream
  Notification in Teams
.NOTES
  Version:        1.0
  Author:         Travis Roberts
  Creation Date:  8/28/2019
  Purpose/Change: Initial script development
  ****This script provided as-is with no warranty. Test it before you trust it.****
.EXAMPLE
  See my YouTube channel at http://www.youtube.com/c/TravisRoberts or https://www.Ciraltos.com for details.
#>

# Step One, get input from Event Grid

Param(
    [parameter (Mandatory = $false)]
    [object] $WebhookData
)

# Declarations

# Set the default error action
$errorActionDefault = $ErrorActionPreference

# Channel Webhook.  This URL comes from the Teams chanel that will recive the messages.
$ChannelURL = "ENTER TEAMS URL HERE"

# Set the image used for the message.  
# leave blank for no image
$image = "LINK TO IMAGE"

# Convert Webhook Data
try {
    $RequestBody = $WebhookData.RequestBody | ConvertFrom-Json -ErrorAction Stop
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error converting requestbody from JSON ' + $ErrorMessage)
    Break
}

# Get the RG Name
try {
    $ErrorActionPreference = 'stop'
    $subjectSplit = $RequestBody.subject -split '/'
    $rgName = $subjectSplit[4]
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error getting Resource Group name ' + $ErrorMessage)
    Break
}
Finally {
    $ErrorActionPreference = $errorActionDefault
}

# Get the subscription
try {
    $ErrorActionPreference = 'stop'
    $topicSplit = $RequestBody.topic -split '/'
    $SubscriptionId = $topicSplit[2]
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error getting Subscription ID ' + $ErrorMessage)
    Break
}
Finally {
    $ErrorActionPreference = $errorActionDefault
}



<# 
# Used for testing
write-output 'request body'
Write-Output $RequestBody
Write-Output 'data'
Write-Output $RequestBody.data
Write-Output 'claims'
Write-Output $RequestBody.data.claims
Write-Output 'name'
Write-Output $RequestBody.data.claims.name
#>

#Send Data to Teams
#Post to teams if the channel webhook is present.   

$TargetURL = "https://portal.azure.com/#resource" + $requestBody.data.resourceUri + "/overview"   
try {    
    $Body = ConvertTo-Json -ErrorAction Stop -Depth 4 @{
        title           = 'Azure Resource Group Creation Notification' 
        text            = 'A new Azure Resource Group has been created'
        sections        = @(
            @{
                activityTitle    = 'Azure Resource Group'
                activitySubtitle = 'Resource Group ' + $rgName + ' has been created'
                activityText     = 'Resource Group was created in the subscription ' + $SubscriptionId + ' by ' + $RequestBody.data.claims.name
                activityImage    = $image
            }
        )
        potentialAction = @(@{
                '@context' = 'http://schema.org'
                '@type'    = 'ViewAction'
                name       = 'Click here to manage the Resource Group'
                target     = @($TargetURL)
            })
    }
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error converting body to JSON ' + $ErrorMessage)
    Break
}
           
# call Teams webhook
try {
    Invoke-RestMethod -Method "Post" -Uri $ChannelURL -Body $Body | Write-Verbose
}
catch {
    $ErrorMessage = $_.Exception.message
    write-error ('Error with invoke-restmethod ' + $ErrorMessage)
    Break
}
