# Contributing

## Building the project

To compile the project, run:

```
make CRACKLIB=$PWD/tests/cracklib-dictionary/dict LOGGER_LEVEL=LOGGER_LEVEL_TRACE
```

This will produce the `check_password.so` shared library with cracklib support using test dictionary and maximum logging enabled.

## Testing

Test suite uses OpenLDAP's test framework.

First ensure that [OpenLDAP](https://github.com/openldap/openldap) is cloned under the `openldap-src` directory and compiled by running:

```
make opendldap
```

Then run the tests with:

```
make test
```

Tests are run against a temporary OpenLDAP server instance started for the duration of the tests.
Password changes are performed using the `ldappasswd` command-line tool.
After running a test, you can find the detailed test output files in the `openldap-src/tests/testrun/` directory.

For examples on how to write tests, refer to the [`tests/`](tests/) directory or in the OpenLDAP source code's `openldap-src/tests/scripts` directory.

## Troubleshooting

Run tests with [valgrind](https://valgrind.org/) to catch memory issues:

```
SLAPD_COMMON_WRAPPER=valgrind make test
```

## Code formatting

To format the code, run:

```
make clang-format
```

You need to have `clang-format` installed for this to work.
The formatting style is defined in the [.clang-format](.clang-format) file.

Alternatively you can use the clangd extension in VS Code to format code.
See the "VS Code tips" section below for instructions on setting up clangd.

## VS Code tips

For C language support in VS Code, install the [clangd extension](https://marketplace.visualstudio.com/items?itemName=llvm-vs-code-extensions.vscode-clangd) and [`bear`](https://github.com/rizsotto/Bear), which generates a compilation database for the clangd language server.
To install `bear` on Ubuntu or Debian, run:

```
sudo apt install bear
```

To generate the `compile_commands.json` file, run:

```
make compdb
```

After this, you can open the project in VS Code and benefit from full C language support.

The project also includes a [.clang-format](.clang-format) file for code formatting, which is used by the clangd extension.
