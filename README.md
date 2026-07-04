# Minimal check-bootc-and-reboot

Restarts the machine when `bootc` says it has a deployment staged.

A tool for systems utilizing the likes of *rpm-ostree* without
*Zincati* or any other *auto-update agent* running.

## Motivation

Written to compare implementations of this in various languages;
in particular maintainability (“at least one test”), resulting (static) binary size,
and *call overhead*.

A variant written in Python has been published here:
[github.com/pauldoo/chicken::content/…/bootc-check-and-reboot](https://github.com/pauldoo/chicken/blob/efe1634274866eb8a4f278d546760a3834a77cb6/content/usr/libexec/bootc-check-and-reboot)

→ Zig 0.16 compiles these ~50 LOC to about 155 kiB that run within ~50ms.  
This handily beats any implementation in Python on *call overhead* of its interpreter alone.

As aside: We could have parsed the JSON into dynamic objects like it’s with Python
instead of the pre-define struct.

```zig
parser = std.json.Parser.init(…);
var parsed = try parser.parse(output);
parsed.root.Object.get("staged").?;
// …
```

## Installation

Compile, then copy the binary to `/usr/libexec` as part of an image for actual release deployment.

Either run it on a timer, or call upon the service every time a *rpm-ostreeed* stops after
having checked for updates.

```ini
# systemctl edit rpm-ostreed-automatic.service

[Service]
ExecStopPost=systemctl start --no-block check-bootc-and-reboot.service
```

### SELinux

Writing a proper policy was out-of-scope for out little comparison.

If you want to give it a go on a SELinux-enforcing machine you could bodge
it like this:

```bash
chcon "system_u:object_r:systemd_systemctl_exec_t:s0" /usr/local/sbin/check-bootc-and-reboot
```
