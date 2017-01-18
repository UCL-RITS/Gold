#                                               -*- Autoconf -*-
# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.57)
AC_INIT(Gold, [2.2.0.5], [gold-support@adaptivecomputing.com])
AC_CONFIG_SRCDIR([src/goldd.pl.in])
#AC_CONFIG_HEADER([config.h])

# Checks for programs.
AC_PROG_CC
AC_PROG_LN_S
AC_PROG_MAKE_SET
AC_CHECK_PROG([RM], [rm], [rm -f])
AC_CHECK_PROG([TAR], [tar], [tar])
AC_CHECK_PROG([GZIP], [gzip], [gzip])
AC_CHECK_PROG([AUTOCONF], [autoconf], [autoconf])

# Sets the Prefix
AC_PREFIX_DEFAULT(/opt/gold)
if test "$prefix" = 'NONE'; then
  prefix='/opt/gold';
fi

# Check for Perl 5.6
AC_PATH_PROG(PERL, perl, [])
AC_ARG_VAR(PERL, [full pathname of the Perl interpreter])
if test "$PERL" = ''; then
  AC_MSG_ERROR([Perl is required. Set the PERL environment variable to specify the full pathname to Perl])
fi
$PERL -e "require 5.006;" || AC_MSG_ERROR([Perl 5.6 or newer is required])
AC_SUBST(PERL)
$PERL -e "require 5.008;" || USE_OPEN="#"
AC_SUBST(USE_OPEN)

AC_ARG_WITH(readline,
  [  --without-readline      don't use readline in interactive control program ], readline="$withval", readline="yes")
AC_CHECK_HEADERS(readline/readline.h readline/history.h, , readline="no")
AC_CHECK_LIB(termcap, main, TERMCAP_LIB="-ltermcap")
AC_CHECK_LIB(readline, main, readline="yes", readline="no", $TERMCAP_LIB)
AC_MSG_CHECKING(whether to use readline in goldsh)
if test "$readline" = "yes"; then
  READLINE_PACKAGE=" Term-ReadLine-Gnu-1.15"
  AC_MSG_RESULT(yes)
else
  READLINE_PACKAGE=""
  AC_MSG_RESULT(no)
fi
AC_SUBST(READLINE_PACKAGE)

# Determine which database type to use
AC_ARG_WITH(db,     [  --with-db=DATABASE        database to be used { Pg, mysql, SQLite } [[Pg]]], DB_TYPE=$withval, DB_TYPE=[])
if test "$DB_TYPE" = ''; then
  DB_TYPE="Pg"
  AC_MSG_NOTICE([Gold will be installed with the database "Pg"])
fi
AC_SUBST(DB_TYPE)
if test "$DB_TYPE" = 'Pg'; then
  DBD_PACKAGE=" DBD-Pg-1.32_2gold"
  DB_DATASOURCE="DBI:Pg:dbname=gold;host=${ac_hostname}"
  VARCHAR_SIZE="1024"
  FORKING_SERVER="1"
elif test "$DB_TYPE" = 'Oracle'; then
  DBD_PACKAGE=" DBD-Oracle-1.16"
  DB_DATASOURCE="DBI:Oracle:${ac_hostname}"
  VARCHAR_SIZE="1024"
  FORKING_SERVER="1"
elif test "$DB_TYPE" = 'mysql'; then
  DBD_PACKAGE=" DBD-mysql-2.9004"
  DB_DATASOURCE="DBI:mysql:database=gold;host=${ac_hostname}"
  VARCHAR_SIZE="255"
  FORKING_SERVER="1"
  SQL_INDEX_COMMENT="-- "
elif test "$DB_TYPE" = 'SQLite'; then
  DBD_PACKAGE=" DBD-SQLite-1.08"
  DB_DATASOURCE="DBI:SQLite:dbname=${prefix}/data/gold.db"
  VARCHAR_SIZE="1024"
  FORKING_SERVER="0"
  SQL_INDEX_COMMENT="-- "
else
  AC_MSG_ERROR([--with-db value must be one of Pg, mysql or SQLite])
fi
AC_SUBST(DBD_PACKAGE)
AC_SUBST(DB_DATASOURCE)
AC_SUBST(FORKING_SERVER)
AC_SUBST(VARCHAR_SIZE)
AC_SUBST(SQL_INDEX_COMMENT)

# Check for user
user=`whoami`
AC_ARG_WITH(user,     [  --with-user=USER        user id under which the gold server will run [[defaults to user running configure]]], USER=$withval, USER=[])
if test "$USER" = ''; then
  USER=$user
  AC_MSG_NOTICE([Gold will be installed under the user id $USER])
fi
AC_SUBST(USER)

# Check for log dir
AC_ARG_WITH(log_dir,
  [  --with-log-dir=PATH     directory for log files [[PREFIX/log]]],
  [LOG_DIR=$withval],
  [LOG_DIR=${prefix}/log])
AC_SUBST(LOG_DIR)

# Check for doc dir
AC_ARG_WITH(doc_dir,
  [  --with-doc-dir=PATH     directory for documentation [[PREFIX/doc]]],
  [DOC_DIR=$withval],
  [DOC_DIR=$prefix/doc])
AC_SUBST(DOC_DIR)

# Determine the site perl lib dir
SITE_PERL_LIB_DIR=`$PERL '-V:installsitelib' | sed "s/.*'\(.*\)'.*/\1/"`
AC_SUBST(SITE_PERL_LIB_DIR)

# Determine where the prerequisite perl libs should be installed
AC_ARG_WITH(perl_libs,
  [  --with-perl-libs=local|site  install policy for prerequisite perl libs [[local]]],
  [PERL_LIBS=$withval],
  [PERL_LIBS=local])
if test "$PERL_LIBS" = 'local'; then
  MAKEPL_ARG=" LIB=\$(build_root)$prefix/lib/perl5"
elif test "$PERL_LIBS" = 'site'; then
  :
else
  AC_MSG_ERROR([--with-perl-libs value must be either local or site])
fi
AC_SUBST(MAKEPL_ARG)

# Determine where we will put the gold perl libs
AC_ARG_WITH(gold_libs,
  [  --with-gold-libs=local|site  install policy for Gold perl libs [[local]]],
  [GOLD_LIBS=$withval],
  [GOLD_LIBS=local])
if test "$GOLD_LIBS" = 'local'; then
  LIB_INSTALL_DIR="libdir"
elif test "$GOLD_LIBS" = 'site'; then
  LIB_INSTALL_DIR="siteperllibdir"
else
  AC_MSG_ERROR([--with-gold-libs value must be one of local or site])
fi
AC_SUBST(LIB_INSTALL_DIR)

# Determine the cgi-bin install dir if using gui
AC_ARG_WITH(cgi-bin,
  [  --with-cgi-bin=DIR      directory to install cgi-bin files if using web gui [[/var/www/cgi-bin/gold]]],
  [CGI_BIN=$withval],
  [CGI_BIN=/var/www/cgi-bin/gold])
AC_SUBST(CGI_BIN)

# Checks for libraries.

# Checks for header files.
AC_HEADER_STDC
AC_CHECK_HEADERS([fcntl.h stdlib.h string.h])

# Checks for typedefs, structures, and compiler characteristics.

# Checks for library functions.
AC_CHECK_FUNCS([setenv strerror])

# Make variable Substitutions
AC_SUBST([PACKAGE_NAME])
AC_SUBST([PACKAGE_VERSION])
AC_SUBST([PACKAGE_TARNAME])
AC_SUBST([HOSTNAME], ${ac_hostname})
AC_SUBST([NOW], `$PERL -e 'print time'`)

# Configure the output files, and generate them.
AC_CONFIG_FILES([
  base.sql
  bank.gold
  bank.sql
  doc/installation.sgml
  doc/migration.sgml
  doc/upgrade.sgml
  doc/upgradefile.sgml
  doc/userguide.sgml
  etc/gold.conf.dist
  etc/goldd.conf.dist
  etc/goldg.conf.dist
  etc/gold.spec
  etc/gold.d
  etc/gold.sh
  etc/gold.csh
  INSTALL
  lib/Gold.pm
  lib/Gold/Global.pm
  lib/Gold/CGI.pm
  Makefile
  README
  src/goldsh.pl
  src/goldd.pl
  src/gold_init.pl])
AC_OUTPUT
