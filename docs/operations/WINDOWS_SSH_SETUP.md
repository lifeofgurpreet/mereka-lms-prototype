# Windows SSH Access via Tailscale

**Target**: GPT-6 Windows Workstation
**Purpose**: Enable SSH access from development machines via Tailscale network

## Prerequisites

- Windows 10/11 Pro or Enterprise (with PowerShell 5.1+)
- Tailscale installed and connected
- Administrator access to the Windows machine
- Your SSH public key (e.g., `~/.ssh/codex.pub`)

## Setup Steps

### 1. Install OpenSSH Server

Open PowerShell as Administrator and run:

```powershell
# Check if OpenSSH Server is already installed
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'

# Install OpenSSH Server if not present
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```

Expected output:
```
Path          :
Online        : True
RestartNeeded : False
```

### 2. Configure SSH Service

```powershell
# Set SSH service to start automatically
Set-Service -Name sshd -StartupType 'Automatic'

# Start the SSH service
Start-Service sshd

# Verify the service is running
Get-Service sshd

# Configure Windows Firewall (usually done automatically)
# This command ensures the firewall rule exists:
New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue
```

### 3. Configure Authorized Keys for Administrators

For administrator accounts, Windows uses a different authorized_keys file location:

```powershell
# Create .ssh directory in ProgramData (if it doesn't exist)
New-Item -ItemType Directory -Force -Path "C:\ProgramData\ssh"

# Create or edit the administrators_authorized_keys file
notepad C:\ProgramData\ssh\administrators_authorized_keys
```

In Notepad, paste your SSH public key(s), one per line. For example:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx codex@mereka.dev
```

Save and close Notepad.

### 4. Set Correct Permissions

**CRITICAL**: The `administrators_authorized_keys` file must have strict permissions:

```powershell
# Remove inheritance and set owner to SYSTEM
icacls C:\ProgramData\ssh\administrators_authorized_keys /inheritance:r
icacls C:\ProgramData\ssh\administrators_authorized_keys /grant "SYSTEM:(F)"
icacls C:\ProgramData\ssh\administrators_authorized_keys /grant "Administrators:(F)"

# Verify permissions (should show only SYSTEM and Administrators with Full control)
icacls C:\ProgramData\ssh\administrators_authorized_keys
```

Expected output:
```
C:\ProgramData\ssh\administrators_authorized_keys NT AUTHORITY\SYSTEM:(F)
                                                  BUILTIN\Administrators:(F)
```

### 5. Verify SSH Configuration

Check the SSH server configuration:

```powershell
notepad C:\ProgramData\ssh\sshd_config
```

Ensure these lines are present (or uncommented):
```
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
```

For administrator access using `administrators_authorized_keys`, ensure this line exists:
```
Match Group administrators
       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
```

If you made changes, restart the SSH service:
```powershell
Restart-Service sshd
```

## Testing SSH Access

### From Linux/Mac via Tailscale

First, find the Tailscale IP of the Windows machine:

On Windows:
```powershell
ipconfig | findstr /C:"Tailscale"
```

On your development machine:
```bash
# Replace with the actual Tailscale IP
ssh <username>@100.x.x.x

# Example:
ssh Administrator@100.100.100.50
```

### Troubleshooting

If connection fails, check these on Windows:

```powershell
# Check SSH service status
Get-Service sshd

# View SSH server logs
Get-Content -Path "C:\ProgramData\ssh\logs\sshd.log" -Tail 50

# Test if SSH port is listening
Test-NetConnection -ComputerName localhost -Port 22

# Verify firewall rule
Get-NetFirewallRule -Name sshd
```

Common issues:
1. **Permission denied**: Check `administrators_authorized_keys` permissions (must be owned by SYSTEM)
2. **Connection refused**: Verify SSH service is running and firewall rule exists
3. **Timeout**: Ensure Tailscale is connected on both machines

## Security Notes

- Only authorized SSH keys listed in `administrators_authorized_keys` can connect
- Consider disabling password authentication in `sshd_config`:
  ```
  PasswordAuthentication no
  ```
- SSH traffic goes through Tailscale's encrypted tunnel (WireGuard)
- Access is restricted to machines on the Tailscale network

## Adding Additional Keys

To add more authorized keys:

```powershell
# Open the file
notepad C:\ProgramData\ssh\administrators_authorized_keys

# Add new public key on a new line
# Save and close

# No need to restart SSH service
```

## Removing SSH Access

To disable SSH access:

```powershell
# Stop and disable the service
Stop-Service sshd
Set-Service -Name sshd -StartupType 'Disabled'

# Optionally remove the OpenSSH Server feature
Remove-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```

## References

- [OpenSSH Server Configuration for Windows](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_server_configuration)
- [Tailscale Documentation](https://tailscale.com/kb/1017/install/)
