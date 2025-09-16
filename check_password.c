/*
 * check_password.c for OpenLDAP
 *
 * See LICENSE and README.md files.
 */

#include <ctype.h>
#include <ldap.h>
#include <portable.h>
#include <slap.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#ifdef HAVE_CRACKLIB
#include <crack.h>
#endif

#include "check_password.h"

#define PASSWORD_TOO_SHORT_SZ "Password for dn=\"%s\" is too short (%d/6)"
#define PASSWORD_QUALITY_SZ                                                    \
	"Password for dn=\"%s\" does not pass required number of strength checks " \
	"for the required character sets (%d of %d)"
#define BAD_PASSWORD_SZ "Bad password for dn=\"%s\" because %s"
#define CONSEC_FAIL_SZ                                                         \
	"Too many consecutive characters in the same character class for "         \
	"dn=\"%s\""

#define FILENAME_MAXLEN	 512
#define DN_MAXLEN		 512

int check_password(char* pPasswd, struct berval* errmsg, Entry* pEntry,
				   struct berval* arg);

struct config_entry {
	char* key;
	char* value;
	char* def_value;
} config_entries[] = {{"min_points", NULL, "3"},
					  {"use_cracklib", NULL, "1"},
					  {"min_upper", NULL, "0"},
					  {"min_lower", NULL, "0"},
					  {"min_digit", NULL, "0"},
					  {"min_punct", NULL, "0"},
					  {"max_consecutive_per_class", NULL, "5"},
					  {"contains_username", NULL, "false"},
					  {NULL, NULL, NULL}};

static int get_config_entry_int(const char* entry) {
	const struct config_entry* centry = config_entries;
	for (int i = 0; centry[i].key != NULL; i++) {
		if (strcmp(centry[i].key, entry) == 0) {
			const char* val =
				centry[i].value ? centry[i].value : centry[i].def_value;
			return val ? atoi(val) : -1;
		}
	}
	return -1;
}

static int get_config_entry_boolean(const char* entry) {
	const struct config_entry* centry = config_entries;
	for (int i = 0; centry[i].key != NULL; i++) {
		if (strcmp(centry[i].key, entry) == 0) {
			const char* val =
				centry[i].value ? centry[i].value : centry[i].def_value;
			if (val &&
				(strcasecmp(val, "true") == 0 || strcasecmp(val, "1") == 0)) {
				return 1;
			} else {
				return 0;
			}
		}
	}
	return -1;
}

static void dealloc_config_entries() {
	struct config_entry* centry = config_entries;

	int i = 0;
	while (centry[i].key != NULL) {
		if (centry[i].value != NULL) {
			ber_memfree(centry[i].value);
			centry[i].value = NULL;
		}
		i++;
	}
}

static char* chomp(const char* s) {
	char* t = ber_memalloc(strlen(s) + 1);
	strcpy(t, s);

	if (t[strlen(t) - 1] == '\n') {
		t[strlen(t) - 1] = '\0';
	}

	return t;
}

static void parse_config_line(char* buffer) {
	while (isspace(*buffer) && isascii(*buffer))
		buffer++;

	if (*buffer == '\0' && ispunct(*buffer)) {
		return;
	}

	char* saveptr;
	const char* key = strtok_r(buffer, " \t", &saveptr);
	const char* value = strtok_r(NULL, " \t", &saveptr);

	if (!key || !value)
		return;

	for (int i = 0; config_entries[i].key != NULL; i++) {
		if (strcmp(key, config_entries[i].key) == 0) {
			config_entries[i].value = chomp(value);
			break;
		}
	}
}

static int parse_config(char* buffer) {
	char* line;
	char* saveptr;

	line = strtok_r(buffer, "\n", &saveptr);
	while (line != NULL) {
		parse_config_line(line);
		line = strtok_r(NULL, "\n", &saveptr);
	}

	return 0;
}

static int read_config_file() {
	const char* config_path = getenv("PWDCHECK_MODULE_CONFIG_FILE");
	if (!config_path || strlen(config_path) == 0) {
		config_path = CONFIG_FILE;
	}

	LOGGER_DEBUG("Reading config file %s", config_path);

	FILE* config = fopen(config_path, "r");
	if (config == NULL) {
		LOGGER_ERROR("Could not open config file %s", config_path);
		return -1;
	}

	fseek(config, 0, SEEK_END);
	size_t filesize = ftell(config);
	rewind(config);

	char* buffer = ber_memcalloc(filesize + 1, sizeof(char));
	if (buffer == NULL) {
		fclose(config);
		return -1;
	}

	size_t bytesRead = fread(buffer, sizeof(char), filesize, config);
	fclose(config);

	if (bytesRead != filesize) {
		ber_memfree(buffer);
		return -1;
	}

	int result = parse_config(buffer);
	ber_memfree(buffer);
	return result;
}

static char* get_username(const Entry* pEntry, char* dn) {
	strncpy(dn, pEntry->e_nname.bv_val, DN_MAXLEN - 1);
	dn[DN_MAXLEN - 1] = '\0';

	char* saveptr;
	char* username = strtok_r(dn, ",+", &saveptr);
	strtok_r(username, "=", &saveptr);
	username = strtok_r(NULL, "=", &saveptr);

	return username;
}

static void set_additional_info(struct berval* errmsg, const char* info, ...) {
	va_list args;
	va_start(args, info);
	int needed = vsnprintf(NULL, 0, info, args);
	va_end(args);

	errmsg->bv_val = ber_memalloc(needed + 1);
	if (!errmsg->bv_val) {
		errmsg->bv_len = 0;
		return;
	}
	errmsg->bv_len = needed + 1;

	va_start(args, info);
	vsnprintf(errmsg->bv_val, needed + 1, info, args);
	va_end(args);
}

int check_password(char* pPasswd, struct berval* errmsg, Entry* pEntry,
				   struct berval* pArg) {

	const struct berval* pwdCheckModuleArg = pArg;

	int nLen;
	int nLower = 0;
	int nUpper = 0;
	int nDigit = 0;
	int nPunct = 0;
	int nQuality = 0;

	/**
	 * bail out early as cracklib will reject passwords shorter
	 * than 6 characters
	 */
	nLen = strlen(pPasswd);
	if (nLen < 6) {
		set_additional_info(errmsg, PASSWORD_TOO_SHORT_SZ,
							pEntry->e_name.bv_val, nLen);
		goto fail;
	}

	if (read_config_file() == -1) {
		LOGGER_ERROR("Could not read config file. Using defaults.");
	}

	if (pwdCheckModuleArg != NULL && pwdCheckModuleArg->bv_len > 0) {
		parse_config(pwdCheckModuleArg->bv_val);
	}

	int min_quality = get_config_entry_int("min_points");
	int use_cracklib = get_config_entry_boolean("use_cracklib");
	int min_upper = get_config_entry_int("min_upper");
	int min_lower = get_config_entry_int("min_lower");
	int min_digit = get_config_entry_int("min_digit");
	int min_punct = get_config_entry_int("min_punct");
	int max_consecutive_per_class =
		get_config_entry_int("max_consecutive_per_class");
	int contains_username = get_config_entry_boolean("contains_username");

	LOGGER_DEBUG("min_quality=%d, use_cracklib=%d, min_upper=%d, min_lower=%d, "
				 "min_digit=%d, min_punct=%d, max_consecutive_per_class=%d, "
				 "contains_username=%d",
				 min_quality, use_cracklib, min_upper, min_lower, min_digit,
				 min_punct, max_consecutive_per_class, contains_username);

	/* Check Max Consecutive Per Class first since this has the most likelihood
	 * of being wrong.
	 */

	if (max_consecutive_per_class != 0) {
		int consec_chars = 1;
		char type[10] = "unkown";
		char prev_type[10] = "unknown";
		for (int i = 0; i < nLen; i++) {

			if (islower(pPasswd[i])) {
				strncpy(type, "lower", 10);
			} else if (isupper(pPasswd[i])) {
				strncpy(type, "upper", 10);
			} else if (isdigit(pPasswd[i])) {
				strncpy(type, "digit", 10);
			} else if (ispunct(pPasswd[i])) {
				strncpy(type, "punct", 10);
			} else {
				strncpy(type, "unknown", 10);
			}

			if (consec_chars > max_consecutive_per_class) {
				set_additional_info(errmsg, CONSEC_FAIL_SZ,
									pEntry->e_name.bv_val);
				goto fail;
			}

			if (strncmp(type, prev_type, 10) == 0) {
				consec_chars++;
			} else {
				if (strncmp("unknown", prev_type, 8) != 0) {
					consec_chars = 1;
				} else {
					consec_chars++;
				}
				strncpy(prev_type, type, 10);
			}
		}
	}

	/** The password must have at least min_quality strength points with one
	 * point for the first occurrance of a lower, upper, digit and
	 * punctuation character
	 */

	for (int i = 0; i < nLen; i++) {

		// if ( nQuality >= min_quality ) break;

		if (islower(pPasswd[i])) {
			min_lower--;
			if (!nLower && (min_lower < 1)) {
				nLower = 1;
				nQuality++;
			}
			continue;
		}

		if (isupper(pPasswd[i])) {
			min_upper--;
			if (!nUpper && (min_upper < 1)) {
				nUpper = 1;
				nQuality++;
			}
			continue;
		}

		if (isdigit(pPasswd[i])) {
			min_digit--;
			if (!nDigit && (min_digit < 1)) {
				nDigit = 1;
				nQuality++;
			}
			continue;
		}

		if (ispunct(pPasswd[i])) {
			min_punct--;
			if (!nPunct && (min_punct < 1)) {
				nPunct = 1;
				nQuality++;
			}
			continue;
		}
	}

	/*
	 * If you have a required field, then it should be required in the strength
	 * checks.
	 */

	LOGGER_DEBUG(
		"min_lower=%d, min_upper=%d, min_digit=%d, min_punct=%d, nQuality=%d "
		"(min_quality=%d)",
		min_lower, min_upper, min_digit, min_punct, nQuality, min_quality);
	if ((min_lower > 0) || (min_upper > 0) || (min_digit > 0) ||
		(min_punct > 0) || (nQuality < min_quality)) {
		set_additional_info(errmsg, PASSWORD_QUALITY_SZ, pEntry->e_name.bv_val,
							nQuality, min_quality);
		goto fail;
	}

#ifdef HAVE_CRACKLIB

	/** Check password with cracklib */

	if (use_cracklib > 0) {
		FILE* fp;
		char filename[FILENAME_MAXLEN];
		char const* ext[] = {"hwm", "pwd", "pwi"};
		int nErr = 0;

		/**
		 * Silently fail when cracklib wordlist is not found
		 */

		for (int j = 0; j < 3; j++) {
			snprintf(filename, FILENAME_MAXLEN - 1, "%s.%s", CRACKLIB_DICTPATH,
					 ext[j]);

			if ((fp = fopen(filename, "r")) == NULL) {
				nErr = 1;
				LOGGER_WARNING(
					"Could not find cracklib dictionary '%s', skipping "
					"cracklib checks",
					filename);
				break;
			} else {
				fclose(fp);
			}
		}

		char* r;
		if (nErr == 0) {
			r = (char*)FascistCheck(pPasswd, CRACKLIB_DICTPATH);
			if (r != NULL) {
				LOGGER_DEBUG("Cracklib rejected password '%s' because %s",
							 pPasswd, r);
				set_additional_info(errmsg, BAD_PASSWORD_SZ,
									pEntry->e_name.bv_val, r);
				goto fail;
			}
		} else {
			LOGGER_WARNING("Could not find cracklib dictionary '%s', skipping "
						   "cracklib checks",
						   CRACKLIB_DICTPATH);
		}
	}

#endif /* HAVE_CRACKLIB */

	if (contains_username) {
		char buf[DN_MAXLEN] = {0};
		char* username = get_username(pEntry, buf);
		if (strlen(buf) > 0) {

			LOGGER_DEBUG("Checking username '%s' is not contained in password",
						 username);
			if (strstr(pPasswd, username) != NULL) {
				set_additional_info(errmsg, BAD_PASSWORD_SZ,
									pEntry->e_name.bv_val,
									"it contains the username");
				goto fail;
			}
		} else {
			LOGGER_DEBUG("Cannot get username for entry '%s', skipping check "
						 "that password does not contain username",
						 pEntry->e_name.bv_val);
		}
	}

	dealloc_config_entries();
	return LDAP_SUCCESS;

fail:
	dealloc_config_entries();
	return EXIT_FAILURE;
}
