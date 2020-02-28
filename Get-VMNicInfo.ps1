function Get-VMNicInfo {
<#
.SYNOPSIS
 Gets vNIC information for a VM or multiple VMs
.DESCRIPTION
 Gathers vNIC information from the adapter properties and from the vmtools vmguest layer 3 properties. IP, mac, vlan backing etc.
.PARAMETER  Name
 Name of VM, also accepts wildcards.
.PARAMETER  Server
 Specify the hosting vcenter server to imrpove effeciency. Default is all connected vcenters.
.INPUTS
 It will accept piping from name property.
.OUTPUTS
 To screen lists name,parent vm name,mac, ip, networkname, subnetmask, gateway,dns,connection status,
.EXAMPLE
 Get-VMNicInfo -Name VM1 -server vmca01
 Will display info for vm VM1
#>
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)][string[]]$Name,
        [parameter(Mandatory=$false)]$Server = "*"
    )
        BEGIN{$nicinfo = @()}
        PROCESS{
            $vms = get-vm -name $Name -Server $Server
            $gateways = $vm.ExtensionData.Guest.IpStack.IpRouteConfig.IpRoute.Gateway | Where-Object {$_.ipaddress}
            $nics = Get-NetworkAdapter -vm $vms
            $guestnics = $vm.ExtensionData.Guest.net 
            foreach ($nic in $nics) {
                $length = $nic.uid.Length
                ## Getting deviceID
                $device = $nic.uid.Substring($length - 5,4) - 4000
                $gateway = $gateways | Where-Object {$_.device -eq $device } | select -ExpandProperty ipaddress
                $guestnic = $guestnics | Where-Object MacAddress -eq $nic.MacAddress
                $nic | Select-Object parent,name,networkname,MacAddress,Type,
                @{n='GuestHostname';e={$_.parent.guest.HostName}} ,
                @{n="GuestIP";e={$guestnic| Select-Object -ExpandProperty ipaddress | 
                    Where-Object { $_ -match '^\d{1,3}.*' } }},
                @{N='Gateway';E={$gateway}},
                @{N='Subnet Mask';E={ 
                    $dec = [Convert]::ToUInt32($(('1' * $guestnic.IpConfig.IpAddress[0].PrefixLength).PadRight(32, '0')), 2) 
                    $DottedIP = $( For ($i = 3; $i -gt -1; $i--) { 
                        $Remainder = $dec % [Math]::Pow(256, $i) 
                        ($dec - $Remainder) / [Math]::Pow(256, $i) 
                        $dec = $Remainder 
                        } ) 
                    [String]::Join('.', $DottedIP)  
                    }
                },
                @{N="DNS";E={[string]::Join(',',($guestnic.DnsConfig.IpAddress) ) }},
                @{n='Connected';e={$_.ConnectionState.Connected}},
                @{n='StartConnected';e={$_.ConnectionState.StartConnected}}
                 
             }   

        }
        END{}
}
