# Contributing

## Building the project

To compile the project, run:

```
make
```

## Testing


To run the tests, first ensure the OpenLDAP git submodule is initialized and compiled:

```
git submodule update --init
make opendldap
```

To run the tests:

```
make test
```

Tests are run against a temporary OpenLDAP server instance started specifically for testing.
Password changes during tests are performed using the `ldappasswd` command-line tool.
Both depend on the compiled OpenLDAP source code tree.
After running a test, you can find the test output files in the `openldap-src/tests/testrun/` directory.

For examples of how to write tests, refer to the [`tests/`](tests/) directory or in the OpenLDAP source code's `openldap-src/tests/scripts` directory.


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
