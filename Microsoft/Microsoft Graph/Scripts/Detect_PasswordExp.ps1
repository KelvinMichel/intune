# Script gestão de usuários e senhas expiradas 
# Resumo: Este script valida todos os usuários do tenant, calcula com base em uma política de expiração de senha de 90 dias e
# adiciona a um grupo específico os usuários que a senha vai expirar dentro de 10 dias, o script também remove do grupo os usuários que a senha já foi trocada;
# o objetivo deste grupo é usá-lo diariamente (tem que executar ele em alguma máquina, como uma tarefa agendada por exemplo), desta forma os usuários serão adicionados ao grupo
# este grupo será usado em um script de remédio do intune, o script de remédio em questão irá disparar uma notificação em tela para os usuários deste grupo, no meu caso, 
# a janela com o pop-up direciona o usuário a um porta em específico. 
# o Script com o código da janela pop-up está dentro de Intune -> Scripts

# Variáveis da aplicação
$tenantId = "" # ID do tenant
$clientId = "" # ID do client da aplicação
$clientSecret = "" # Secret code da aplicação
$groupId = ""  # ID do grupo no qual os usuários serão adicionados

# Solicitar token de acesso
$body = @{
    grant_type    = "client_credentials"
    scope         = "https://graph.microsoft.com/.default"
    client_id     = $clientId
    client_secret = $clientSecret
}
$tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Method Post -Body $body
$headers = @{
    Authorization = "Bearer $($tokenResponse.access_token)"
}

# Função para verificar quem já está no grupo
function Get-GroupMembers {
    param (
        [string]$groupId,
        [hashtable]$headers
    )

    $groupMembersUrl = "https://graph.microsoft.com/v1.0/groups/$groupId/members"
    $membersResponse = Invoke-RestMethod -Headers $headers -Uri $groupMembersUrl -Method Get
    return $membersResponse.value
}

# Função para adicionar usuário ao grupo
function Add-UserToGroup {
    param (
        [string]$userId,
        [string]$groupId,
        [hashtable]$headers
    )

    $addUserToGroupUrl = "https://graph.microsoft.com/v1.0/groups/$groupId/members/`$ref"
    $groupMembershipBody = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/users/$userId"
    } | ConvertTo-Json

    try {
        Invoke-RestMethod -Headers $headers -Uri $addUserToGroupUrl -Method Post -Body $groupMembershipBody -ContentType "application/json"
        Write-Output "Usuário: $($user.userPrincipalName), ID: $($user.id), adicionado ao grupo com sucesso."
    }
    catch {
        Write-Output "Erro ao adicionar $userId ao grupo: $_"
    }
}

# Função para remover usuário do grupo
function Remove-UserFromGroup {
    param (
        [string]$userId,
        [string]$groupId,
        [hashtable]$headers
    )

    $removeUserFromGroupUrl = "https://graph.microsoft.com/v1.0/groups/$groupId/members/$userId/`$ref"

    try {
        Invoke-RestMethod -Headers $headers -Uri $removeUserFromGroupUrl -Method Delete
        Write-Output "Usuário: $($user.userPrincipalName), ID: $($user.id), removido do grupo com sucesso."
    }
    catch {
        Write-Output "Erro ao remover $userId do grupo: $_"
    }
}

# Obter os membros atuais do grupo
$groupMembers = Get-GroupMembers -groupId $groupId -headers $headers
$groupMemberIds = $groupMembers | ForEach-Object { $_.id }

# URL inicial para obter usuários
$url = 'https://graph.microsoft.com/beta/users?$select=displayName,userPrincipalName,id,lastPasswordChangeDateTime,accountEnabled,department'

# Lista para armazenar os resultados filtrados
$resultados = @()

do {
    # Fazer a solicitação para obter usuários
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

    foreach ($user in $response.value) {
        if ($user.accountEnabled -eq $true -and
            $user.department -ne $null -and
            ($user.userPrincipalName -like "*@email.com.br" -or $user.userPrincipalName -like "*@email2.com.br") -and #filtro para pegar contas específicas, ajuste a sua preferência
            ($user.displayName -like "*| Sua empresa*" -or $user.displayName -like "*| Sua empresa 2*")) {

            if ($user.lastPasswordChangeDateTime -ne $null) {
                try {
                    $lastPasswordChange = [datetime]::ParseExact($user.lastPasswordChangeDateTime, "MM/dd/yyyy HH:mm:ss", $null)
                }
                catch {
                    $lastPasswordChange = Get-Date $user.lastPasswordChangeDateTime
                }

                $expirationDate = $lastPasswordChange.AddDays(90)
                $daysToExpiration = ($expirationDate - (Get-Date)).Days

                # Adicionar ao grupo se faltarem 10 dias ou menos para a expiração
                if ($daysToExpiration -le 10 -and $daysToExpiration -ge 0) {
                    if (-not ($user.id -in $groupMemberIds)) {
                        Add-UserToGroup -userId $user.id -groupId $groupId -headers $headers
                    }
                }
                # Adicionar ao grupo se a data de expiração for negativa
                elseif ($daysToExpiration -lt 0) {
                    if (-not ($user.id -in $groupMemberIds)) {
                        Add-UserToGroup -userId $user.id -groupId $groupId -headers $headers
                    }
                }
                # Remover do grupo se a expiração for maior que 10 dias
                elseif ($daysToExpiration -gt 10) {
                    if ($user.id -in $groupMemberIds) {
                        Remove-UserFromGroup -userId $user.id -groupId $groupId -headers $headers
                    }
                }

                # Adicionar os usuários que atendem aos critérios à lista de resultados
                $resultados += [pscustomobject]@{
                    DisplayName                = $user.displayName
                    UserPrincipalName          = $user.userPrincipalName
                    Department                 = $user.department
                    LastPasswordChangeDateTime = $user.lastPasswordChangeDateTime
                    PasswordExpirationDate     = $expirationDate
                    DaysToExpiration           = $daysToExpiration
                }

                Write-Output "Usuário: $($user.userPrincipalName), ID: $($user.id), Data Última Troca da Senha: $($user.lastPasswordChangeDateTime)"
            }
        }
    }

    # Verificar se há mais páginas de resultados
    if ($null -ne $response.'@odata.nextLink') {
        $url = $response.'@odata.nextLink'
    }
    else {
        $url = $null
    }
} while ($url -ne $null)

# Exportar todos os resultados para um CSV
$exportPath = "C:\Logs\Password EXP\"
$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$csvFileName = "lista_usuários_senha_exp_$timestamp.csv"

# Criar a pasta se não existir
if (-not (Test-Path -Path $exportPath)) {
    New-Item -ItemType Directory -Path $exportPath | Out-Null
}

# Exportar todos os resultados para CSV com codificação UTF-8
if ($resultados.Count -gt 0) {
    $resultados | Export-Csv -Path (Join-Path -Path $exportPath -ChildPath $csvFileName) -NoTypeInformation -Encoding UTF8
}
$resultados | Format-Table -AutoSize #exibe o resultado em tela