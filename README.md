# XiaomiDebloater

Una finestra per Windows che mostra **tutte le app del tuo telefono Xiaomi, Redmi o POCO** e ti dice senza ambiguità quali sono **app di sistema che dal telefono non puoi disinstallare**. Con un clic le togli via ADB, e con un altro clic le rimetti.

Niente root, niente sblocco del bootloader, niente comandi da scrivere a mano.

## Cosa fa

- Legge le app **direttamente dal telefono** collegato via cavo USB.
- Le divide in sei schede:

| Scheda | Cosa contiene |
| --- | --- |
| 1. SISTEMA - rimovibili SOLO con ADB | App di sistema che dal telefono non si disinstallano ma si possono togliere senza rompere niente (es. YouTube, Mi Browser, Temi, Glance, MSA) |
| 2. ESSENZIALI - non toccare | App di sistema necessarie (Play Services, Telefono, Sicurezza, Home, Impostazioni...) |
| 3. Rimovibili dal telefono | App che puoi già togliere tenendo premuta l'icona |
| 4. Rimosse | App tolte con ADB, da spuntare per ripristinarle |
| 5. Componenti tecnici | Parti interne senza icona |
| 6. Tutte | Tutti i pacchetti |

- Per ogni app mostra nome, pacchetto, descrizione in italiano, **numero di traccianti e reti pubblicitarie trovati nel codice**, stato (installata, disattivata, rimossa) e se si può togliere dal telefono o solo con ADB.
- Le app essenziali sono in rosso. Se ne selezioni una, ti avvisa e chiede una seconda conferma.
- Ogni rimozione e ripristino viene registrato in `rimosse_storico.txt`.

## Come si usa

1. Sul telefono attiva le **Opzioni sviluppatore**: Impostazioni → Informazioni sul telefono → tocca 7 volte "Versione OS".
2. In Impostazioni → Impostazioni aggiuntive → Opzioni sviluppatore attiva **Debug USB**.
3. Scarica questo progetto (pulsante verde **Code → Download ZIP**) ed estrailo in una cartella.
4. Collega il telefono al PC con il cavo e fai doppio clic su **`XiaomiDebloater.bat`**.
   Al primo avvio scarica da solo gli strumenti ADB ufficiali di Google.
5. Sul telefono tocca **Consenti** alla richiesta di debug USB e premi "Aggiorna dal telefono".
6. Spunta le app e premi **Rimuovi selezionate** o **Ripristina selezionate**.

## È sicuro?

La rimozione usa `pm uninstall -k --user 0`: l'app viene tolta **solo per il tuo utente**, mentre il file originale resta nella memoria di sistema. Per questo:

- si rimette in qualsiasi momento con "Ripristina" (`cmd package install-existing`), senza scaricare niente;
- un ripristino di fabbrica riporta tutto com'era.

Togliere un'app essenziale può far smettere di funzionare chiamate, notifiche o installazioni. Per questo sono separate in una scheda a parte e protette da doppia conferma. Lo usi a tuo rischio.

## Da dove vengono i dati

- **Sistema o no**: letto dal telefono in tempo reale (`pm list packages -s`), quindi vale per qualsiasi modello.
- **Traccianti e reti pubblicitarie** (`traccianti.csv`): misurati cercando le firme di 84 SDK di analisi e pubblicità nel codice di ogni app, sul principio di Exodus Privacy, su un REDMI Note 15 Pro+ 5G con HyperOS 3.0 (Android 16, ROM global, novembre 2026). Su altri modelli i numeri possono cambiare.
- **Descrizioni** (`descrizioni_app.json`) e **nomi** (`nomi_app.json`): scritti a mano. Le app senza descrizione mostrano una dicitura generica.

## Requisiti

- Windows 10 o 11 (usa PowerShell e Windows Forms, già presenti).
- Un telefono Xiaomi, Redmi o POCO con MIUI o HyperOS e Debug USB attivo.

## Licenza

MIT. Vedi [LICENSE](LICENSE).
