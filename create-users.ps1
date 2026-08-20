# ============================================================
# ASHGROVE CLINIC - Bulk Staff Account Creation Script
# Bridgeway Technology / Active Directory Lab, Phase 3
#
# Creates 5 named Ashgrove Clinic staff accounts in their correct
# department OUs, plus a batch of additional staff with real
# first/last names randomly distributed across the department OUs.
#
# Run this on DC1, in PowerShell ISE, as Administrator.
# Requires the _IT, CLINICAL, _FRONT DESK, and _FINANCE OUs to
# already exist directly under ashgroveclinic.com.
# ============================================================

# ----- Edit these Variables for your own Use Case ----- #
$PASSWORD_FOR_USERS      = "Password1"
$NUMBER_OF_RANDOM_USERS  = 15
$DEPARTMENT_OUS          = @("_IT", "CLINICAL", "_FRONT DESK", "_FINANCE")
# ------------------------------------------------------ #

$domainDN = ([ADSI]"").distinguishedName

$firstNames = @(
    "James","Maria","Michael","Sarah","David","Jennifer","Robert","Linda",
    "William","Patricia","Christopher","Elizabeth","Daniel","Susan","Matthew","Jessica",
    "Anthony","Karen","Mark","Nancy","Steven","Lisa","Paul","Betty",
    "Andrew","Margaret","Joshua","Sandra","Kevin","Ashley","Brian","Kimberly",
    "George","Emily","Edward","Donna","Ronald","Michelle","Timothy","Carol",
    "Jason","Amanda","Jeffrey","Melissa","Ryan","Deborah","Jacob","Stephanie",
    "Gary","Rebecca"
)

$lastNames = @(
    "Smith","Johnson","Williams","Brown","Jones","Garcia","Miller","Davis",
    "Rodriguez","Martinez","Hernandez","Lopez","Gonzalez","Wilson","Anderson","Thomas",
    "Taylor","Moore","Jackson","Martin","Lee","Perez","Thompson","White",
    "Harris","Sanchez","Clark","Ramirez","Lewis","Robinson","Walker","Young",
    "Allen","King","Wright","Scott","Torres","Nguyen","Hill","Flores",
    "Green","Adams","Nelson","Baker","Hall","Rivera","Campbell","Mitchell",
    "Carter","Roberts"
)

Function create-ad-user($firstName, $lastName, $username, $ouName) {
    $ouPath = "OU=$ouName,$domainDN"

    if (Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue) {
        Write-Host "Skipping $username, already exists" -ForegroundColor Yellow
        return
    }

    $password = ConvertTo-SecureString $PASSWORD_FOR_USERS -AsPlainText -Force
    $samName  = $username.Substring(0, [Math]::Min(20, $username.Length))

    try {
        New-AdUser -AccountPassword $password `
                   -GivenName $firstName `
                   -Surname $lastName `
                   -DisplayName $username `
                   -Name $username `
                   -SamAccountName $samName `
                   -EmployeeID $username `
                   -PasswordNeverExpires $true `
                   -Path $ouPath `
                   -Enabled $true

        Write-Host "Created user: $username  (OU: $ouName)" -ForegroundColor Cyan
    }
    catch {
        Write-Host "FAILED to create $username  (OU: $ouName): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ----- Named Ashgrove Clinic staff ----- #
create-ad-user -firstName "Devon" -lastName "Ricci"  -username "devon.ricci" -ouName "_IT"
create-ad-user -firstName "Marcus" -lastName "Bell"   -username "marcus.bell" -ouName "_IT"
create-ad-user -firstName "Elena"  -lastName "Marsh"  -username "elena.marsh" -ouName "CLINICAL"
create-ad-user -firstName "Renee"  -lastName "Park"   -username "renee.park"  -ouName "_FRONT DESK"
create-ad-user -firstName "Tasha"  -lastName "Combs"  -username "tasha.combs" -ouName "_FINANCE"

# ----- Remaining staff, real names, randomly assigned to a department OU ----- #
$usedNames = @{}
$count = 1
while ($count -le $NUMBER_OF_RANDOM_USERS) {
    $firstName = $firstNames[$(Get-Random -Minimum 0 -Maximum $firstNames.Count)]
    $lastName  = $lastNames[$(Get-Random -Minimum 0 -Maximum $lastNames.Count)]
    $username  = ($firstName + '.' + $lastName).ToLower()

    if ($usedNames.ContainsKey($username)) {
        continue
    }
    $usedNames[$username] = $true

    $randomOU = $DEPARTMENT_OUS[$(Get-Random -Minimum 0 -Maximum $DEPARTMENT_OUS.Count)]

    create-ad-user -firstName $firstName -lastName $lastName -username $username -ouName $randomOU

    $count++
}

Write-Host "Done." -ForegroundColor Green
