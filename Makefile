.PHONY: all clean
.DEFAULT: all

ifdef PE_ENV
  CXX = CC
endif

ifeq ($(PE_ENV), CRAY)
  toolchain = cray

  # CCE 9 and above use Clang frontend for C/C++ code
  is_clang = $(shell $(CXX) --version 2> /dev/null | grep 'Cray clang')
  ifneq ($(is_clang),)
    toolchain = clang
  endif
else ifeq ($(PE_ENV), PGI)
  toolchain = pgi
else ifeq ($(PE_ENV), INTEL)
  toolchain = intel
else ifeq ($(PE_ENV), GNU)
  toolchain = gnu
endif

toolchain ?= gnu

ifeq ($(toolchain), cray)
  ifndef PE_ENV
    CC  = craycc
    CXX = crayCC
  endif
  OMP_FLAGS = -homp -hstd=c++11
else ifeq ($(toolchain), pgi)
  ifndef PE_ENV
    CC  = pgcc
    CXX = pgc++
  endif
  OMP_FLAGS = -mp
else ifeq ($(toolchain), intel)
  ifndef PE_ENV
    CC  = icc
    CXX = icpcp
  endif
  OMP_FLAGS = -Wall -qopenmp -std=c++11
else ifeq ($(toolchain), gnu)
  ifndef PE_ENV
    CC  = gcc
    CXX = g++
  endif
  OMP_FLAGS = -Wall -fopenmp -std=c++11
else ifeq ($(toolchain), clang)
  ifndef PE_ENV
    CC  = clang
    CXX = clang++
  endif
  OMP_FLAGS = -Wall -fopenmp -std=c++11
endif


DEBUG  ?= 0
OPENMP ?= 1
MPI    ?= 0
MKDIR_P = mkdir -p
RM      = /bin/rm

MAKE_CPPFLAGS = -D_GNU_SOURCE -Iinclude -I${GTEST_ROOT}/include
MAKE_CXXFLAGS =
MAKE_LDFLAGS  = -L.

ifeq ($(DEBUG), 1)
  MAKE_CPPFLAGS += -D_DEBUG_
  MAKE_CXXFLAGS += -g -O0
else
  MAKE_CPPFLAGS += -DNDEBUG
  MAKE_CXXFLAGS += -g -O3
endif

ifeq ($(OPENMP), 1)
  MAKE_CXXFLAGS += $(OMP_FLAGS)
  MAKE_LDFLAGS  += $(OMP_FLAGS)
endif

ifeq ($(MPI), 1)
  MAKE_CPPFLAGS += -DUSE_MPI
endif

CPU_CPPFLAGS = $(MAKE_CPPFLAGS) $(CPPFLAGS)
CPU_CXXFLAGS = $(MAKE_CXXFLAGS) $(CXXFLAGS)
CPU_LDFLAGS  = $(LDFLAGS) $(MAKE_LDFLAGS)

CPU_COMPILE = $(CXX) -c $(CPU_CXXFLAGS) $(CPU_CPPFLAGS)

LIBRARIES =

PROGRAMS = affinity
ifdef GTEST_ROOT
  PROGRAMS += tests/test_cpuset
endif

affinity_SOURCES = \
	src/affinity.cpp
test_cpuset_SOURCES = \
	tests/test_cpuset.cpp

affinity_OBJECTS = $(affinity_SOURCES:.cpp=.o) $(LIBRARIES)
affinity_DEPS = $(affinity_OBJECTS:.o=.d)
affinity_LIBS =


test_cpuset_OBJECTS = $(test_cpuset_SOURCES:.cpp=.o) $(LIBRARIES)
test_cpuset_DEPS = $(test_cpuset_OBJECTS:.o=.d)
test_cpuset_LIBS =

all: $(PROGRAMS) $(LIBRARIES)

-include $(affinity_DEPS)
-include $(test_cpuset_DEPS)

%.o: %.cpp
	$(CPU_COMPILE) $*.cpp -o $*.o
	@$(CC) -std=c++11 -MM $(CPU_CPPFLAGS) $*.cpp > $*.d
	@cp -f $*.d $*.d.tmp
	@sed -e 's/.*://' -e 's/\\$$//' < $*.d.tmp | fmt -1 | \
	  sed -e 's/^ *//' -e 's/$$/:/' >> $*.d
	@rm -f $*.d.tmp


affinity: $(affinity_OBJECTS) $(affinity_LIBS)
	$(CXX) -o $@ $(affinity_OBJECTS) $(affinity_LIBS) $(CPU_LDFLAGS)

tests/test_cpuset: $(test_cpuset_OBJECTS) $(test_cpuset_LIBS)
	$(CXX) -o $@ $(test_cpuset_OBJECTS) $(test_cpuset_LIBS) $(CPU_LDFLAGS)


clean:
	$(RM) -f $(PROGRAMS) $(affinity_OBJECTS) $(affinity_DEPS) $(test_cpuset_OBJECTS)
