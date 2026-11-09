---
name: "Bug melden / Bug Report"
about: "Melde einen Fehler oder ein Anzeigeproblem in ELLA (DE / EN)"
title: "[Bug] "
labels: ["bug"]
---

### Beschreibung / Description
<!-- Was ist passiert und was hättest du erwartet? / What happened and what did you expect? -->

### Schritte zum Reproduzieren / Steps to Reproduce
1.
2.
3.

### Umgebung / Environment
- **ELLA Version:** (z. B. `v1.9.1`)
- **Client-Sprache / Locale:** (`deDE` / `enUS`)
- **Auflösung / Resolution:** (z. B. `2560x1440`, `1920x1080`, `1280x800`)
- **Betroffenes Fenster / Window:** (z. B. `CharacterFrame`, Drittanbieter-AddOn)

### Lua-Fehlermeldung oder Screenshot (optional)
<!-- Füge hier ggf. einen Lua-Error oder Screenshot ein -->

### ELLA-Diagnose (optional)

Mit `/ella debug` kannst du einen Diagnosebericht öffnen. Prüfe den Text vor dem Kopieren.
Bitte füge bei Bedarf den Diagnosebericht ein und halte private Profilcodes separat.

Auszug aus einem fiktiven Bericht:

```text
ella_diagnostics=2
client_interface=16001
combat_pending=0
CHARACTER state=bound mode=SCALE_AND_MOVE candidate=primary
window_2 state=waiting_for_addon mode=DISABLED candidate=-
addon_bindings_pending=1
```

Eigene Fenster erscheinen nummeriert. `candidate` ist `primary` für den
primären Frame, eine Nummer für einen alternativen Kandidaten oder `-`.
