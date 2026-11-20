# XiaomiDebloater - interfaccia grafica per vedere, rimuovere e ripristinare via ADB le app di sistema dei telefoni Xiaomi/Redmi/POCO
# https://github.com/HokutoNoCode/XiaomiDebloater - Licenza MIT
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$base = Split-Path -Parent $MyInvocation.MyCommand.Path
$adb  = Join-Path $base 'platform-tools\adb.exe'
$csvPath   = Join-Path $base 'traccianti.csv'
$nomiPath  = Join-Path $base 'nomi_app.json'
$storico   = Join-Path $base 'rimosse_storico.txt'
$script:serial = $null

# App da NON togliere: rompono il telefono o funzioni importanti
$essenziali = @(
 'android','com.android.systemui','com.android.settings','com.android.phone','com.android.vending',
 'com.google.android.gms','com.google.android.gsf','com.google.android.dialer','com.google.android.contacts',
 'com.android.mms','com.google.android.apps.messaging','com.android.camera','com.miui.gallery',
 'com.miui.securitycenter','com.miui.home','com.android.providers.downloads.ui','com.mi.android.globalFileexplorer',
 'com.xiaomi.xmsf','com.xiaomi.account','com.xiaomi.finddevice','com.miui.powerkeeper','com.lbe.security.miui',
 'com.miui.global.packageinstaller','com.google.android.packageinstaller','com.google.android.permissioncontroller',
 'com.android.updater','com.miui.core','com.miui.system','com.miui.rom','com.xiaomi.incallui','com.xiaomi.phone',
 'com.google.android.webview','com.android.server.telecom',
 'com.android.providers.contacts','com.android.providers.telephony','com.android.providers.media',
 'com.android.providers.settings','com.android.nfc','com.android.bluetooth','com.xiaomi.joyose','miui.systemui.plugin'
)

function Invoke-Adb([string]$argomenti, [int]$timeoutMs = 30000) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $adb
  $psi.Arguments = $argomenti
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true
  $p = [System.Diagnostics.Process]::Start($psi)
  $o = $p.StandardOutput.ReadToEndAsync()
  $e = $p.StandardError.ReadToEndAsync()
  if (-not $p.WaitForExit($timeoutMs)) { try { $p.Kill() } catch {} ; return 'TIMEOUT: il telefono non ha risposto' }
  return ($o.Result + $e.Result).Trim()
}

function Get-Seriale {
  $out = Invoke-Adb 'devices' 15000
  foreach ($riga in ($out -split "`r?`n")) {
    if ($riga -match '^(\S+)\s+device$' -and $Matches[1] -notmatch ':') { return $Matches[1] }
  }
  return $null
}

function Get-Pacchetti([string]$opzioni) {
  $out = Invoke-Adb "-s $script:serial shell pm list packages $opzioni"
  $set = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($r in ($out -split "`r?`n")) { if ($r -match '^package:(\S+)') { [void]$set.Add($Matches[1]) } }
  return ,$set
}

# --- dati dell'analisi ---
$info = @{}
if (Test-Path $csvPath) {
  foreach ($r in (Import-Csv -Path $csvPath -Delimiter ';' -Encoding UTF8)) { $info[$r.Pacchetto] = $r }
}
$nomi = @{}
if (Test-Path $nomiPath) {
  $j = Get-Content -Raw -Encoding UTF8 $nomiPath | ConvertFrom-Json
  foreach ($pr in $j.PSObject.Properties) { $nomi[$pr.Name] = $pr.Value }
}

$descr = @{}
$descrPath = Join-Path $base 'descrizioni_app.json'
if (Test-Path $descrPath) {
  $j2 = Get-Content -Raw -Encoding UTF8 $descrPath | ConvertFrom-Json
  foreach ($pr in $j2.PSObject.Properties) { $descr[$pr.Name] = $pr.Value }
}

# --- tabella ---
$tab = New-Object System.Data.DataTable
[void]$tab.Columns.Add('Sel', [bool])
[void]$tab.Columns.Add('Nome', [string])
[void]$tab.Columns.Add('Pacchetto', [string])
[void]$tab.Columns.Add('Tipo', [string])
[void]$tab.Columns.Add('DalTelefono', [string])
[void]$tab.Columns.Add('Traccianti', [int])
[void]$tab.Columns.Add('Pubblicita', [string])
[void]$tab.Columns.Add('Stato', [string])
[void]$tab.Columns.Add('Nota', [string])
[void]$tab.Columns.Add('Descrizione', [string])

function Get-Tipo([string]$pkg, $sistema) {
  if ($essenziali -contains $pkg) { return 'ESSENZIALE' }
  if ($sistema.Contains($pkg)) {
    if ($nomi.ContainsKey($pkg)) { return 'SISTEMA - solo ADB' }
    return 'Componente tecnico'
  }
  $cat = ''
  if ($info.ContainsKey($pkg)) { $cat = $info[$pkg].Categoria }
  if ($cat -eq 'Preinstallata (rimovibile)') { return 'Preinstallata, rimovibile' }
  return 'Installata da te'
}

function Aggiorna-Elenco {
  $lblStato.Text = 'Cerco il telefono via cavo USB...'
  $form.Refresh()
  $script:serial = Get-Seriale
  if (-not $script:serial) {
    $lblStato.Text = 'Telefono NON trovato: collegalo via cavo USB con Debug USB attivo, sbloccalo, accetta la richiesta sul telefono e premi Aggiorna.'
    $lblStato.ForeColor = [System.Drawing.Color]::Firebrick
    return
  }
  $lblStato.Text = "Leggo le app dal telefono $script:serial ..."
  $form.Refresh()
  $installate = Get-Pacchetti ''
  $tutte      = Get-Pacchetti '-u'
  $disatt     = Get-Pacchetti '-d'
  $sistema    = Get-Pacchetti '-s -u'
  $tab.Rows.Clear()
  foreach ($pkg in $tutte) {
    $riga = $tab.NewRow()
    $riga.Sel = $false
    $riga.Pacchetto = $pkg
    if ($nomi.ContainsKey($pkg)) { $riga.Nome = $nomi[$pkg] } else { $riga.Nome = ($pkg -split '\.')[-1] }
    $riga.Tipo = Get-Tipo $pkg $sistema
    if ($sistema.Contains($pkg)) { $riga.DalTelefono = 'NO - solo con ADB' } else { $riga.DalTelefono = 'Si, dalle Impostazioni' }
    $n = 0
    if ($info.ContainsKey($pkg)) {
      [int]::TryParse($info[$pkg].'N. traccianti', [ref]$n) | Out-Null
      $riga.Pubblicita = $info[$pkg].'SDK pubblicitari'
    }
    $riga.Traccianti = $n
    if ($installate.Contains($pkg)) {
      if ($disatt.Contains($pkg)) { $riga.Stato = 'Disattivata' } else { $riga.Stato = 'Installata' }
    } else { $riga.Stato = 'Rimossa' }
    if ($essenziali -contains $pkg) { $riga.Nota = 'ESSENZIALE: non toglierla' } else { $riga.Nota = '' }
    if ($descr.ContainsKey($pkg)) { $riga.Descrizione = $descr[$pkg] }
    else {
      switch ($riga.Tipo) {
        'Installata da te' { $riga.Descrizione = 'App installata da te.' }
        'Preinstallata, rimovibile' { $riga.Descrizione = 'App preinstallata che puoi togliere anche dal telefono.' }
        'Componente tecnico' { $riga.Descrizione = 'Parte interna di Android/Qualcomm/Xiaomi senza icona.' }
        default { $riga.Descrizione = 'App di sistema.' }
      }
    }
    $tab.Rows.Add($riga)
  }
  Applica-Filtro
  $nInst = ($tab.Select("Stato <> 'Rimossa'")).Count
  $nRim  = ($tab.Select("Stato = 'Rimossa'")).Count
  $nAdb  = ($tab.Select("Tipo = 'SISTEMA - solo ADB' AND Stato <> 'Rimossa'")).Count
  $nEss  = ($tab.Select("Tipo = 'ESSENZIALE' AND Stato <> 'Rimossa'")).Count
  $lblStato.Text = "Telefono $script:serial collegato - $nInst app presenti, di cui $nAdb di sistema rimovibili SOLO con ADB e $nEss essenziali - $nRim rimosse."
  $lblStato.ForeColor = [System.Drawing.Color]::DarkGreen
}

function Applica-Filtro {
  $f = switch ($tabs.SelectedIndex) {
    0 { "Tipo = 'SISTEMA - solo ADB' AND Stato <> 'Rimossa'" }
    1 { "Tipo = 'ESSENZIALE' AND Stato <> 'Rimossa'" }
    2 { "(Tipo = 'Preinstallata, rimovibile' OR Tipo = 'Installata da te') AND Stato <> 'Rimossa'" }
    3 { "Stato = 'Rimossa'" }
    4 { "Tipo = 'Componente tecnico' AND Stato <> 'Rimossa'" }
    default { "1 = 1" }
  }
  $t = $txtCerca.Text.Trim()
  if ($t -ne '') {
    $t = $t -replace "'", "''" -replace '\[', '[[]' -replace '%', '[%]' -replace '\*', '[*]'
    $f += " AND (Nome LIKE '%$t%' OR Pacchetto LIKE '%$t%')"
  }
  $tab.DefaultView.RowFilter = $f
  $tab.DefaultView.Sort = 'Traccianti DESC, Nome ASC'
  $tabs.SelectedTab.Controls.Add($grid)
  $lblDesc.Text = $descrizioni[$tabs.SelectedIndex] + "   (" + $tab.DefaultView.Count + " app)"
}

function Get-Selezionate {
  $grid.EndEdit()
  return @($tab.Select('Sel = true'))
}

function Scrivi-Log([string]$t) {
  $txtLog.AppendText($t + "`r`n")
}

function Esegui([string]$azione) {
  if (-not $script:serial) { [System.Windows.Forms.MessageBox]::Show('Telefono non collegato. Premi Aggiorna.') | Out-Null; return }
  $sel = Get-Selezionate
  if ($sel.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show('Spunta almeno un''app nella prima colonna.') | Out-Null; return }
  $elenco = ($sel | ForEach-Object { '- ' + $_.Nome + '  (' + $_.Pacchetto + ')' }) -join "`r`n"
  if ($azione -eq 'rimuovi') {
    $ess = @($sel | Where-Object { $_.Nota -ne '' })
    if ($ess.Count -gt 0) {
      $lista = ($ess | ForEach-Object { '- ' + $_.Nome }) -join "`r`n"
      $r = [System.Windows.Forms.MessageBox]::Show("ATTENZIONE: queste sono essenziali e toglierle puo' rompere il telefono:`r`n$lista`r`n`r`nVuoi davvero toglierle?", 'App essenziali', 'YesNo', 'Warning')
      if ($r -ne 'Yes') { return }
    }
    $r = [System.Windows.Forms.MessageBox]::Show("Tolgo queste app? (reversibile)`r`n`r`n$elenco", 'Conferma rimozione', 'YesNo', 'Question')
  } else {
    $r = [System.Windows.Forms.MessageBox]::Show("Rimetto queste app?`r`n`r`n$elenco", 'Conferma ripristino', 'YesNo', 'Question')
  }
  if ($r -ne 'Yes') { return }
  $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
  foreach ($row in $sel) {
    $pkg = $row.Pacchetto
    if ($azione -eq 'rimuovi') {
      $out = Invoke-Adb "-s $script:serial shell pm uninstall -k --user 0 $pkg"
      if ($out -match 'Success') { Add-Content -Path $storico -Value ("{0}  RIMOSSA  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $pkg) }
    } else {
      $out = Invoke-Adb "-s $script:serial shell cmd package install-existing $pkg"
      if ($out -match 'installed') { Add-Content -Path $storico -Value ("{0}  RIPRISTINATA  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $pkg) }
    }
    Scrivi-Log ("{0} - {1}: {2}" -f $row.Nome, $pkg, $out)
    $form.Refresh()
  }
  $form.Cursor = [System.Windows.Forms.Cursors]::Default
  Aggiorna-Elenco
}

# --- finestra ---
$form = New-Object System.Windows.Forms.Form
$form.Text = 'XiaomiDebloater - gestione app di sistema via ADB'
$form.Size = New-Object System.Drawing.Size(1400, 800)
$form.WindowState = 'Maximized'
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

$top = New-Object System.Windows.Forms.Panel
$top.Dock = 'Top'; $top.Height = 72

$lblStato = New-Object System.Windows.Forms.Label
$lblStato.Location = '10,8'; $lblStato.Size = '1100,22'
$lblStato.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Dock = 'Fill'
$tabs.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$titoli = @('1. SISTEMA - rimovibili SOLO con ADB','2. ESSENZIALI - non toccare','3. Rimovibili dal telefono','4. Rimosse (ripristinabili)','5. Componenti tecnici','6. Tutte')
foreach ($ti in $titoli) { $tp = New-Object System.Windows.Forms.TabPage; $tp.Text = $ti; [void]$tabs.TabPages.Add($tp) }
$descrizioni = @(
 'App di sistema NON essenziali: dal telefono non si disinstallano, con ADB si possono togliere senza rompere niente.',
 'App di sistema ESSENZIALI: servono a chiamate, notifiche, installazioni o al funzionamento. Non toglierle.',
 'App normali: le puoi disinstallare anche dal telefono, tenendo premuta l''icona o da Impostazioni > App.',
 'App tolte con ADB: spuntale e premi Ripristina per rimetterle.',
 'Parti interne di Android, Qualcomm e Xiaomi senza icona: non toccarle se non sai cosa sono.',
 'Tutti i pacchetti presenti sul telefono.'
)
$lblDesc = New-Object System.Windows.Forms.Label
$lblDesc.Location = '10,40'; $lblDesc.Size = '660,22'

$lblC = New-Object System.Windows.Forms.Label
$lblC.Text = 'Cerca:'; $lblC.Location = '680,41'; $lblC.AutoSize = $true

$txtCerca = New-Object System.Windows.Forms.TextBox
$txtCerca.Location = '730,37'; $txtCerca.Width = 200

$btnAgg = New-Object System.Windows.Forms.Button
$btnAgg.Text = 'Aggiorna dal telefono'; $btnAgg.Location = '945,35'; $btnAgg.Size = '170,28'

$top.Controls.AddRange(@($lblStato,$lblDesc,$lblC,$txtCerca,$btnAgg))

$grid = New-Object System.Windows.Forms.DataGridView
$grid.Dock = 'Fill'
$grid.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.RowHeadersVisible = $false
$grid.SelectionMode = 'FullRowSelect'
$grid.AutoSizeColumnsMode = 'Fill'
$grid.DataSource = $tab.DefaultView

$bottom = New-Object System.Windows.Forms.Panel
$bottom.Dock = 'Bottom'; $bottom.Height = 150

$btnRim = New-Object System.Windows.Forms.Button
$btnRim.Text = 'Rimuovi selezionate'; $btnRim.Location = '10,8'; $btnRim.Size = '190,34'
$btnRim.BackColor = [System.Drawing.Color]::MistyRose

$btnRip = New-Object System.Windows.Forms.Button
$btnRip.Text = 'Ripristina selezionate'; $btnRip.Location = '210,8'; $btnRip.Size = '190,34'
$btnRip.BackColor = [System.Drawing.Color]::Honeydew

$lblAiuto = New-Object System.Windows.Forms.Label
$lblAiuto.Location = '415,10'; $lblAiuto.Size = '700,34'
$lblAiuto.Text = 'Spunta le app nella prima colonna. La rimozione vale per il tuo utente ed e'' reversibile con "Ripristina". Le righe in rosso sono essenziali.'

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true; $txtLog.ScrollBars = 'Vertical'; $txtLog.ReadOnly = $true
$txtLog.Location = '10,50'; $txtLog.Size = '1110,90'
$txtLog.Anchor = 'Left,Right,Top,Bottom'

$bottom.Controls.AddRange(@($btnRim,$btnRip,$lblAiuto,$txtLog))

$form.Controls.Add($tabs)
$form.Controls.Add($bottom)
$form.Controls.Add($top)

$grid.add_DataBindingComplete({
  foreach ($c in $grid.Columns) { if ($c.Name -ne 'Sel') { $c.ReadOnly = $true } }
  if ($grid.Columns['Sel']) { $grid.Columns['Sel'].HeaderText = ''; $grid.Columns['Sel'].FillWeight = 12 }
  if ($grid.Columns['Nome']) { $grid.Columns['Nome'].FillWeight = 70 }
  if ($grid.Columns['Pacchetto']) { $grid.Columns['Pacchetto'].FillWeight = 95 }
  if ($grid.Columns['Tipo']) { $grid.Columns['Tipo'].FillWeight = 55 }
  if ($grid.Columns['DalTelefono']) { $grid.Columns['DalTelefono'].HeaderText = 'Si toglie dal telefono?'; $grid.Columns['DalTelefono'].FillWeight = 55 }
  if ($grid.Columns['Traccianti']) { $grid.Columns['Traccianti'].FillWeight = 30 }
  if ($grid.Columns['Pubblicita']) { $grid.Columns['Pubblicita'].HeaderText = 'Reti pubblicitarie nel codice'; $grid.Columns['Pubblicita'].FillWeight = 80 }
  if ($grid.Columns['Stato']) { $grid.Columns['Stato'].FillWeight = 35 }
  if ($grid.Columns['Nota']) { $grid.Columns['Nota'].Visible = $false }
  if ($grid.Columns['Descrizione']) { $grid.Columns['Descrizione'].FillWeight = 190 }
  if ($grid.Columns['Pacchetto']) { $grid.Columns['Pacchetto'].FillWeight = 75 }
  foreach ($r in $grid.Rows) {
    $v = $r.DataBoundItem
    if ($null -eq $v) { continue }
    if ($v['Nota'] -ne '') { $r.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Firebrick }
    elseif ($v['Stato'] -eq 'Rimossa') { $r.DefaultCellStyle.ForeColor = [System.Drawing.Color]::Gray }
    if ($v['DalTelefono'] -like 'NO*') { $r.Cells['DalTelefono'].Style.BackColor = [System.Drawing.Color]::LightSalmon; $r.Cells['DalTelefono'].Style.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold) }
    if ($v['Traccianti'] -ge 10) { $r.Cells['Traccianti'].Style.BackColor = [System.Drawing.Color]::Moccasin }
  }
})
$grid.add_CurrentCellDirtyStateChanged({ if ($grid.IsCurrentCellDirty) { $grid.CommitEdit('CurrentCellChange') | Out-Null } })

$tabs.add_SelectedIndexChanged({ Applica-Filtro })
$txtCerca.add_TextChanged({ Applica-Filtro })
$btnAgg.add_Click({ Aggiorna-Elenco })
$btnRim.add_Click({ Esegui 'rimuovi' })
$btnRip.add_Click({ Esegui 'ripristina' })
$form.add_Shown({ Applica-Filtro; Aggiorna-Elenco })

[void]$form.ShowDialog()
