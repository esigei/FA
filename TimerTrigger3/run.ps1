# Input bindings are passed in via param block.
param($Timer)

$policyList=("DEVSUBWAF","Policy1","TestSubWaf","devwaf")
$policyResourceGroupsList=("myrg","testrg","RSGDEV")
$rules=("mycustom2","devcustom1","mycustom1")
# Getting IPs from a Remote file
$Response = Invoke-WebRequest -URI "https://eliteststorage1.blob.core.windows.net/mytestcontsiner/iplist2.txt" -UseBasicParsing
$RemoteIPsClean=@()
$RawIPList=$Response.Content.Split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)
foreach($ip in $RawIPList){
$RemoteIPsClean +=$ip.Trim()}
#Removes Duplicates if on list
# Clean list of IP Addresses from Remote file
$RemoteIPsClean=$RemoteIPsClean | select -Unique
#Get list of subscriptions and set the scop to each of the subscription
$Subscriptions=az account list | ConvertFrom-Json
$SubscriptionId=$Subscriptions.id
foreach($sub in $SubscriptionId){
$sub
# For each subscription set the scope to current Subscription & get a list of WAF's in the Current sub
az account set --subscription $sub
$rg=az group list | ConvertFrom-Json
$WAFList=(az network application-gateway waf-policy list | ConvertFrom-Json)
# Check at each WAF policy in the current sub; 
# If policy matches policies in the policy List and if is in specified resource-group
# then get the policies' Custom Rules
foreach($policy in $WAFList){
foreach ($rg in $policyResourceGroupsList){
if(($policyList -contains $policy.name) -and ($rg -eq $policy.resourceGroup)){
$CustomRuleList=az network application-gateway waf-policy custom-rule list --policy-name $policy.name --resource-group $rg | ConvertFrom-Json
###
$policy.name
$rg
# Iterate through each custom rule and get the rule that matches rule to update
foreach($rule in $rules){
$CustomRulesList=$CustomRuleList | Where name -eq $rule
$CustomRuleName=$CustomRulesList.name
$CustomRuleName
$matchVals=$CustomRulesList.matchConditions.matchValues
#newlistIP= Place Holder variable for list of new Ips to be added to the policy
$newlistIP=@() 
#For each of the Custom Rules names, check if any addressfrom remote file is in matchValues
# if not, add Address to the new list
foreach($cname in $CustomRuleName){
foreach($Address in $RemoteIPsClean){
if($matchVals -notcontains $Address){
 $newlistIP +=$Address
}
}
$newlistIP
# Append addresses in the new list to the match Values
#####1/16
if((($matchVals.length)+($newlistIP.length)) -le 50){
az network application-gateway waf-policy custom-rule update --name $cname --policy-name $policy.name --resource-group $rg --add matchConditions[0].matchValues $newlistIP
Write-Host "Successfully Added for this rule $cname"
}else{
    Write-Host "Cannot add to the rule as it exceeds the limit Total lenght= (($matchVals.length)+($newlistIP.length))"
}
####end1/16
}
####
}
}
}
}
}