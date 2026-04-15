import paramiko
import re
import os

os.chdir(os.path.dirname(__file__))
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

def execute_scan(ip_address):
    try:
        client.connect(ip_address, port=22, username='admin', password='1')

        stdin, stdout, stderr = client.exec_command('/system script run scan-and-send')

        output = stdout.read().decode('utf-8')
        error = stderr.read().decode('utf-8')

        ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
        output_clean = ansi_escape.sub('', output)
        error_clean = ansi_escape.sub('', error)

        print('Skanowanie zakończone')
        if error_clean:
            print('Error:', error_clean)

    except Exception as e:
        print(f'Błąd: {e}')
    finally:
        client.close()



ip_addresses = []

with open("ip_addresses.txt") as f:
  for x in f:
    ip_addresses.append(x.strip())

print(ip_addresses)

for ip_address in ip_addresses:
    print(f'Scanning Router: {ip_address}')
    execute_scan(ip_address)



