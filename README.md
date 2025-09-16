# PPolicy PwdCheck Module for OpenLDAP

This project provides an OpenLDAP password policy checker module that enforces password quality rules.
The module integrates with OpenLDAP's password policy overlay ([`slapo-ppolicy(5)`](https://www.openldap.org/software/man.cgi?query=slapo-ppolicy&sektion=5&apropos=0&manpath=OpenLDAP+2.6-Release)).

This project is a fork of a legacy password checker module, updated for compatibility with OpenLDAP 2.6 and with couple of minor enhancements.
It is intended for users who require backwards compatiiblity with original module's functionality on newer OpenLDAP versions.
For others the PPM password policy module available in the OpenLDAP contrib directory [`contrib/slapd-modules/ppm/`](https://github.com/openldap/openldap/tree/master/contrib/slapd-modules/ppm) may be a better choice.

For details on the origins of this project, see Acknowledgements section.

## Usage

In OpenLDAP 2.6 the password checker module is configured via the ppolicy overlay in your `slapd.conf` configuration.

```
overlay       ppolicy
...
ppolicy_check_module libcheck_password.so
```

or with online configuration

```
objectClass: olcPPolicyConfig
...
olcPPolicyCheckModule: libcheck_password.so
```

Refer to OpenLDAP 2.6 documentation for details on overlay and module configuration.

### Configuration

By default, the module reads its configuration from `/etc/openldap/check_password.conf` if the file exists.
You can change this location or provide configuration in the following ways:

- Set the `PWDCHECK_MODULE_CONFIG_FILE` environment variable before starting `slapd` to specify a custom config file path.
- Set the `CONFIG` variable in the Makefile during compilation to change the default path, see [Compilation](#compilation).
- Provide configuration using `pwdCheckModuleArg` in the `pwdPolicyChecker` object class, see [`slapo-ppolicy(5)`](https://www.openldap.org/software/man.cgi?query=slapo-ppolicy&sektion=5&apropos=0&manpath=OpenLDAP+2.6-Release).

#### Parameters

| Parameter                   | Type                | Default | Description                                                    |
| --------------------------- | ------------------- | ------- | -------------------------------------------------------------- |
| `use_cracklib`              | boolean<sup>1</sup> | `true`  | Enable CrackLib checks. Ignored if not compiled in.            |
| `min_points`                | integer             | 3       | Minimum number of character classes (quality points) required. |
| `min_upper`                 | integer             | 0       | Minimum uppercase characters required.                         |
| `min_lower`                 | integer             | 0       | Minimum lowercase characters required.                         |
| `min_digit`                 | integer             | 0       | Minimum digit characters required.                             |
| `min_punct`                 | integer             | 0       | Minimum punctuation characters required.                       |
| `max_consecutive_per_class` | integer             | 5       | Maximum consecutive characters from the same class.            |
| `contains_username`         | boolean<sup>1</sup> | `false` | Reject passwords containing the username.                      |

<sup>1</sup> For boolean parameters, you can use `1`/`0` or `true`/`false` (case-insensitive).

##### CrackLib

CrackLib is a library that checks passwords against a dictionary of known weak passwords and patterns to enhance password security.
The CrackLib support may be disabled at compile time by setting `HAVE_CRACKLIB=0` during compilation.
For more information, see the official repository at [github](https://github.com/cracklib/cracklib/tree/main/src).

##### Quality Points Concept (`min_points`)

There are four character classes: (1) lowercase letters, (2) uppercase letters, (3) digits, and (4) punctuation/special characters.
When the password is evaluated, one quality point is awarded for each character class that fully meets the minimum requirement.
For example, if `min_upper` is set to 2, at least 2 uppercase letters are needed to earn one point for the uppercase class.
If `min_points` is set to 3, the password must meet the minimum requirements in at least 3 of the 4 character classes to be accepted.

##### Maximum Consecutive Characters (`max_consecutive_per_class`)

This parameter sets the limit for consecutive characters from the same character class in a password.
For instance, with `max_consecutive_per_class` set to 5, a password may include up to 4 consecutive lowercase letters.
`abcdABCD1234` is valid, but `abcdeABCD1234` exceeds the limit and is rejected.

Setting value 0 disables this check.

⚠️ **Note:** Due to a bug, consecutive characters are counted incorrectly, resulting in the effective limit being one less than the configured value. This behavior is preserved for compatibility with the original module.

##### Password Contains Username (`contains_username`)

If enabled, this option rejects any password that includes the username.
For example, for the DN `uid=john,ou=people,dc=example,dc=com`, the username `john` is checked against the password.
If the password contains `john`, it will be rejected.

##### Example configuration

Each line in the config file should be: `parameter value`
Spaces and tabs are delimiters.
Parameter names are case-sensitive.

```
use_cracklib 1
min_points 3
min_upper 1
min_lower 1
min_digit 1
min_punct 0
max_consecutive_per_class 5
contains_username false
```

## Compiling

### Build Requirements

- OpenLDAP source tree.
- CrackLib development headers and libraries (unless disabling with `HAVE_CRACKLIB=0`).
- GNU Make, GCC

### Compilation Parameters (from Makefile)

| Variable        | Default Value                       | Description                   |
| --------------- | ----------------------------------- | ----------------------------- |
| `CONFIG`        | `/etc/openldap/check_password.conf` | Path to config file           |
| `LDAP_SRC_PATH` | `./openldap-src`                    | Path to OpenLDAP source tree  |
| `HAVE_CRACKLIB` | `1`                                 | Enable CrackLib support       |
| `CRACKLIB`      | `/usr/share/cracklib/pw_dict`       | Path to CrackLib dictionary   |
| `CRACK_INC`     | (empty)                             | Path to CrackLib headers      |
| `LOGGER_LEVEL`  | `LOGGER_LEVEL_WARNING`              | Logging verbosity (see below) |


For example, to compile without Cracklib, with a custom config file path and OpenLDAP source tree location, run:

```
make HAVE_CRACKLIB=0 CONFIG=/path/to/config LDAP_SRC_PATH=<path-to-openldap-source>
```

To install the module, run:

```
make install
```

By default, the module is installed to `/usr/lib/openldap/modules/`.
You can change this by setting the `DESTDIR=<path-to-install-directory>` variable in the `make install` command.

##### Logging

The module outputs log messages to `stderr` during runtime, mainly for development and troubleshooting purposes.
You can control the verbosity by setting the `LOGGER_LEVEL` variable in the Makefile at compile time.
Supported levels include:

- `LOGGER_LEVEL_DEBUG`
- `LOGGER_LEVEL_INFO`
- `LOGGER_LEVEL_WARNING`
- `LOGGER_LEVEL_ERROR`

To turn off logging entirely, use `make LOGGER_LEVEL=LOGGER_LEVEL_NONE`.

## Acknowledgements

This project is based on work by Michael Steinmann, Pierre-Yves Bonnetain, Clement Oudot, Jerome HUET, and Trevor Vaughan.
For full details, see the git history.

Original repositories:

- [ltb-project/openldap-ppolicy-check-password](https://github.com/ltb-project/openldap-ppolicy-check-password)
- [trevor-vaughan/openldap-ppolicy-check-password (refactor_and_tests)](https://github.com/trevor-vaughan/openldap-ppolicy-check-password/tree/refactor_and_tests)
