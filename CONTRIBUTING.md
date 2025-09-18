# Contributing

## Testing

The test suite uses OpenLDAP's test framework to configure and run `slapd` and to collect test logs.

First, ensure that [OpenLDAP](https://github.com/openldap/openldap) is cloned into the `openldap-src` directory and compiled.
Run:

```
make openldap
```

This command checks out the latest released version (as defined by the `OPENLDAP_GIT_TAG` variable in the [`Makefile`](Makefile)) and compiles it in the `openldap-src` directory.

Next, compile the project and run the tests with:

```
make test
```

The tests run against a temporary OpenLDAP server instance, which is started for the duration of the tests.
Password changes are performed using the `ldappasswd` command line tool from the OpenLDAP source tree.
After running the tests, you can find detailed output files in the `openldap-src/tests/testrun/` directory.

For examples of how to write tests, refer to the [`tests/`](tests/) directory in this project or the `openldap-src/tests/scripts` directory in the OpenLDAP source code.

## Troubleshooting

To catch memory issues, run the tests with [valgrind](https://valgrind.org/):

```
SLAPD_COMMON_WRAPPER=valgrind make test
```

To capture and display LDAP traffic with Wireshark, use:

```
wireshark -i lo -d tcp.port==9011,ldap -k -Y ldap
```

## Code Formatting

To format the code, run:

```
make clang-format
```

You need to have `clang-format` installed for this to work.
The formatting style is defined in the [.clang-format](.clang-format) file.
Alternatively, you can use the clangd extension in VS Code to format code.

## VS Code Tips

For C language support in VS Code, install the [clangd extension](https://marketplace.visualstudio.com/items?itemName=llvm-vs-code-extensions.vscode-clangd) and [`bear`](https://github.com/rizsotto/Bear), which generates a compilation database for the clangd language server.

To install `bear` on Ubuntu or Debian, run:

```
sudo apt install bear
```

To generate the `compile_commands.json` file, run:

```
make compdb
```

After this, you can open the project in VS Code with full C language support.
