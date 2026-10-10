# Unser Raum

Ein kleiner, privater Ort für zwei: tägliche Gedanken, Versprechen, eine Liste mit Wünschen, Notizen zu Gesprächen und offene Fragen.

Die Seite selbst ist öffentlich erreichbar, die Inhalte nicht. Sie liegen in Supabase in einem eigenen Bereich, an den man nur mit einem persönlichen Link kommt. In diesem Repo stehen weder Inhalte noch Geheimnisse.

## Einrichtung

### 1. Datenbank

1. Im Supabase-Projekt den **SQL Editor** öffnen und eine neue Abfrage anlegen.
2. Den kompletten Inhalt von `setup.sql` einfügen und ausführen.
3. Optional: die private Startliste (nicht in diesem Repo) genauso ausführen.

### 2. Persönliche Links

Im SQL Editor für jede Person einmal ausführen:

```sql
select unser_raum.new_link('Name');
```

Das Ergebnis ist ein langer Code. Der persönliche Link lautet dann:

```
https://<github-name>.github.io/unser-raum/#k=<CODE>
```

Der Code wird nur einmal angezeigt und nirgends im Klartext gespeichert. Wer den Link hat, kann alles lesen und schreiben. Also nur direkt an die Person schicken.

### 3. GitHub Pages

Im Repo unter **Settings → Pages** als Quelle den Branch `main` und den Ordner `/ (root)` wählen und speichern. Nach etwa einer Minute ist die Seite online.

### 4. Auf dem Handy

- **iPhone:** Link in Safari öffnen, dann Teilen → „Zum Home-Bildschirm“.
- **Android:** Link in Chrome öffnen, dann Menü → „Zum Startbildschirm hinzufügen“.

Fragt die Seite nach dem Hinzufügen nach dem Link, ihn einfach einmal einfügen. Danach merkt sich das Gerät den Zugang.

## Link ersetzen

Ist ein Link in falsche Hände geraten oder verloren gegangen, im SQL Editor dieselbe Zeile noch einmal ausführen:

```sql
select unser_raum.new_link('Name');
```

Der alte Link funktioniert dann sofort nicht mehr. Alle Einträge bleiben erhalten.

## Technik

- `index.html`: die ganze Seite, ohne Build-Schritt
- `setup.sql`: Schema `unser_raum` mit RLS ohne Policies; Zugriff nur über die Funktionen `ur_load`, `ur_put` und `ur_delete`, die den Link prüfen (gespeichert wird nur ein SHA-256-Hash)
- Supabase pausiert Gratis-Projekte erst nach einer Woche ohne Nutzung
