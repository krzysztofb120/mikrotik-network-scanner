Prosty skaner sieci oparty na Pythonie i narzędziu Nmap, umożliwiający automatyczne wykrywanie hostów oraz wykonywanie podstawowych operacji sieciowych. Projekt pozwala na skanowanie adresów IP, automatyczne uruchamianie skryptów, integrację z urządzeniami MikroTik oraz może być uruchamiany w środowisku Docker.

Przed uruchomieniem projektu należy samodzielnie zmodyfikować dane dostępowe, takie jak tokeny, klucze API, dane logowania do urządzeń oraz konfigurację SMTP (np. serwer, login i hasło) w pliku config.rsc.

Projekt nie zawiera prawdziwych danych dostępowych, dlatego wszystkie wrażliwe informacje należy uzupełnić ręcznie przed użyciem. Uruchomienie aplikacji odbywa się za pomocą polecenia python run_ssh.py.
