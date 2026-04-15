{       

# Konfiguracja VPN ,DHCP ,Wiregurad oraz STMP


# DNS i NTP
/ip dns set servers=8.8.8.8,1.1.1.1 allow-remote-requests=yes
/system ntp client set enabled=yes servers=pool.ntp.org

# Certyfikaty SSL
:if ([:len [/certificate find]] < 100) do={
    :put "Pobieram certyfikaty SSL..."
    /tool fetch url="https://curl.se/ca/cacert.pem"
    /certificate import file-name=cacert.pem passphrase=""
}

# Nadaje adres IP portowi
:if ([:len [/ip address find address="192.67.67.1/24" interface="ether2"]] = 0) do={
    /ip address add address=192.67.67.1/24 interface=ether2
    :put "Dodano adres IP dla ether2."
}

# Określa zakres adresów IP
:if ([:len [/ip pool find name="dhcp_pool"]] = 0) do={
    /ip pool add name=dhcp_pool ranges=192.67.67.10-192.67.67.50
    :put "Utworzono pule adresow DHCP."
}

# Tworzy i włącza serwer DHCP
:if ([:len [/ip dhcp-server find name="server1"]] = 0) do={
    /ip dhcp-server add name=server1 interface=ether2 address-pool=dhcp_pool disabled=no
    :put "Uruchomiono serwer DHCP."
}

# Konfiguruje bramę i serwery DNS
:if ([:len [/ip dhcp-server network find address="192.67.67.0/24"]] = 0) do={
    /ip dhcp-server network add address=192.67.67.0/24 gateway=192.67.67.1 dns-server=8.8.8.8
    :put "Dodano brame i DNS do konfiguracji DHCP."
}


# Provisioning 
#Zmienne lokalne które umożliwiąja połaczenie się z serwerem mailowym
:local siteId         ""
:local provisionUrl   ""
:local provisionToken ""

:put "Provisioning"
:local payload ("{\"token\":\"" . $provisionToken . "\",\"site_id\":\"" . $siteId . "\"}")
:local response [/tool fetch url=$provisionUrl http-method=post \
    http-header-field="Content-Type: application/json" \
    http-data=$payload output=user as-value]
:local body ($response->"data")

#Pobieranie odpiewiednich danych z odpiewiedzi serwera
:local wgPrivKey   [:pick $body ([:find $body "\"private_key\":\""] + 14)   [:find $body "\"" ([:find $body "\"private_key\":\""]   + 14)]]
:local wgServerPub [:pick $body ([:find $body "\"server_public_key\":\""] + 21) [:find $body "\"" ([:find $body "\"server_public_key\":\""] + 21)]]
:local wgPsk       [:pick $body ([:find $body "\"psk\":\""] + 7)             [:find $body "\"" ([:find $body "\"psk\":\""]             + 7)]]
:local wgIp        [:pick $body ([:find $body "\"ip\":\""] + 6)              [:find $body "\"" ([:find $body "\"ip\":\""]              + 6)]]
:local wgEndpoint  [:pick $body ([:find $body "\"server_endpoint\":\""] + 19) [:find $body "\"" ([:find $body "\"server_endpoint\":\""] + 19)]]
:local smtpHost    [:pick $body ([:find $body "\"smtp_host\":\""] + 13)      [:find $body "\"" ([:find $body "\"smtp_host\":\""]      + 13)]]

:put ("Provisioning — IP: " . $wgIp . ", SMTP: " . $smtpHost)
:if ($wgIp = "") do={
    :put "BLAD: Provisioning nie zwrocil danych. Sprawdz token i URL."
    :error "Provisioning failed"
}

# WireGuard
:put "WireGuard"

:if ([:len [/interface wireguard find name="wg-nas"]] = 0) do={
    /interface wireguard add name=wg-nas listen-port=13231 private-key=$wgPrivKey
    :put "WireGuard interface created."
} else={
    /interface wireguard set [find name="wg-nas"] private-key=$wgPrivKey
    :put "WireGuard interface updated."
}

:local existingWgIp [/ip address find interface="wg-nas"]
:if ([:len $existingWgIp] > 0) do={
    /ip address remove $existingWgIp
}
/ip address add address=($wgIp . "/24") interface=wg-nas
:put ("WireGuard IP: " . $wgIp)

:if ([:len [/interface wireguard peers find interface="wg-nas"]] > 0) do={
    /interface wireguard peers remove [find interface="wg-nas"]
}
:local epAddress [:pick $wgEndpoint 0 [:find $wgEndpoint ":"]]
:local epPort    [:pick $wgEndpoint ([:find $wgEndpoint ":"] + 1) [:len $wgEndpoint]]

/interface wireguard peers add \
    interface=wg-nas \
    public-key=$wgServerPub \
    preshared-key=$wgPsk \
    endpoint-address=$epAddress \
    endpoint-port=$epPort \
    allowed-address=10.0.0.1/32,10.0.1.0/24 \
    persistent-keepalive=25s
:put "WireGuard peer dodany."

:if ([:len [/ip route find dst-address="10.0.0.0/8"]] > 0) do={
    /ip route remove [find dst-address="10.0.0.0/8"]
}
/ip route add dst-address=10.0.0.0/8 gateway=wg-nas
:put "Trasa 10.0.0.0/8 przez wg-nas."

# SMTP
:put "SMTP"
/tool e-mail set server=$smtpHost \
    port=25 \
    tls=starttls \
    user="report@local.com" \
    password="1" \
    from=($siteId . "@local.lan")

:put ("SMTP skonfigurowane: " . $smtpHost . ":25")


# Wirtualna siec kontenera
:put "Wirtualna siec kontenera"

:local vethName   "veth_alpine"
:local bridgeName "docker"
:local tmpDir     "container_alpine/tmp"

# Tworzy wirtualny switch
:if ([:len [/interface bridge find name=$bridgeName]] = 0) do={
    /interface bridge add name=$bridgeName
}

# Nadaje IP bramie domyślnej
:if ([:len [/ip address find interface=$bridgeName]] = 0) do={
    /ip address add address="10.10.10.1/24" interface=$bridgeName
}

# Tworzy wirtualną kartę sieciową
:if ([:len [/interface veth find name=$vethName]] = 0) do={
    /interface veth add name=$vethName address="10.10.10.2/24" gateway="10.10.10.1"
}

# Podłącza kartę do switcha
:if ([:len [/interface bridge port find interface=$vethName]] = 0) do={
    /interface bridge port add bridge=$bridgeName interface=$vethName
}
#Podłącza internet dla kontenera
:if ([:len [/ip firewall nat find comment="alpine_nat"]] = 0) do={
    /ip firewall nat add chain=srcnat src-address="10.10.10.0/24" action=masquerade comment="alpine_nat"
}

#Zmienne lokalne do pobrazniu obrazu dockera
/container config set \
    registry-url=https://ghcr.io \
    username="login Github" \
    password="token Github" \
    tmpdir=$tmpDir

/container mounts remove [find name="scan-results"]
/container mounts add name="scan-results" src="scan-results" dst="/output"

:put "Konfiguracja gotowa"
}
