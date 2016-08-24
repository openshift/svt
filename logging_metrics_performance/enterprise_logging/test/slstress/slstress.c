/********************************************************************
 * slstress.c - simple syslog stress tool
 * 
 * Compile: gcc -Wall -o slstress slstress.c
 * 
 * Copyright (C) 2016 Jiri Mencak; Red Hat, Inc.
 *
 * slstress is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as 
 * published by the Free Software Foundation; version 2.1.
 *
 * slstress is distributed in the hope that it will be useful, but 
 * WITHOUT ANY WARRANTY; without even the implied warranty of 
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
 * GNU Lesser General Public License for more details.
 *******************************************************************/

#define _GNU_SOURCE
#include <syslog.h>	/* syslog() */
#include <stdlib.h>	/* rand(), calloc(), ... */
#include <stdio.h>	/* fprinf(), stderr, ... */
#include <signal.h>	/* signal() */
#include <string.h>	/* strlen() */
#include <unistd.h>	/* usleep() */

/* Macros. */
#define PNAME		"slstress"
#define OPL(s)		(((s) == NULL)? 0: (strncmp(opt, (s), (opt_off = strlen(s))) == 0))

/* Structure for options and list of them. */
typedef struct option_item {
  const char sw;		/* switch (-/+) */
  const char *short_name;
  const char *long_name;
  const char *help_text;	/* can be NULL */
} option_item;

/********************************************************************
 * Constants
 ********************************************************************/
option_item optionlist[] = {
  { '-', "h[#]", "help[=#]",		"display help and exit (#: help level)" },
  { '-', "l#", "string-length=#",	NULL },
  { '-', "s#", "seed=#",		"seed for srand()" },
  { '-', "t<p>", "tag=<p>",		"mark every line to be logged with specified tag <p>" },

  { 0, NULL, NULL,			NULL }
};
#define D_LEN		256		/* default string length */
#define D_USECS		1000000		/* default delay in microseconds */

/* Global variables. */
const char charset[] = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";

/* Options. */
unsigned int help = 0;			/* 0: no help; 1: basic help; ... */
unsigned int seed = 0;			/* seed for srand() */
unsigned long msg_sent = 0;		/* messages sent to syslog */
unsigned int string_length = D_LEN;	/* length of a string being sent through syslog */
unsigned int usecs = D_USECS;		/* sleep delay microseconds between syslog() calls */
char *tag = PNAME;			/* default tag */

/********************************************************************
 * Usage function
 ********************************************************************/
void
usage(int ret_val)
{
  option_item *op;
 
  fprintf(stderr, "Usage: %s [-", PNAME);

  for (op = optionlist; op->short_name != 0; op++)
  {
    if(op->sw == '+') continue;
    putc(op->short_name[0], stderr);
  }

  fprintf(stderr, "] [LONG-OPT] <DELAY>\n");

  fprintf(stderr, "Example: %s -tmy_test -l1024 %u\n", PNAME, usecs);
/*  fprintf(stderr, "Type `%s --help' for more information.\n", PNAME); */
}

void
hlp(int l)
{
  option_item *op;

  usage(0);
  fprintf(stderr, "\n");
  fprintf(stderr, "Options:\n");
  
  for (op = optionlist; op->sw != 0; op++)
  {
    int n;
    char s[32];
    s[0] = 0;
    if (op->short_name) 
      sprintf(s, "  %c%s%s%n", op->sw, op->short_name, op->long_name? ",": "", &n);
    else n = 0;
    n = 9 - n;					/* 9 */
    if (n < 1) n = 1;
    fprintf(stderr, "%s%.*s", s, n, "         ");	/* 9 spaces */
    s[0] = 0;
    if (op->long_name) sprintf(s,"%c%c%s%n", op->sw, op->sw, op->long_name, &n);
    else n = 0;
    n = 23 - n;
    if (n < 1) n = 1;
    fprintf(stderr, "%s%.*s", s, n, "                           ");

    if(op->short_name)
      switch(op->short_name[0]) {
      case 'l':
        fprintf(stderr, "string length to be sent to syslog (%d)\n", string_length);
      break;

      default:
        fprintf(stderr,"%s\n", op->help_text);
      } else {
        /* we ran out of short options..., distinguish by the long one */
      }
  }
}


/********************************************************************
 * Parse command-line option (global)
 *
 * Returns:
 *  -1: parameter was found (opt doesn't start with -+)
 *   0: option was found
 *   1: option was NOT found
 *   2: an error
 ********************************************************************/
int
parse_cmd_opt(char *opt)
{
  int opt_off;
  char *p_err;

  if(opt == NULL) {
    /* internal error */
    perror("opt == NULL\n");
    exit(EXIT_FAILURE);
  }

  /* Process the options */

  /* Parameters */
  if (!(*opt == '-' || *opt == '+')) 
    return -1;

  if (OPL("-h") || OPL("-?") || OPL("--help"))
  { /* help */
    if(opt_off > 2 && *(opt + opt_off) == '=')
      /* long option, ignore '=' */
      opt_off++;
      
    help = strtol(opt + opt_off, &p_err, 0);
    if (p_err == opt + opt_off || *p_err) {
      /* no option value given || value contains invalid/non-digit char */
      help = 0;
    }

    hlp(0);
    exit(0);
  }

  if (OPL("-l") || OPL("--string-length"))
  {
    if(opt_off > 2 && *(opt + opt_off) == '=')
      /* long option, ignore '=' */
      opt_off++;

    string_length = strtol(opt + opt_off, &p_err, 0);
    if (p_err == opt + opt_off || *p_err) {
      /* no option value given || value contains invalid/non-digit char */
      fprintf(stderr, "string-length `%s' not an integer\n", p_err);
      exit(EXIT_FAILURE);
    }

    return 0;
  }

  if (OPL("-s") || OPL("--seed"))
  {
    if(opt_off > 2 && *(opt + opt_off) == '=')
      /* long option, ignore '=' */
      opt_off++;

    seed = strtol(opt + opt_off, &p_err, 0);
    if (p_err == opt + opt_off || *p_err) {
      /* no option value given || value contains invalid/non-digit char */
      fprintf(stderr, "seed length `%s' not an integer\n", p_err);
      exit(EXIT_FAILURE);
    }

    return 0;
  }

  if (OPL("-t") || OPL("--tag="))
  { 
    tag=opt + opt_off;

    return 0;
  }

  return 1;
}

/********************************************************************
 * Parse command-line options
 ********************************************************************/
extern int
parse_cmd_opts(int argc, char **argv)
{
  int i;

  if(argv == NULL) {
    /* internal error */
    perror("argv == NULL\n");
    exit(EXIT_FAILURE);
  }
  
  for (i = 1; i < argc; i++)
  {
    char *opt = argv[i];
    int ret_val;

    if((ret_val = parse_cmd_opt(opt) == -1))
      /* non -+ option */
      break;
  }

  return i;
}

/* Print statistics. */
void
print_stats()
{
  fprintf(stdout, "Messages sent: %lu\n", msg_sent);
  fprintf(stdout, "String length: %u\n", string_length);
  fprintf(stdout, "Delay (usecs): %u\n", usecs);
}

/* Print statistics and exit. */
void
print_stats_exit(int sig)
{
  print_stats();
  exit(EXIT_SUCCESS);
}

/* Set signal handlers. */
void
set_signals()
{
  signal(SIGUSR1, print_stats);

  signal(SIGINT, print_stats_exit);
  signal(SIGTERM, print_stats_exit);
}

/* Generate "random" string. */
static char *
rand_string(char *str, unsigned int size)
{
  unsigned int n, key;
  
  if (size) {
    --size;
    for (n = 0; n < size; n++) {
      key = rand() % (unsigned int) (sizeof charset - 1);
      str[n] = charset[key];
    }
    str[size] = '\0';
  }
  return str;
}

/* The main loop. */
void
syslog_spammer(unsigned int string_length, unsigned int usecs, char *tag)
{
  char *s=NULL;

  set_signals();
  srand(seed);

  openlog(tag, LOG_CONS | LOG_NDELAY, LOG_LOCAL0);		/* add LOG_PID to log PID too */
  s = (char *)calloc(string_length + 1, sizeof(char *));

  while(1) {
    if (s == NULL) {
      perror("calloc failed");
      exit(EXIT_FAILURE);
    }
    syslog(LOG_INFO, "%s\n", rand_string(s, string_length));
    msg_sent++;
    usleep(usecs);
  }

  closelog();

  free(s);
}

/********************************************************************
 * main()
 ********************************************************************/
int
main(int argc, char *argv[])
{
  int i;
  char *p_err;
  
  /* Parse command line options */
  i = parse_cmd_opts(argc, argv);

  if ((argc - i) != 1) {
    usage(0);
    exit(EXIT_FAILURE);
  }

  usecs = strtol(argv[i], &p_err, 0);
  if (p_err == argv[i] || *p_err) {
    /* no option value given || value contains invalid/non-digit char */
    fprintf(stderr, "<DELAY> `%s' not an integer\n", p_err);
    exit(EXIT_FAILURE);
  }

  /* Workhorse */
  syslog_spammer(string_length, usecs, tag);
  
  print_stats();

  return 0;
}
