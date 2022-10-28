<span style="color:red">
********************************************************************************

DISCLAIMER: The code/examples/suggestions provided hereunder are provided free-of-charge, 
and shall be deemed ForgeRock "Sample Code" or untested suggestions as defined in the 
relevant governing agreement with ForgeRock.
The code/examples/suggestions are to be used exclusively in connection with ForgeRock’s software 
or services. ForgeRock only offers ForgeRock software or services to legal entities who have 
entered into a binding license agreement with ForgeRock.

THE CODE/EXAMPLES/SUGGESTIONS HEREUNDER ARE PROVIDED “AS IS” AND WITHOUT WARRANTY OF ANY KIND. 
SUCH CODE/EXAMPLE/SUGGESTION IS EXPRESSLY EXCLUDED FROM FORGEROCK'S INDEMNITY OR SUPPORT OBLIGATIONS, 
IF ANY, PURSUANT TO THE RELEVANT GOVERNING AGREEMENT. FORGEROCK AND ITS LICENSORS EXPRESSLY 
DISCLAIM ALL WARRANTIES, WHETHER EXPRESS, IMPLIED OR STATUTORY, INCLUDING, WITHOUT LIMITATION, 
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND ANY WARRANTY 
OF NON-INFRINGEMENT. FORGEROCK SHALL NOT HAVE ANY LIABILITY ARISING OUT OF OR RELATING TO ANY USE, 
IMPLEMENTATION OR CONFIGURATION OF THE SAMPLE CODE HEREUNDER.

********************************************************************************

Thorough testing is HIGHLY recommended!

********************************************************************************

</span>

### Need:

 A. One VM if you want to generate load on the same VM hosting DS
   
    -or-

 B. Two VMs if you want to generate load on a different host from the VM hosting DS
   
    -or-
 
 C. Three VMs if you want the same as B but you want to have replication between two DS instances

Size of these VMs is up to the person participating in this lab. 
Review https://backstage.forgerock.com/docs/ds/7.2/release-notes/before-you-install.html first. 

<span style="color:coral">
How these VM(s) are acquired and paid for is the responsibility of the person participating in this lab. ForgeRock is NOT responsible for any costs or time incurred. Using containers for this exercise is out of scope. 
</span>
 
********************************************************************************

For the following instructions option C above is being used. Make sure to update the /etc/hosts file correctly.

```
# one Load generator
10.1.0.6 rmflgwu0.internal.cloudapp.net rmflgwu0
# two DS+RS instances with replication:
10.1.0.4 rmfdsrswu0.internal.cloudapp.net rmfdsrswu0
10.1.0.5 rmfdsrswu1.internal.cloudapp.net rmfdsrswu1
```
These VMs are being hosted in an Azure west data center.

Ubuntu 20.x was used as the VM's operating system.

********************************************************************************
### Prep:

Install the OS of choice on the VM(s) and then install the following: 
```
sudo apt-get upgrade
sudo apt-get update
sudo apt install net-tools
sudo apt install unzip
sudo apt install zip
sudo apt install dstat
sudo apt install jq
sudo apt install fio
sudo apt install openjdk-17-jdk-headless
sudo apt-get update
```
To make networking easier you -may- need to do the following on each VM:
```
sudo vi /etc/hosts

10.1.0.6 rmflgwu0.internal.cloudapp.net rmflgwu0
10.1.0.4 rmfdsrswu0.internal.cloudapp.net rmfdsrswu0
10.1.0.5 rmfdsrswu1.internal.cloudapp.net rmfdsrswu1 
```
^^^^^ what to add is based on the environment ^^^^^

********************************************************************************

Download DS 7.2 zip (https://backstage.forgerock.com/downloads/browse/ds/featured)

Install DS 7.2 (https://backstage.forgerock.com/docs/ds/7.2/getting-started/install.html) on VM:
```
unzip ~/DS-7.2.0.zip
```
***************************************************************************
************* SAVE the output from the following **************************
```
~/opendj/bin/dskeymgr create-deployment-id --deploymentIdPassword password
```
it will be different for every deployment and it will be required for the next step

An example of the output from dskeymgr:

AJDLO6nxjWezI7U9Adqu8y88BpyO_0Q5CBVN1bkVDAN_0t3gfi6wEcXkI

***************************************************************************

```
~/opendj/setup \
 --instancePath /home/forgerock/opendj \
 --serverId rmfdsrswu0 \
 --deploymentId AJDLO6nxjWezI7U9Adqu8y88BpyO_0Q5CBVN1bkVDAN_0t3gfi6wEcXkI \
 --deploymentIdPassword password \
 --rootUserDn uid=admin \
 --rootUserPassword password \
 --hostname rmfdsrswu0.internal.cloudapp.net \
 --adminConnectorPort 4444 \
 --ldapPort 1389 \
 --ldapsPort 1636 \
 --httpPort 8080 \
 --httpsPort 8443 \
 --replicationPort 8989 \
 --profile ds-evaluation \
 --acceptlicense \
 --set ds-evaluation/generatedUsers:1000000

~/opendj/bin/start-ds

~/opendj/bin/dsconfig \
  set-global-configuration-prop \
  --advanced --port 4444 --hostname rmfdsrswu0.internal.cloudapp.net \
  --bindDN uid=admin --bindPassword password \
  --set trust-transaction-ids:true \
  --trustStorePath ~/opendj/config/keystore \
  --trustStorePassword:file ~/opendj/config/keystore.pin \
  --no-prompt
```

++++++++++ Optional - second DS+RS on separate VM for replication

Install DS on separate VM if setting up replication (optional)

Download DS 7.2 zip (https://backstage.forgerock.com/downloads/browse/ds/featured)

Install DS 7.2 (https://backstage.forgerock.com/docs/ds/7.2/getting-started/install.html) on VM:
```
unzip ~/DS-7.2.0.zip
```
The deploymentId will be the same used with the first DS instance.
```
~/opendj/setup \
 --instancePath /home/forgerock/opendj \
 --serverId rmfdsrswu1 \
 --deploymentId AJDLO6nxjWezI7U9Adqu8y88BpyO_0Q5CBVN1bkVDAN_0t3gfi6wEcXkI \
 --deploymentIdPassword password \
 --rootUserDn uid=admin \
 --rootUserPassword password \
 --hostname rmfdsrswu1.internal.cloudapp.net \
 --adminConnectorPort 4444 \
 --ldapPort 1389 \
 --ldapsPort 1636 \
 --httpPort 8080 \
 --httpsPort 8443 \
 --replicationPort 8989 \
 --bootstrapReplicationServer rmfdsrswu0.internal.cloudapp.net:8989 \
 --profile ds-evaluation \
 --acceptlicense \
 --set ds-evaluation/generatedUsers:100

~/opendj/bin/start-ds

~/opendj/bin/dsconfig \
  set-global-configuration-prop \
  --advanced --port 4444 --hostname rmfdsrswu1.internal.cloudapp.net \
  --bindDN uid=admin --bindPassword password \
  --set trust-transaction-ids:true \
  --trustStorePath ~/opendj/config/keystore \
  --trustStorePassword:file ~/opendj/config/keystore.pin \
  --no-prompt
 
~/opendj/bin/dsrepl \
 initialize \
 --baseDN dc=example,dc=com \
 --toServer rmfdsrswu1 \
 --hostname rmfdsrswu0 \
 --port 4444 \
 --bindDN uid=admin \
 --bindPassword password \
 --trustStorePath ~/opendj/config/keystore \
 --trustStorePassword:file ~/opendj/config/keystore.pin \
 --no-prompt

~/opendj/bin/dsrepl status --hostname $(hostname -f) --port 4444 \
                           --bindDN "uid=admin" --bindPassword password \
                           --showReplicas --trustAll \
                           --showChangeLogs --showGroups
```

+++++++++++++ Optional - DS+RS on separate VM for load generation 

Install DS on separate VM if using for load generation (optional)

Download DS 7.2 zip (https://backstage.forgerock.com/downloads/browse/ds/featured)

Install DS 7.2 (https://backstage.forgerock.com/docs/ds/7.2/getting-started/install.html) on VM:
```
unzip ~/DS-7.2.0.zip

~/opendj/bin/dskeymgr create-deployment-id --deploymentIdPassword password
```
SAVE - it will be different for the load generator:

AANj2zoucqRF7NAod0R2UrgLBpyg9g5CBVN1bkVDUtzSlgfpGX3ZGQ
```
/home/forgerock/opendj/setup \
 --instancePath /home/forgerock/opendj \
--serverId rmflgwu0 \
--deploymentId AANj2zoucqRF7NAod0R2UrgLBpyg9g5CBVN1bkVDUtzSlgfpGX3ZGQ \
--deploymentIdPassword password \
--rootUserDn uid=admin \
--rootUserPassword password \
--hostname rmflgwu0.internal.cloudapp.net \
--adminConnectorPort 4444 \
--ldapPort 1389 \
--ldapsPort 1636 \
--httpPort 8080 \
--httpsPort 8443 \
--replicationPort 8989 \
--profile ds-evaluation \
--set ds-evaluation/generatedUsers:100

~/opendj/bin/dsconfig \
  set-global-configuration-prop \
  --advanced --port 4444 --hostname rmflgwu0.internal.cloudapp.net \
  --bindDN uid=admin --bindPassword password \
  --set trust-transaction-ids:true \
  --trustStorePath ~/opendj/config/keystore \
  --trustStorePassword:file ~/opendj/config/keystore.pin \
  --no-prompt
```

***************************************************************************
### Now for OS-level testing. Best to have at least two screens into each VM. 
***************************************************************************
First IOPs testing using ```fio``` while at the same time watching the VM with ```dstat```. In one window:
```
dstat --time --cpu-adv --disk --bw --io 
```
and in another window:
```
fio --name=random-writers --ioengine=libaio --iodepth=4 \
    --readwrite=write --bs=8k --size=4g --numjobs=1 --runtime=30 \
    --direct=1
```
Record results from ```fio``` and from ```dstat```and then run again with only one switch changed:
```
dstat --time --cpu-adv --disk --bw --io 

fio --name=random-writers --ioengine=libaio --iodepth=4 \
    --readwrite=write --bs=8k --size=4g --numjobs=1 --runtime=30 \
    --direct=0
```
Record results and compare. Notice anything?

***************************************************************************
## FINALLY some DS testing.
***************************************************************************

On the intance used for load generation:
```
~/opendj/bin/ldapsearch --hostname rmfdsrswu0.internal.cloudapp.net --port 1636 \
                        --bindDN "uid=admin" --bindPassword "password" \
                        --useSsl --trustAll \
                        --control TransactionId:false:"$(hostname -f)-xyz1cat add23-$(date +%s)" \
                        --baseDN "ou=people,dc=example,dc=com" \
                        "(uid=user.1870)" "*" "+"

~/opendj/bin/ldapsearch --hostname rmfdsrswu0.internal.cloudapp.net --port 4444 \
                        --bindDN "uid=admin" --bindPassword "password" 
                        --trustAll --useSsl \
                        --baseDN "cn=monitor" --searchScope sub \
                        "(objectClass=*)" "*"
```
```
~/opendj/bin/searchrate --hostname rmfdsrswu0.internal.cloudapp.net --port 1636 \
                        --bindDN "uid=admin" --bindPassword "password" \
                        --useSsl --trustAll \
                        --baseDn 'uid=user.{1},ou=people,dc=example,dc=com' \
                        --keepConnectionsOpen --noRebind \
                        --numConnections 1 \
                        --numConcurrentRequests 1 \
                        --targetThroughput 500 \
                        --argument "rand(0,10000)" "(uid=user.{})"

~/opendj/bin/searchrate --hostname rmfdsrswu1.internal.cloudapp.net --port 1636 \
                        --bindDN "uid=admin" --bindPassword "password" \
                        --useSsl --trustAll \
                        --baseDn 'uid=user.{1},ou=people,dc=example,dc=com' \
                        --keepConnectionsOpen --noRebind \
                        --numConnections 1 \
                        --numConcurrentRequests 1 \
                        --targetThroughput 500 \
                        --argument "rand(0,10000)" "(uid=user.{})"

~/opendj/bin/modrate --hostname rmfdsrswu0.internal.cloudapp.net --port 1636 \
                        --bindDN "uid=admin" --bindPassword "password" \
                        --useSsl --trustAll \
                        --keepConnectionsOpen --noRebind \
                        --numConnections 1 \
                        --numConcurrentRequests 1 \
                        --targetThroughput 20 \
                        --argument 'rand(0,10000)' \
                        --targetDn 'uid=user.{1},ou=people,dc=example,dc=com' \
                        --argument 'randstr(16)' 'description:{2}'

~/opendj/bin/addrate --hostname rmfdsrswu0.internal.cloudapp.net --port 1636 \
                        --bindDN "uid=admin" --bindPassword "password" \
                        --useSsl --trustAll \
                        --keepConnectionsOpen --noRebind \
                        --numConnections 1 \
                        --numConcurrentRequests 1 \
                        --targetThroughput 10 \
                        ~/addrate.template
```
Links around MakeLDIF and templates:

https://backstage.forgerock.com/docs/ds/7.2/tools-reference/makeldif.html

https://backstage.forgerock.com/docs/ds/7.2/tools-reference/makeldif-template.html

```
cp ~/opendj/config/MakeLDIF/addrate.template ~/.
```
(edit) ```vi ~/addrate.template ```

Append to: ```uid: user.{employeeNumber}```

A string like
```.<random:alphanumeric:16>```

So it becomes: 

```uid: user.{employeeNumber}.<random:alphanumeric:16>```

save edits
```
cat addrate.template

define suffix=dc=example,dc=com
define maildomain=example.com

branch: [suffix]
objectClass: domain

branch: ou=People,[suffix]
objectclass: organizationalUnit
subordinateTemplate: person

template: person
rdnAttr: uid
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
givenName: <first>
sn: <last>
cn: {givenName} {sn}
initials: {givenName:1}<random:chars:ABCDEFGHIJKLMNOPQRSTUVWXYZ:1>{sn:1}
employeeNumber: <sequential:100000>
uid: user.{employeeNumber}.<random:alphanumeric:16>
mail: {uid}@[maildomain]
userPassword: 5up35tr0ng
telephoneNumber: <random:telephone>
homePhone: <random:telephone>
pager: <random:telephone>
mobile: <random:telephone>
street: <random:numeric:5> <file:streets> Street
l: <file:cities>
st: <file:states>
postalCode: <random:numeric:5>
postalAddress: {cn}${street}${l}, {st}  {postalCode}
description: This is the description for {cn}.
```
