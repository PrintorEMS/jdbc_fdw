# contrib/jdbc_fdw/Makefile

MODULE_big = jdbc_fdw
OBJS = jdbc_fdw.o option.o deparse.o connection.o jq.o

PG_CPPFLAGS = -I$(libpq_srcdir)
SHLIB_LINK = $(libpq)

EXTENSION = jdbc_fdw
DATA = jdbc_fdw--1.0.sql jdbc_fdw--1.0--1.1.sql jdbc_fdw--1.2.sql

REGRESS = postgresql/new_test postgresql/aggregates postgresql/date postgresql/float8 postgresql/insert postgresql/select postgresql/update postgresql/delete postgresql/float4 postgresql/int4 postgresql/int8 postgresql/ported_postgres_fdw postgresql/exec_function 

JDBC_CONFIG = jdbc_config

# Locate the JVM shared library (libjvm.so) to link against.
#
# libjvm.so does not live in a standard linker search path (e.g. /usr/lib64);
# its location depends on which JDK is installed (vendor, version, arch), e.g.
#   /usr/lib/jvm/java-21-openjdk-amd64/lib/server/libjvm.so
#
# Respect JAVA_HOME if the caller has set it; otherwise try to discover it
# from the `java` binary on PATH.
ifndef JAVA_HOME
JAVA_HOME := $(shell java -XshowSettings:properties -version 2>&1 | sed -n 's/^[[:space:]]*java\.home = //p')
endif

ifeq ($(strip $(JAVA_HOME)),)
$(error JAVA_HOME is not set and could not be auto-detected from `java` on PATH. Please `export JAVA_HOME=/path/to/your/jdk` and retry)
endif

LIBJVM_DIR := $(shell find $(JAVA_HOME) -name 'libjvm.so' 2>/dev/null | xargs -r -n1 dirname | head -1)

ifeq ($(strip $(LIBJVM_DIR)),)
$(error Could not find libjvm.so under JAVA_HOME ($(JAVA_HOME)). Please check your JDK installation)
endif

# -L to find it at link time, -rpath so the backend can dlopen() it at
# runtime too (libjvm.so is normally not in the system ldconfig cache).
SHLIB_LINK += -L$(LIBJVM_DIR) -Wl,-rpath,$(LIBJVM_DIR) -ljvm

UNAME = $(shell uname)

JAVA_SOURCES = \
	JDBCUtils.java \
	JDBCDriverLoader.java \
	JDBCConnection.java \
	resultSetInfo.java

# Generate a list of .class files corresponding to .java files
JAVA_CLASSES = $(patsubst %.java,%.class,$(JAVA_SOURCES))

PG_CPPFLAGS=-D'SHARE_EXT_DIR=$(datadir)/extension' -I$(libpq_srcdir)

# Target to compile all Java source files
all:$(JAVA_CLASSES)

# Rules for compiling each .java file into a .class
%.class: %.java
	javac $<

# Use DATA_built to install .class files
DATA_built = $(JAVA_CLASSES)

# the db name is hard-coded in the tests
override USE_MODULE_DB =

ifdef USE_PGXS
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
else
SHLIB_PREREQS = submake-libpq
subdir = contrib/jdbc_fdw
top_builddir = ../..
include $(top_builddir)/src/Makefile.global
include $(top_srcdir)/contrib/contrib-global.mk
endif

ifdef REGRESS_PREFIX
REGRESS_PREFIX_SUB = $(REGRESS_PREFIX)
else
REGRESS_PREFIX_SUB = $(VERSION)
endif

REGRESS := $(addprefix $(REGRESS_PREFIX_SUB)/,$(REGRESS))
$(shell mkdir -p results/$(REGRESS_PREFIX_SUB)/griddb)
$(shell mkdir -p results/$(REGRESS_PREFIX_SUB)/mysql)
$(shell mkdir -p results/$(REGRESS_PREFIX_SUB)/postgresql)
