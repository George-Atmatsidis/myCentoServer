#!/usr/bin/env bash

SecureSsh() { 
sed -i 's/\(#ClientAliveInterval 0\).*/\ClientAliveInterval '$useridle'm/' /etc/ssh/sshd_config  #doc 2
sed -i "s/#ClientAliveCountMax 3/ClientAliveCountMax 0/" /etc/ssh/sshd_config
echo "[*] Disable Empty Passwords from ssh passcode connection's"
sed -i 's/\(#PermitEmptyPasswords no\).*/\PermitEmptyPasswords no/' /etc/ssh/sshd_config #doc 3
sleep .5
echo "[*] Removing root login from ssh"
sed -i 's/\(#PermitRootLogin yes\).*/\PermitRootLogin no/' /etc/ssh/sshd_config #doc 5
sleep .5
echo "[*] Disable Forwarding"
sed -i 's/\(X11Forwarding yes\).*/\X11Forwarding no/' /etc/ssh/sshd_config #doc 8
sed -i 's/\(#AllowTcpForwarding yes\).*/\AllowTcpForwarding no/' /etc/ssh/sshd_config
sed -i 's/\(#MaxAuthTries\).*/\MaxAuthTries 2/' /etc/ssh/sshd_config #doc 9
sleep .5
echo '[*] Set A Login Grace Timeout'
sed -i "s/#LoginGraceTime 2m/LoginGraceTime 1m/" /etc/ssh/sshd_config
sleep .5
echo "[*] Disable .Rhosts"
sed -i "s/#IgnoreRhosts yes/IgnoreRhosts yes/" /etc/ssh/sshd_config
sleep .5
echo "[*] Disable Host-Based Authentication"
sed -i "s/#HostbasedAuthentication no/HostbasedAuthentication no/" /etc/ssh/sshd_config
sed -i "s/#IgnoreUserKnownHosts no/IgnoreUserKnownHosts yes/" /etc/ssh/sshd_config
sleep .5
echo "[*] Log More Information ssh log file"
sed -i "s/#LogLevel INFO/LogLevel VERBOSE/" /etc/ssh/sshd_config
sed -i 's/\(#MaxStartups\).*/\MaxStartups 2/' /etc/ssh/sshd_config
sleep .5
echo '[*] Displaying the last login'
sed -i "s/#PrintLastLog yes/PrintLastLog yes/" /etc/ssh/sshd_config
sleep .5
echo '[*] Check User Specific Configuration Files'
sed -i "s/#StrictModes yes/StrictModes yes/" /etc/ssh/sshd_config
sleep .5
echo '[*] Prevent Privilege Escalation'
sed -i "s/#UsePrivilegeSeparation sandbox/UsePrivilegeSeparation sandbox/" /etc/ssh/sshd_config
sleep .5
echo '[*] Disable GSSAPI Authentication'
sed -i "s/GSSAPIAuthentication yes/GSSAPIAuthentication no/" /etc/ssh/sshd_config
sleep .5
echo '[*] Disable Kerberos Authentication'
sed -i "s/#KerberosAuthentication no/KerberosAuthentication no/" /etc/ssh/sshd_config
sleep .5
echo '[*] Use FIPS 140-2'
sed -i "s/#RekeyLimit default none/Ciphers aes128-ctr,aes192-ctr,aes256-ctr/" /etc/ssh/sshd_config
echo "Restarting ssh"
sudo systemctl restart sshd.service
}

SudoUser(){   
adduser $newuser
passwd $newuser
usermod -aG wheel $newuser
echo "Adding user $newuser to ssh"
echo AllowUsers $newuser >> /etc/ssh/sshd_config
}

IfUserExist(){ 

if id "$newuser" >/dev/null 2>&1; then
        echo "$newuser created successfull"
else
        echo "$newuser created fail"
fi
}

TwoFactorAuthenticator(){ 
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo yum install -y google-authenticator
echo auth required pam_google_authenticator.so nullok >> /etc/pam.d/sshd
sed -i 's/\(ChallengeResponseAuthentication no\).*/\ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
echo "Restarting ssh"
sudo systemctl restart sshd.service
##
#2FAuth - Google Authenticator
echo " Copy this -> ssh $newuser@$(dnsdomainname -f)
to login from the $newuser user.
and then execute the following command
google-authenticator && sudo systemctl restart sshd.service && exit"
read cmdauth
eval $cmdauth > /dev/pts/0
}

TcpWrapper() {
sudo yum install -y tcp_wrappers
sleep .5
echo '[*] Configure Tcp-Wrappers'
sudo echo 'ALL : ALL' >> /etc/hosts.deny
sudo echo 'sshd : '$publicip >> /etc/hosts.allow
}

SetAthensTimezone(){
echo '[*] Set Athens timezone'
timedatectl set-timezone Europe/Athens
}

Firewalld() {
echo "[*] Filter SSH at the Firewall"
firewall-cmd --permanent --remove-service="ssh"
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address='$publicip' service name="ssh" accept'
echo "* Open http 80 port tcp"
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --reload
}

Fail2Ban() {
echo "[*] Fail2Ban Monitoring For Ssh & Apatche2"
sleep .5
sudo yum install -y epel-release
sudo yum install -y fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sed -i "s/findtime  = 10m/findtime = 30/" /etc/fail2ban/jail.local
echo "* Bantime for 372days"
sleep .5
sed -i "s/bantime  = 10m/bantime = 372d/" /etc/fail2ban/jail.local
echo "* Whitelist our publicIP"
sleep .5
sed -i "s/\#ignoreip =/\ignoreip = $publicip/" /etc/fail2ban/jail.local
echo "* Decrease MaxTries to 2"
sleep .5
sed -i "s/maxretry = 5/maxretry = 2/" /etc/fail2ban/jail.local
echo "* "
sed -i "s/backend = %(sshd_backend)s/backend = %(sshd_backend)s\nenabled = true/" /etc/fail2ban/jail.local
echo '* Restart Fail2Ban'
sudo systemctl start fail2ban
sudo systemctl restart fail2ban
sleep .5
echo 'Fail2Ban Install and Configuration successful'
}

cd ~
SetAthensTimezone
echo "Hello,$USER,
Because we connect to the server via ssh root which means that a third party can also access our server as root.
So anyone with a bruteforce method can try a combination of passwords to gain access and perform malicious actions.
One action we can take is to lock ssh root and create a new system user with sudo privileges.
Give new username in empty space below
[IMPORTANT]: Use strong username/passcode for SSH"
read newuser
SudoUser '$newuser'
IfUserExist '$newuser'
echo "[*] What is minimum idle time the user will logout from SSH? 
[The time is canculated to minutes]"
read useridle
echo "Add public ip from local machine"
read publicip
TwoFactorAuthenticator
TcpWrapper '$publicip'
Firewalld '$publicip'
Fail2Ban '$publicip'
SecureSsh '$useridle' 
