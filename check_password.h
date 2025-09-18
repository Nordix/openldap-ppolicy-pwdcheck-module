/*
 * check_password.c for OpenLDAP
 *
 * See LICENSE and README.md files.
 */

#ifndef CHECK_PASSWORD_H
#define CHECK_PASSWORD_H

#include <stdio.h>
#include <time.h>

#ifndef LOGGER_LEVEL
#define LOGGER_LEVEL LOGGER_LEVEL_WARNING
#endif

#define LOGGER_LEVEL_DEBUG	 0
#define LOGGER_LEVEL_INFO	 1
#define LOGGER_LEVEL_WARNING 2
#define LOGGER_LEVEL_ERROR	 3
#define LOGGER_LEVEL_NONE	 9

#if LOGGER_LEVEL <= LOGGER_LEVEL_DEBUG
#define LOGGER_DEBUG(fmt, ...) LOGGER_WITH_LEVEL(fmt, "DEBUG", ##__VA_ARGS__)
#else
#define LOGGER_DEBUG(fmt, ...) LOGGER_NOOP(fmt, ##__VA_ARGS__)
#endif

#if LOGGER_LEVEL <= LOGGER_LEVEL_INFO
#define LOGGER_INFO(fmt, ...) LOGGER_WITH_LEVEL(fmt, "INFO", ##__VA_ARGS__)
#else
#define LOGGER_INFO(fmt, ...) LOGGER_NOOP(fmt, ##__VA_ARGS__)
#endif

#if LOGGER_LEVEL <= LOGGER_LEVEL_WARNING
#define LOGGER_WARNING(fmt, ...)                                               \
	LOGGER_WITH_LEVEL(fmt, "WARNING", ##__VA_ARGS__)
#else
#define LOGGER_WARNING(fmt, ...) LOGGER_NOOP(fmt, ##__VA_ARGS__)
#endif

#if LOGGER_LEVEL <= LOGGER_LEVEL_ERROR
#define LOGGER_ERROR(fmt, ...) LOGGER_WITH_LEVEL(fmt, "ERROR", ##__VA_ARGS__)
#else
#define LOGGER_ERROR(fmt, ...) LOGGER_NOOP(fmt, ##__VA_ARGS__)
#endif

#define LOGGER_WITH_LEVEL(fmt, level, ...)                                     \
	do {                                                                       \
		time_t t = time(NULL);                                                 \
		struct tm tm = *localtime(&t);                                         \
		fprintf(stderr,                                                        \
				"%d-%02d-%02dT%02d:%02d:%02d %s:%d " level ": " fmt "\n",      \
				tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour,      \
				tm.tm_min, tm.tm_sec, __FILE__, __LINE__, ##__VA_ARGS__);      \
		fflush(stderr);                                                        \
	} while (0)

#define LOGGER_NOOP(fmt, ...)                                                  \
	do {                                                                       \
	} while (0)

#endif /* CHECK_PASSWORD_H */
