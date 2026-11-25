# Rocky 10 sudo RPM Packaging (Minimal + LDAP Split)

This project repackages `sudo` from Rocky Linux 10 (`sudo-1.9.17-10.p2.el10_3.13.src.rpm`), splitting it into:
1. A minimal base **`sudo`** package that does **not** link against or require OpenLDAP libraries (`libldap`, `liblber`).
2. A **`sudo-ldap`** extension subpackage providing LDAP directory support for sudoers.

A **single SRPM** produces all packages in a single build pass (similar to Debian source package builds producing both `sudo` and `sudo-ldap`).

---

## Architecture & Design

In sudo, all core binaries (`/usr/bin/sudo`, `/usr/sbin/visudo`, `/usr/bin/cvtsudoers`, `/usr/bin/sudoreplay`, `/usr/libexec/sudo/libsudo_util.so`) have zero LDAP dependencies. Only the sudoers plugin (`/usr/libexec/sudo/sudoers.so`) links against `libldap.so.2` and `liblber.so.2`.

### Single SRPM Dual-Build Model
During build:
- The base tree is compiled with `--without-ldap`, creating `sudoers-minimal.so` without any OpenLDAP dependencies.
- A clean second tree is compiled with `--with-ldap`, creating `sudoers-ldap.so` linked against OpenLDAP.

### Plugin Selection via `update-alternatives`
The `/usr/libexec/sudo/sudoers.so` plugin symlink is managed by `update-alternatives`:

| Package | Plugin File | Alternatives Priority | OpenLDAP Dependencies |
| :--- | :--- | :--- | :--- |
| **`sudo`** (Base) | `/usr/libexec/sudo/sudoers-minimal.so` | 10 | **None** |
| **`sudo-ldap`** (Subpackage) | `/usr/libexec/sudo/sudoers-ldap.so` | 50 | `libldap.so.2`, `liblber.so.2` |

- When only **`sudo`** is installed: `/usr/libexec/sudo/sudoers.so` points to `sudoers-minimal.so`.
- When **`sudo-ldap`** is installed: `update-alternatives` automatically switches `/usr/libexec/sudo/sudoers.so` to `sudoers-ldap.so` (priority 50 > 10).
- If **`sudo-ldap`** is uninstalled: `update-alternatives` safely reverts `/usr/libexec/sudo/sudoers.so` back to `sudoers-minimal.so`.
- In the base `sudo` package, `/usr/libexec/sudo/sudoers.so` is marked as `%ghost` so RPM tracks the alternatives symlink without conflict.

### Packages Produced
1. **`sudo` (Base package):**
   - Core binaries: `sudo`, `sudoedit`, `visudo`, `cvtsudoers`, `sudoreplay`
   - Default sudoers configuration: `/etc/sudoers`, `/etc/sudoers.d`, `/etc/sudo.conf`, PAM configs
   - Minimal plugin: `/usr/libexec/sudo/sudoers-minimal.so`
   - Ghost symlink: `/usr/libexec/sudo/sudoers.so`
   - Zero LDAP dependencies.

2. **`sudo-ldap` (Subpackage):**
   - LDAP plugin: `/usr/libexec/sudo/sudoers-ldap.so`
   - Configuration: `/etc/sudo-ldap.conf`
   - Man pages: `sudoers.ldap(5)`, `sudo-ldap.conf(5)`
   - LDAP schemas: ActiveDirectory, OpenLDAP, etc.
   - Strict version requirement: `Requires: sudo%{?_isa} = %{version}-%{release}`.

3. **`sudo-devel` & `sudo-python-plugin`:**
   - Companion subpackages for development headers and python plugin support.

---

## Building

### Prerequisites
- `mock` installed and configured with Rocky Linux 10 (`rocky-10-x86_64`).
- `rpmbuild` (`rpm-build` package).

### Build Commands

```bash
# Build the single SRPM in SRPMS/
make srpm

# Build all binary RPMs in Rocky Linux 10 Mock
make mock
```

The binary RPMs will be placed in `RPMS/`:
- `RPMS/sudo-1.9.17-10.p2.el10.13.x86_64.rpm`
- `RPMS/sudo-ldap-1.9.17-10.p2.el10.13.x86_64.rpm`
- `RPMS/sudo-devel-1.9.17-10.p2.el10.13.x86_64.rpm`
- `RPMS/sudo-python-plugin-1.9.17-10.p2.el10.13.x86_64.rpm`

---

## Verification

Check that base `sudo` has no OpenLDAP dependencies:
```bash
rpm -qpR RPMS/sudo-*.el10.x86_64.rpm | grep ldap
# (Outputs nothing)
```

Check that `sudo-ldap` requires OpenLDAP and the base `sudo` package:
```bash
rpm -qpR RPMS/sudo-ldap-*.el10.x86_64.rpm | grep -E "ldap|sudo"
# Output includes:
#   libldap.so.2()(64bit)
#   liblber.so.2()(64bit)
#   sudo(x86-64) = 1.9.17-10.p2.el10.13
```
