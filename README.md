# 🎮🕒 MasterMind & Clock – Progetti Flutter

Questa repository contiene **due applicazioni Flutter**, entrambe pensate come esercizi didattici:

---

## 📍 1) MasterMind (Gioco)

Una semplice versione del gioco **MasterMind**, dove il giocatore deve indovinare una combinazione segreta di colori o numeri.

### ✨ Funzionalità
- Generazione casuale della combinazione segreta  
- Inserimento tentativi da parte del giocatore  
- Feedback visivo su:
  - elementi corretti e nella posizione giusta  
  - elementi corretti ma nella posizione sbagliata  
- Conteggio dei tentativi
- Interfaccia Flutter semplice e intuitiva

---

## 📍 2) Clock / Cronometro con Stream

Un cronometro realizzato in Flutter che utilizza **due Stream** indipendenti:

- ⏱ **Stream secondi** → emette un valore ogni 1 secondo  
- ⚡ **Stream tick** → emette un valore ogni 200 ms  

Il cronometro mostra:
- tempo totale (mm:ss)
- numero di tick calcolati solo mentre il cronometro è attivo

### ✨ Funzionalità
- START  
- STOP  
- RESET  
- PAUSE  
- RESUME  

### 🔧 Tecnologie usate
- `Stream.periodic`  
- `StreamSubscription`  
- `setState()` per aggiornare l'interfaccia  
- gestione semplice degli stati con variabili booleane

---

## 📂 Struttura della repository

