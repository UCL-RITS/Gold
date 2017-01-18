/******************************************************************************
 *                                                                            *
 *                             Copyright (c) 2005                             *
 *                 Pacific Northwest National Laboratory,                     *
 *                        Battelle Memorial Institute.                        *
 *                            All rights reserved.                            *
 *                                                                            *
 ******************************************************************************
 *                                                                            *
 *    Redistribution and use in source and binary forms, with or without      *
 *    modification, are permitted provided that the following conditions      *
 *    are met:                                                                *
 *                                                                            *
 *    · Redistributions of source code must retain the above copyright        *
 *    notice, this list of conditions and the following disclaimer.           *
 *                                                                            *
 *    · Redistributions in binary form must reproduce the above copyright     *
 *    notice, this list of conditions and the following disclaimer in the     *
 *    documentation and/or other materials provided with the distribution.    *
 *                                                                            *
 *    · Neither the name of the Battelle nor the names of its contributors    *
 *    may be used to endorse or promote products derived from this software   *
 *    without specific prior written permission.                              *
 *                                                                            *
 *    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS     *
 *    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT       *
 *    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS       *
 *    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE          *
 *    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,     *
 *    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,    *
 *    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;        *
 *    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER        *
 *    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT      *
 *    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN       *
 *    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         *
 *    POSSIBILITY OF SUCH DAMAGE.                                             *
 *                                                                            *
 ******************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h> 
#include <fcntl.h>
#include <string.h>
#include <pwd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <openssl/hmac.h>

#define GOLD_ADMIN "gold"
#define GOLD_HOME "/opt/gold"

main(int argc, char *argv[])
{
  int num, bytes_read, fd, c, i;
  int dlen = EVP_MAX_MD_SIZE;
  int debug = 0;
  char actor[256], uid[256], key[256], keyfile[256];
  char *quote, *request;
  char digest[EVP_MAX_MD_SIZE];
	struct passwd *passwd_s;
	FILE *fp;

  /* Check Usage */
  while ((c = getopt(argc, argv, "c:s:")) != -1)
  {
    switch (c)
    { 
      case 'd':
        debug = 1;
        break;
      default:
        fprintf(stderr, "Usage:\t%s -d\n", argv[0]);
        return 1;
    }
  }

  /* Extract actor from request string */
  num = scanf("<Request action=\"%*255s actor=\"%255s", actor);
  quote = strstr(actor, "\"");
  *quote = 0;

printf("actor = %s\n", actor);

  /* Determine uid running this program */
  passwd_s = getpwuid(getuid());
	strncpy(uid, passwd_s->pw_name, sizeof(uid) - 1);
  uid[sizeof(uid) - 1] = 0;

printf("uid = %s\n", uid);
  
  /* Verify that actor = uid */
  if (strcmp(actor, uid) != 0)
  {
    fprintf(stderr, "actor is not the same as the invoking user\n");
    return 2;
  }

	/* Setuid to gold admin */
	passwd_s = getpwnam(GOLD_ADMIN);
	setuid(passwd_s->pw_uid);

  /* Build keyfile from compiled default */
  strcpy(keyfile, GOLD_HOME);
  strcat(keyfile, "/etc/auth_key");

  /* Open the keyfile */
  fd = open(keyfile, O_RDONLY);
  if (fd < 0)
  {
    fprintf(stderr, "Unable to open keyfile (%s) for reading: %s\n", keyfile, strerror(errno));
    exit(errno);
  }

  /* Read the hash key */
  bytes_read = read(fd, key, sizeof(key));
  if ( bytes_read == -1)
  {
    fprintf(stderr, "Error reading hash key from keyfile (%s): %s\n", keyfile);
    exit(errno);
  }
  key[bytes_read] = 0; /* Null terminate the string */
  for (i = strlen(key)-1; i>0; i--) /* Remove carriage return if any */
  {
    if (!isspace(key[i])) break;
    key[i] = 0;
  }

  /* Close the file */
  close(fd);

  /* Compute the keyed hash for the data and key */
  cp = HMAC(EVP_sha1(), key, strlen(key), request, strlen(request), digest, &dlen);

  /* Print the checksum to stdout */
  pr_sha(stdout, digest, dlen);

  return 0;
}


