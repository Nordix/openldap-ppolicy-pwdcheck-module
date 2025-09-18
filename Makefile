# Copyright 2007 Michael Steinmann, Calivia. All Rights Reserved.
# Updated by Pierre-Yves Bonnetain, B&A Consultants, 2008
# Updated by Trevor Vaughan, Onyx Point Inc., 2011
# Copyright (c) 2025 OpenInfra Foundation Europe and others.

# Path to the check_password.c configuration file.
CONFIG=/etc/openldap/check_password.conf

# Path to OpenLDAP source tree (defaults to source downloaded with 'make openldap').
LDAP_SRC_PATH=openldap-src

# If using the checker with OpenLDAP versions prior to 2.6, set this to 1.
# This will compile the module against the older ppolicy API.
# Note: the tests only work with OpenLDAP 2.6 and later.
LDAP_VERSION_PRE_2_6=0

# Define to 1 if you want to use CrackLib for password strength checking.
HAVE_CRACKLIB=1

# Path to CrackLib dictionaries.
CRACKLIB=/usr/share/cracklib/pw_dict

# Path to CrackLib headers, if needed.
CRACK_INC=

# Install path for the compiled module (used for 'make install').
DESTDIR=/usr/lib/openldap/modules/

# OpenLDAP source code repository and tag to use (used for 'make openldap').
OPENLDAP_GIT_URL=https://github.com/openldap/openldap.git
OPENLDAP_GIT_TAG=OPENLDAP_REL_ENG_2_6_10

# Set LOGGER_LEVEL to pick what level of logging you want
#
# Possible values are:
#   LOGGER_LEVEL_TRACE
#   LOGGER_LEVEL_INFO
#   LOGGER_LEVEL_WARNING
#   LOGGER_LEVEL_ERROR
#   LOGGER_LEVEL_NONE
#
LOGGER_LEVEL=LOGGER_LEVEL_WARNING


CC = gcc

TARGET = check_password.so
SRCS = check_password.c
OBJS = $(SRCS:.c=.o)

CFLAGS = -Wall -Wextra -Werror -g -O2 -fPIC

CPPFLAGS = \
	-DCONFIG_FILE="\"$(CONFIG)\"" \
    -DLOGGER_LEVEL="$(LOGGER_LEVEL)"

CPPFLAGS += -I$(LDAP_SRC_PATH)/include -I$(LDAP_SRC_PATH)/servers/slapd -I$(LDAP_SRC_PATH)/build-servers/include

LDFLAGS=-shared -Wl,--no-undefined -L$(LDAP_SRC_PATH)/libraries/libldap/.libs -L$(LDAP_SRC_PATH)/libraries/liblber/.libs

LDLIBS=-lldap -llber

ifeq ($(HAVE_CRACKLIB),1)
CPPFLAGS += -DHAVE_CRACKLIB -DCRACKLIB_DICTPATH="\"$(CRACKLIB)\""
LDLIBS += -lcrack
ifneq ($(CRACK_INC),)
CPPFLAGS += -I$(CRACK_INC)
endif
endif

ifeq ($(LDAP_VERSION_PRE_2_6),1)
CPPFLAGS += -DLDAP_VERSION_PRE_2_6
endif

$(TARGET): $(OBJS)
	$(CC) $(CPPFLAGS) -o $(TARGET) $(OBJS) $(LDFLAGS) $(LDLIBS)

install: $(TARGET)
	install -m 644 $(TARGET) $(DESTDIR)/$(TARGET)

clean:
	$(RM) $(OBJS) $(TARGET)

openldap:
	[ -d openldap-src ] || git clone $(OPENLDAP_GIT_URL) openldap-src
	(cd openldap-src && git fetch --tags && git checkout $(OPENLDAP_GIT_TAG) && ./configure --enable-modules --enable-ppolicy && make depend && make)

test:
	$(MAKE) CRACKLIB=$(CURDIR)/tests/cracklib-dictionary/dict LOGGER_LEVEL=LOGGER_LEVEL_DEBUG
	tests/run.sh

compdb:
	bear -- make

clang-format:
	clang-format -i *.c *.h
