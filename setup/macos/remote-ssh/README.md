# Tailscale-only Remote SSH for macOS

This opt-in dotfiles feature configures Apple's OpenSSH server for one enrolled
iPhone. TCP/22 remains standard, but is reachable only at the Mac's Tailscale
IPv4 address and only from the enrolled phone's current Tailscale IPv4 address.

Security layers:

- exact source and destination filtering with macOS `pf`;
- a persistent root service that owns a PF enable reference and loads only its
  scoped `com.apple/local.tailscale-ssh` anchor;
- Tailscale's encrypted device network and existing tailnet policy;
- one permitted local user and one managed authorized key;
- public-key authentication only;
- no root login, forwarding, tunnelling, user RC, or X11 forwarding;
- Apple's application firewall with stealth mode;
- root-owned installed configuration, never symlinked from `~/.config`.

The installer does not modify or reload `/etc/pf.conf`. It uses the
`com.apple/*` anchor point already present in macOS's startup ruleset, avoiding
the loss of dynamic rules maintained by system services.

## Enrol the phone

Create a key used only for this access:

- Termius: prefer a device-bound Secure Enclave or FIDO2 key.
- Echo: use a dedicated Ed25519 key, require Face ID for the key and app, and
  remember that Echo currently stores an importable private key in Keychain.

Export only the public key:

```bash
cp /path/to/exported-key.pub ~/.config/ssh/authorized_keys/iphone.pub
```

The file must contain exactly one public-key line. Never put a private key in
the dotfiles repo.

Confirm that `config` contains the phone's stable Tailscale DNS name. The
installer resolves the current address from the signed-in Mac's live Tailscale
network map, so no per-Mac or stale `100.x` address is committed.

## Preview and apply

Run while physically at the Mac:

```bash
~/.config/setup/setup.sh --profile local --with-remote-ssh --dry-run
~/.config/setup/setup.sh --profile local --with-remote-ssh
```

The second command may ask for the administrator password. On current macOS,
`systemsetup` can require Full Disk Access for the terminal app. If that final
step fails, grant it temporarily or enable **System Settings → General →
Sharing → Remote Login** manually. Keep Full Disk Access for remote users off.

Use regular SSH in the phone app, not Mosh: the firewall intentionally permits
only TCP/22.

## Verify

The installer prints the Mac's Ed25519 host-key fingerprint. Compare it with
the phone client's first-connection prompt; never accept a different key.

From the enrolled phone with Tailscale enabled:

```text
ssh adam@<printed-mac-tailscale-ip>
```

Expected checks:

1. The enrolled key succeeds.
2. Password-only authentication reports `publickey`.
3. Connecting to the Mac's Wi-Fi/LAN address fails.
4. A different tailnet device cannot reach port 22.
5. After reboot, the phone can still connect and these commands show the
   managed rules:

   ```bash
   sudo pfctl -a com.apple/local.tailscale-ssh -sr
   sudo sshd -T | grep -E '^(passwordauthentication|kbdinteractiveauthentication|authenticationmethods|permitrootlogin) '
   ```

Echo currently accepts host keys automatically rather than presenting the
fingerprint. That weakens independent server authentication; Termius or
another client with host-key verification is preferred for this configuration.

## Update or revoke

To rotate the phone key, replace `ssh/authorized_keys/iphone.pub`, commit it,
and rerun the feature. To revoke the phone immediately, turn off Remote Login
locally and remove the phone from the Tailscale admin console.

If the phone is re-enrolled under a different Tailscale DNS name, update
`config` and rerun. The old address remains installed until a successful
rerun, so do this while physically at the Mac.

## Recovery

All replaced files are copied beneath the setup run's timestamped
`~/dotfiles-backup/` directory. To disable access without removing the tracked
configuration, turn off Remote Login in System Settings.

Do not use `pfctl -d` as routine rollback: other macOS services may share PF.
Boot out `system/local.pf-tailscale-ssh` to release this feature's enable
reference. The service deliberately never reloads the complete PF ruleset.
