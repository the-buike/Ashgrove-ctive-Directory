<p align="center">
  <img src="images/00-active-directory-logo.png" alt="Active Directory logo" width="240" />
</p>

# Ashgrove Clinic Active Directory Infrastructure Build

**Simulated engagement: Bridgeway Technology (MSP) for Ashgrove Clinic**

## Project Overview

This project simulates an MSP technician (Bridgeway Technology) standing up a full internal Active Directory environment for a fictional outpatient healthcare client, Ashgrove Clinic, in Azure. The project covers four phases:

1. **Infrastructure Setup** — provisioning the domain controller and client VMs in Azure, configuring static IP and DNS
2. **Active Directory Installation and Domain Structure** — promoting the domain controller, building the department OU structure, creating the working domain admin account, and joining the first workstation to the domain
3. **Remote Access and Bulk User Provisioning** — enabling standard domain users to remote into the workstation, and provisioning Ashgrove Clinic's staff accounts with a PowerShell script
4. **Account Administration** — configuring an account lockout policy, then handling lockouts, password resets, account disable/enable, and reviewing authentication logs

## Environment & Technologies

| Component | Detail |
|---|---|
| Platform | Microsoft Azure |
| Resource group | Active-Directory-Lab |
| Region | East US 2 |
| Domain controller | DC1 — Windows Server 2022 Datacenter, Standard_D2ls_v7 |
| Client workstation | client1 — Windows 11 Pro, Standard_D2ls_v7 |
| Domain | ashgroveclinic.com |
| Tools | Server Manager, Active Directory Users and Computers, Group Policy Management, PowerShell ISE, Remote Desktop Connection |

---

# Phase 1: Infrastructure Setup

## Step 1: Create the Resource Group

Went to the Azure Portal > Resource groups > Create a resource group. Set:
- Subscription: Azure subscription 1
- Resource group name: **Active-Directory-Lab**
- Region: **East US 2**

Clicked Review + create > Create.

![Create a resource group screen, name Active-Directory-Lab, region East US 2](images/01-create-resource-group.png)

## Step 2: Create the DC1 Virtual Machine

Went to Virtual machines > Create > Azure virtual machine. On the Basics tab, set:
- Resource group: Active-Directory-Lab
- Virtual machine name: **DC1**
- Region: East US 2
- Image: **Windows Server 2022 Datacenter: Azure Edition - x64 Gen2**
- Size: **Standard_D2ls_v7** (2 vCPUs, 4 GiB memory)
- Username: **DC1ADMIN**, password set and confirmed

![Create a virtual machine, Basics tab, DC1 with Windows Server 2022 Datacenter image](images/02-create-vm-dc1-basics.png)

On the Networking tab, left the virtual network and subnet on their auto-generated defaults (this created **vnet-eastus2-1** and **snet-eastus2-1**, 172.16.0.0/24, since no vnet existed yet), attached a new public IP (**DC1-ip**), and allowed inbound RDP (port 3389).

![Create a virtual machine, Networking tab, for DC1 showing vnet-eastus2-1, subnet snet-eastus2-1, and RDP allowed](images/03-create-vm-dc1-networking.png)

Clicked Review + create, confirmed the settings, and clicked Create.

![Review and create screen for DC1](images/04-create-vm-dc1-review.png)

![Deployment complete confirmation for DC1](images/05-dc1-deployment-complete.png)

## Step 3: Create the client1 Virtual Machine

Repeated the same process for the second VM. On the Basics tab:
- Resource group: Active-Directory-Lab
- Virtual machine name: **client1**
- Image: **Windows 11 Pro, version 25H2 - x64 Gen2**
- Size: **Standard_D2ls_v7**
- Username: **azureuser**, password set and confirmed

![Create a virtual machine, Basics tab, for client1 showing Windows 11 Pro image](images/06-create-vm-client1-basics.png)

On the Networking tab, selected the existing **vnet-eastus2-1** and **snet-eastus2-1** (the same network DC1 is on), attached a new public IP (**client1-ip**), and allowed inbound RDP.

![Create a virtual machine, Networking tab, for client1 showing the same vnet and subnet as DC1](images/07-create-vm-client1-networking.png)

Clicked Review + create > Create.

![Review and create screen for client1](images/08-create-vm-client1-review.png)

![Deployment complete confirmation for client1](images/09-client1-deployment-complete.png)

## Step 4: Set DC1's Private IP to Static

Went to DC1 > Networking > Network settings, opened the NIC (dc1348), and confirmed the assigned private IP.

![DC1 Network settings overview showing NIC dc1348 and private IP 172.16.0.4](images/10-dc1-network-settings-overview.png)

Opened IP configurations and found the private IP allocated dynamically at **172.16.0.4**.

![DC1 IP configurations before the change, private IP 172.16.0.4 shown as Dynamic](images/11-dc1-ip-configurations-before.png)

Edited the IP configuration, switched allocation from Dynamic to **Static**, keeping the same address (172.16.0.4), and saved. This was done before touching client1's DNS setting, since client1 is about to be pointed at this exact address and a dynamic IP could change on it later.

![Edit IP configuration panel for DC1 with allocation set to Static at 172.16.0.4](images/12-dc1-edit-ip-config-static.png)

## Step 5: Point client1's DNS to DC1

Went to client1 > Networking > Network settings, opened the NIC (client1326), and confirmed its private IP (172.16.0.5).

![client1 Network settings overview showing NIC client1326 and private IP 172.16.0.5](images/13-client1-network-settings-overview.png)

Opened DNS servers, switched from "Virtual network inherited" to **Custom**, and entered **172.16.0.4** (DC1's static IP) as the DNS server. Saved and restarted client1.

A client's DNS setting is what it uses to look up where a domain controller lives. Azure's default DNS resolver has no knowledge of a private domain like this one, so client1 has to be pointed directly at DC1 to find it later.

![client1 DNS servers screen set to Custom with 172.16.0.4 entered](images/14-client1-dns-servers-custom.png)

## Step 6: Connect to client1 via Remote Desktop and Verify

Opened Remote Desktop Connection, entered client1's public IP, and connected using the azureuser credentials created in Step 3. Once logged in, opened PowerShell and ran:

```
ping 172.16.0.4
```

Got a successful reply with 0% packet loss.

![PowerShell on client1 showing a successful ping to 172.16.0.4 with 0% packet loss](images/15-client1-ping-dc1-success.png)

Ran `ipconfig /all` and confirmed the DNS Servers field now shows 172.16.0.4.

![PowerShell on client1 showing ipconfig /all output with DNS Servers listed as 172.16.0.4](images/16-client1-ipconfig-all-dns.png)

**End of Phase 1:** two VMs exist on the same virtual network, DC1 has a locked static IP, and client1's DNS points at it and is confirmed working.

---

# Phase 2: Active Directory Installation and Domain Structure

## Step 1: Install the AD DS Role on DC1

Connected to DC1 via Remote Desktop. In Server Manager, went to Add roles and features. Clicked through the wizard:

![Add Roles and Features Wizard, Before You Begin screen](images/17-add-roles-features-before-begin.png)

On Server Roles, checked **Active Directory Domain Services** and accepted the additional required features when prompted.

![Select server roles screen with Active Directory Domain Services checked](images/18-select-server-roles-adds.png)

On the confirmation screen, checked "Restart the destination server automatically if required" and clicked Install.

![Confirm installation selections screen listing AD DS, Group Policy Management, and related tools](images/19-confirm-installation-selections.png)

![Installation progress screen showing feature installation in progress](images/20-installation-progress.png)

![Server Manager dashboard after installation, showing AD DS listed as an installed role](images/21-server-manager-dashboard-post-install.png)

## Step 2: Promote DC1 to a Domain Controller

Server Manager flagged that post-deployment configuration was required. Clicked the notification flag and selected **Promote this server to a domain controller**.

![Server Manager dashboard showing the post-deployment configuration notification flag](images/22-post-deployment-config-notification.png)

On the Deployment Configuration screen, selected **Add a new forest** and entered the root domain name: **ashgroveclinic.com**.

![Deployment Configuration screen, Add a new forest selected with root domain name ashgroveclinic.com](images/23-adds-deployment-configuration-ashgroveclinic.png)

On Domain Controller Options, left DNS server and Global Catalog checked, and set a Directory Services Restore Mode (DSRM) password.

![Domain Controller Options screen showing DNS server and Global Catalog checked, with DSRM password fields](images/24-domain-controller-options-dsrm.png)

On Prerequisites Check, all checks passed. Clicked Install. The server restarted automatically once promotion finished.

![Prerequisites Check screen showing all checks passed successfully](images/25-prerequisites-check-passed.png)

## Step 3: Log Back Into DC1 With Domain Credentials

After the restart, opened Remote Desktop Connection again. This time the login required the domain name prefix, since DC1's accounts now live in Active Directory instead of a local account database.

![Remote Desktop Connection login screen showing ashgroveclinic.com\\azureuser as the username](images/26-rdp-login-azureuser-ashgroveclinic.png)

## Step 4: Build the OU Structure

Opened Server Manager > Tools > **Active Directory Users and Computers**.

![Server Manager Tools menu with Active Directory Users and Computers highlighted](images/27-server-manager-tools-adusc.png)

Right-clicked the domain (ashgroveclinic.com) > New > Organizational Unit.

![Right click context menu on the domain showing New > Organizational Unit](images/28-adusc-new-organizational-unit.png)

Created the following OUs one at a time, using this same right-click process: **_ADMINS**, **CLINICAL**, **_IT**, **_FRONT DESK**, **_FINANCE**, **_CLIENTS**.

![New Object - Organizational Unit dialog, name field set to _ADMINS](images/29-new-ou-admins.png)

![New Object - Organizational Unit dialog, name field set to CLINICAL](images/30-new-ou-clinical.png)

![Full OU list under ashgroveclinic.com showing _ADMINS, _CLIENTS, _FINANCE, _FRONT DESK, _IT, and CLINICAL](images/31-ou-list-full.png)

The **_ADMINS** OU is reserved for privileged administrative accounts only, kept separate from every department, including IT. Regular department staff never go in _ADMINS, even IT staff, since privileged and standard accounts should stay isolated.

## Step 5: Create the Domain Admin Account

Right-clicked the **_ADMINS** OU > New > User.

![Right click context menu on the _ADMINS OU showing New > User](images/32-admins-ou-new-user.png)

Entered:
- First name: **Chibuike**
- Last name: **Okerulu**
- User logon name: **chibuikeo** (@ashgroveclinic.com)

Set a password on the following screens and finished the wizard.

![New Object - User dialog showing First name Chibuike, Last name Okerulu, User logon name chibuikeo, at ashgroveclinic.com](images/33-new-user-chibuike-okerulu.png)

Right-clicked the new account > Properties.

![Right click context menu on the Chibuike Okerulu account showing Properties highlighted](images/34-chibuike-context-menu-properties.png)

Went to the **Member Of** tab > Add, typed **Domain Admins**, clicked Check Names to confirm it resolved, then OK and Apply.

![Select Groups dialog with Domain Admins entered as the group to add](images/35-select-groups-domain-admins.png)

![Chibuike Okerulu Properties, Member Of tab, showing membership in Domain Admins and Domain Users](images/36-chibuike-member-of-domain-admins.png)

Created an account first, then explicitly added it to Domain Admins as a second, separate step, so privilege is never accidental, an account only has domain-wide power because it was deliberately granted.

## Step 6: Switch to the Domain Admin Account

Logged off, reopened Remote Desktop Connection, and logged into DC1 as **ashgroveclinic.com\\chibuikeo**. This is the account used for all administrative work from this point forward.

![Remote Desktop Connection login screen showing chibuikeo@ashgroveclinic.com as the username](images/37-rdp-login-chibuikeo.png)

## Step 7: Join client1 to the Domain

Connected to client1 via Remote Desktop as azureuser. Right-clicked Start > System.

![Right click Start menu on client1, System highlighted](images/38-client1-rightclick-start-system.png)

Confirmed client1 was still a standalone machine on WORKGROUP with a local account.

![Settings About page for client1, showing azureuser as a local account](images/39-client1-about-azureuser-local.png)

Opened System Properties > Advanced tab, then the Computer Name tab, and clicked **Change**.

![System Properties, Advanced tab](images/40-system-properties-advanced.png)

![System Properties, Computer Name tab, showing Workgroup WORKGROUP](images/41-system-properties-computer-name-workgroup.png)

In the Computer Name/Domain Changes dialog, selected **Domain** and typed **ashgroveclinic.com**.

![Computer Name/Domain Changes dialog with the Domain field empty, about to be filled in](images/42-computer-name-domain-changes-blank.png)

Because client1's DNS was already pointed at DC1 in Phase 1, it was able to locate the domain controller for ashgroveclinic.com and complete the join.

![Welcome to the ashgroveclinic.com domain confirmation dialog](images/43-welcome-to-ashgroveclinic-domain.png)

Restarted client1. After the restart, confirmed the machine's new fully qualified name.

![Computer Name/Domain Changes dialog showing full computer name client1.ashgroveclinic.com and Domain ashgroveclinic.com](images/44-computer-name-domain-changes-confirmed.png)

## Step 8: Verify the Domain Join

Back on DC1, opened Active Directory Users and Computers, expanded **Computers**, and confirmed client1's object was there with a fully qualified DNS name.

![Server Manager and Active Directory Users and Computers, client1 Properties General tab showing DNS name client1.ashgroveclinic.com](images/45-adusc-client1-properties-dns-name.png)

![Active Directory Users and Computers, Computers container showing client1 listed](images/46-adusc-computers-ou-client1.png)

Logged back into client1 to confirm the domain login itself worked.

![Remote Desktop lock screen showing Chibuike Okerulu, Welcome](images/47-client1-lockscreen-chibuike-welcome.png)

![Settings About page for client1 showing Chibuike Okerulu, chibuikeo@ashgroveclinic.com](images/48-client1-about-chibuike-domain.png)

**End of Phase 2:** DC1 is a domain controller for ashgroveclinic.com, the department OU structure is built, a working domain admin account exists, and client1 is joined to the domain.

---

# Phase 3: Remote Access and Bulk User Provisioning

## Step 1: Allow Domain Users to Remote Into client1

On client1, went to Settings > System > Remote Desktop > Remote Desktop users.

![Settings, System, Remote Desktop, Remote Desktop Users dialog showing ASHGROVECLINIC\\chibuikeo already has access](images/49-remote-desktop-users-dialog.png)

Clicked Add, typed **Domain Users**, and confirmed.

![Select Users or Groups dialog with Domain Users entered as the object to add](images/50-select-users-domain-users.png)

By default only administrators can RDP into a machine. Adding the Domain Users group means any standard Ashgrove Clinic staff account can log into client1, not just admins.

**Homelab note:** this was configured by hand directly on client1 because there is only one workstation in this environment. With multiple machines, this would be pushed out through a Group Policy Object instead of set individually on each one.

## Step 2: Write the Bulk User Creation Script

On DC1, opened **PowerShell ISE** as Administrator.

![Apps list showing Windows PowerShell ISE highlighted](images/52-apps-list-powershell-ise.png)

Created a new script, create-users.ps1, that creates five named Ashgrove Clinic staff accounts directly into their correct department OUs, then generates 15 additional staff with real first/last names, randomly assigned across the department OUs.

![PowerShell ISE with create-users.ps1 open, showing the name arrays and department OU list at the top of the script](images/51-powershell-ise-script-top.png)

The script (provided separately as **create-users.ps1**) went through a few corrections before it worked cleanly:
- Fixed a bug where a misspelled variable (`$fisrtName`) meant first names were never actually populated
- Replaced algorithmic name generation with real first/last name lists
- Corrected the target OU names to match what actually exists (**_IT**, **CLINICAL**, **_FRONT DESK**, **_FINANCE**) instead of a placeholder `_EMPLOYEES` OU
- Added a duplicate-account check and error handling so one failed user doesn't stop the whole run

## Step 3: Run the Script

Clicked Run Script. The console showed each user being created in real time.

![PowerShell ISE showing the bottom portion of the script alongside console output listing created users and two error blocks](images/53-powershell-ise-run-output-errors.png)

Two error types came up during the run:
- **elena.marsh** failed with "account already exists" — a leftover from an earlier test run, expected and harmless
- **william.rodriguez** and **timothy.rodriguez** failed with a vague Active Directory attribute error, most likely an auto-derived SamAccountName collision, resolved in the corrected script by setting SamAccountName explicitly

## Step 4: Verify the Accounts Landed in the Right Departments

Checked each department OU in Active Directory Users and Computers.

![CLINICAL OU showing a list of users including elena.marsh](images/55-adusc-clinical-ou-users.png)

![_IT OU showing a list of users including devon.ricci and marcus.bell](images/56-adusc-it-ou-users.png)

![_FINANCE OU showing a list of users including tasha.combs](images/57-adusc-finance-ou-users.png)

![_FRONT DESK OU showing a list of users including renee.park](images/58-adusc-frontdesk-ou-users.png)

## Step 5: Test a Non-Admin Login

Opened Remote Desktop Connection to client1 and logged in as **ashgroveclinic.com\\devon.ricci**.

![Windows Security credentials prompt showing ashgroveclinic.com\\devon.ricci as the username](images/59-rdp-login-devon-ricci.png)

![Remote Desktop lock screen showing devon.ricci, Welcome](images/60-client1-lockscreen-devon-welcome.png)

Opened File Explorer to confirm a new local profile had been created for the account.

![File Explorer Users folder on client1 showing azureuser, chibuikeo, devon.ricci, and Public folders](images/61-client1-users-folder-profiles.png)

**End of Phase 3:** client1 accepts logins from any standard domain account, and 20 Ashgrove Clinic staff accounts exist across the four department OUs, including the five named staff members in their correct departments.

---

# Phase 4: Account Administration

## Step 1: Test for an Account Lockout Policy

On client1, deliberately logged in with a wrong password against a test account (tasha.combs), repeated 10 to 11 times.

**Result:** the account did not lock out. Ashgrove Clinic's domain had no lockout threshold configured by default.

**Homelab note:** deliberately failing logins repeatedly against a real account is only done here to confirm whether a policy existed. In production this kind of test would run against a dedicated test account, not a live staff member's credentials.

## Step 2: Configure the Account Lockout Policy

On DC1, opened Tools > **Group Policy Management**.

![Tools dropdown menu with Group Policy Management highlighted](images/63-tools-group-policy-management.png)

Right-clicked the **Default Domain Policy** (already linked to ashgroveclinic.com) and selected Edit.

![Group Policy Management console, right click context menu on Default Domain Policy with Edit highlighted](images/64-gpmc-default-domain-policy-edit.png)

Navigated to Computer Configuration > Policies > Windows Settings > Security Settings > Account Policies > **Account Lockout Policy**.

![Group Policy Management Editor showing the Account Lockout Policy node selected, with four available policy settings listed](images/65-gpme-account-lockout-policy-node.png)

Set:
- Account lockout duration: **30 minutes**
- Account lockout threshold: **5 invalid logon attempts**
- Reset account lockout counter after: **10 minutes**

![Account lockout duration Properties dialog set to 30 minutes](images/66-account-lockout-duration-properties.png)

![Group Policy Management Editor showing the configured Account Lockout Policy values: 30 minute duration, 5 invalid logon attempts, Not Defined for administrator lockout, 10 minute reset counter](images/67-gpme-account-lockout-configured.png)

## Step 3: Force the Policy Onto client1

On client1, opened Command Prompt and ran:

```
gpupdate /force
```

Both Computer Policy and User Policy updates completed successfully.

![Command Prompt on client1 showing gpupdate /force run successfully](images/68-gpupdate-force-success.png)

## Step 4: Confirm the Lockout Policy Works

Repeated the failed-login test against tasha.combs, entering the wrong password 5 to 7 times.

**Result:** the account locked out after the 5th attempt, exactly as configured.

![Remote Desktop Connection error stating the account has been locked because there were too many logon attempts](images/69-rdp-error-account-locked.png)

## Step 5: Unlock the Account

On DC1, opened Active Directory Users and Computers, found **tasha.combs**, right-clicked > Properties > **Account** tab.

![tasha.combs Properties, Account tab, showing the Unlock account checkbox unchecked, with text confirming the account is currently locked out](images/71-tasha-account-tab-unlock-unchecked.png)

Checked **Unlock account** and clicked Apply.

![tasha.combs Properties, Account tab, showing the Unlock account checkbox now checked](images/72-tasha-account-tab-unlock-checked.png)

Retried the login with the correct password. It succeeded.

![Windows Security credentials prompt for ashgroveclinic.com\\tasha.combs, retrying the login after the account was unlocked](images/73-windows-security-retry-after-unlock.png)

## Step 6: Reset a Password

Right-clicked the account in Active Directory Users and Computers > **Reset Password**, entered a new password. This is a separate action from unlocking, unlocking clears the failed-attempt counter, it doesn't change the password.

**Homelab note:** every account in this lab uses a shared, non-expiring password (Password1) for convenience. A real reset would issue a unique temporary password and force a change at next login.

## Step 7: Disable and Re-Enable an Account

Right-clicked tasha.combs > **Disable Account**, simulating a staff departure or compromised credential.

![Right click context menu on tasha.combs showing Disable Account highlighted](images/74-disable-account-context-menu.png)

Attempted a login, confirmed it was rejected specifically because the account was disabled.

![Remote Desktop Connection error stating the user account is currently disabled and cannot be used](images/75-disabled-account-rdp-error.png)

Re-enabling follows the same process in reverse: right-click the account > **Enable Account**.

## Step 8: Review Authentication Logs

On client1, searched for and opened **Event Viewer**.

![Search box showing Event Viewer as the best match result](images/76-search-event-viewer.png)

Expanded Windows Logs > Security. The Overview and Summary screen confirmed both the failed login attempts (Audit Failure) and the eventual successful login (Audit Success) were logged as discrete events. Failed logons appear under Event ID 4625, successful ones under 4624.

![Event Viewer Overview and Summary screen, showing Audit Success and Audit Failure counts under the Security log summary](images/77-event-viewer-overview-summary.png)

Authentication events show up locally on whichever machine the login attempt was made against, which is why these are on client1's Security log rather than DC1's.

**End of Phase 4:** Ashgrove Clinic's domain enforces an account lockout policy (5 attempts, 30 minute lockout, 10 minute reset), and account unlock, password reset, disable/enable, and log review procedures are all demonstrated and working.

---

*Bridgeway Technology, Ashgrove Clinic engagement*
