# fonction cp_365_createuser
function cp_365_createuser {
    param (
        [parameter(mandatory = $true)]
        [string]$cheminfichiercsv
    )

    begin {
        # Installation du module Microsoft Graph API si besoin et importation.
        Install-Module -Name Microsoft.Graph

        # Connexion mggraph.
        $ClientId = "9e622d1a-2ab0-410e-888e-fac34de0d1ad"
        $TenantId = "c176a1c4-c9c2-405f-9f76-ab88af47ddc6"
        $ClientSecret = "qB08Q~0X~bCDKONSelteoW0W7UxFmLmpE4w8HaZL"
        $Body = @{
            Grant_Type    = "client_credentials"
            Scope         = "https://graph.microsoft.com/.default"
            Client_Id     = $ClientId
            Client_Secret = $ClientSecret
        }

        # Récupérer le jeton d'accès
        $Connection = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method POST -Body $Body

        # Récupérer le jeton d'accès
        $token = $Connection.access_token

        # Convertir le jeton d'accès en SecureString
        $SecureToken = ConvertTo-SecureString $token -AsPlainText -Force

        # Se connecter à Microsoft Graph en utilisant le jeton d'accès sécurisé
        Connect-MgGraph -AccessToken $SecureToken

        # Importer les utilisateurs depuis le fichier CSV
        $utilisateurs = Import-CSV -Path $cheminfichiercsv -Delimiter ","
    }

    process {
        foreach ($utilisateur in $utilisateurs) {
            Try {
                # Vérifier si l'utilisateur existe dans Azure AD
                $user = Get-MgUser -UserId $utilisateur.UserPrincipalName -ErrorAction SilentlyContinue
                if ($null -ne $user) {
                    Write-Host "$($utilisateur.UserPrincipalName) - Existe dans Azure AD"
                }
                Else {
                    Write-Host "$($utilisateur.UserPrincipalName) - Création du compte dans Azure AD"

                    $PasswordProfile = @{
                        Password                             = $utilisateur.Password
                        ForceChangePasswordNextSignIn        = $true
                        ForceChangePasswordNextSignInWithMfa = $true
                    }

                    $utilisateurParams = @{
                        GivenName         = $utilisateur.GivenName
                        Surname           = $utilisateur.Surname
                        DisplayName       = $utilisateur.DisplayName
                        MailNickName      = $utilisateur.MailNickName
                        Mail              = $utilisateur.Mail
                        UserPrincipalName = $utilisateur.UserPrincipalName
                        Department        = $utilisateur.Service
                        JobTitle          = $utilisateur.JobTitle
                        #  MobilePhone       = $utilisateur.MobilePhone
                        Country           = $utilisateur.Country
                        AccountEnabled    = $true
                        PasswordProfile   = $PasswordProfile
                    }
                    # Création de l'utilisateur
                    New-MgUser @utilisateurParams -ErrorAction stop

                    # Création du groupe
                    $groupes = $utilisateur.Groupes -split ';'
            
                    foreach ($groupe in $groupes) {
                        $Groupid = (Get-MgGroup | Where-Object { $_.DisplayName -eq "$($groupe)" }).id
                        $odadaID = "https://graph.microsoft.com/v1.0/users/" + [System.Uri]::EscapeDataString($utilisateur.UserPrincipalName)
                        New-MgGroupMemberByRef -GroupId $GroupId -OdataId $odadaID -erroraction SilentlyContinue
                    }
           
                    # Affichage des infos utilisateurs
                    Get-MgUser -UserId $utilisateur.UserPrincipalName | select-object -Property GivenName, Surname, DisplayName, MailNickName, Mail, UserPrincipalName, Department, JobTitle, Country, AccountEnabled
                
                    # Attribution de la licence 365
                    #       $usageLocation = 'FR'
                    #         update-mguser -UserId $newUser.UserPrincipalName -usagelocation $usageLocation
                    #         Set-MgUserLicense -UserId $newUser.Id -AddLicenses @{SkuId = '3b555118-da6a-4418-894f-7df1e2096870' } -RemoveLicenses @()
                }
            }
            Catch {
                # Afficher un avertissement en cas d'erreur
                Write-Warning "Une erreur est survenue lors de la création de l'utilisateur $($utilisateur.UserPrincipalName)"
                Write-Host $_.Exception.Message 
            }
        }
    }
}

