CXX=g++
CXXFLAGS=-g -Wall -std=c++1y -I$(INC_DIR) 
LDFLAGS=-L$(LIB_DIR) $(LIBS)
PERFOPTS=-march=native -mtune=native -fopenmp -O3 
CXXASSEMBLYFLAGS=-S -g -fverbose-asm

# make sure likwid is installed to this prefix
# manual install to this directory is preferred because then we can run without
# sudo permission
PREFIX=/usr/local
INC_DIR=$(PREFIX)/include
LIB_DIR=$(PREFIX)/lib
LIBS=

MAIN_DIR=src
SRC_DIR=lib
OBJ_DIR=obj
ASM_DIR=asm
EXEC_DIR=bin
TEST_EXEC_DIR=$(EXEC_DIR)/tests
TEST_DIR=tests

SOURCES=$(wildcard lib/*.cpp)
HEADERS=$(wildcard lib/*.h)
MAINS=$(wildcard src/*.cpp)
TEST_LIBS=$(wildcard tests/*.cpp)
TEST_LIB_HEADERS=$(wildcard tests/*.h)

LIB_OBJS=$(SOURCES:$(SRC_DIR)/%.cpp=$(OBJ_DIR)/%.o)
OBJS=$(LIB_OBJS)
OBJS+=$(MAINS:$(MAIN_DIR)/%.cpp=$(OBJ_DIR)/%.o)
OBJS+=$(TEST_LIBS:$(TEST_DIR)/%.cpp=$(OBJ_DIR)/%.o)

ASM=$(SOURCES:$(SRC_DIR)/%.cpp=$(ASM_DIR)/%.s)
ASM+=$(MAINS:$(MAIN_DIR)/%.cpp=$(ASM_DIR)/%.s)
ASM+=$(TEST_LIBS:$(TEST_DIR)/%.cpp=$(ASM_DIR)/%.s)

EXEC_NAME=tsp-ilp
EXEC=$(EXEC_DIR)/$(EXEC_NAME)
TEST_EXEC_NAME=test-tsp-ilp
TEST_EXEC=$(EXEC_DIR)/$(TEST_EXEC_NAME)

### meta-rules for easier calling
build: $(EXEC) $(TEST_EXEC)

tests: $(TEST_EXEC)
	$(TEST_EXEC)

assembly: $(ASM) 

### utility rules
debug:
	@echo "sources:       $(SOURCES)";
	@echo "mainfiles:     $(MAIN_DIR)";
	@echo "lib objects:   $(LIB_OBJS)";
	@echo "objects:       $(OBJS)";
	@echo "exec:          $(EXEC)";
	@echo "asm:           $(ASM)"; 
debug: LDFLAGS += -Q --help=target
# debug: clean build

clean:
	rm -f $(OBJS) $(EXEC)

### rules to create directories
$(EXEC_DIR):
	mkdir $(EXEC_DIR)

$(OBJ_DIR):
	mkdir $(OBJ_DIR)

$(TEST_EXEC_DIR):
	mkdir $(TEST_EXEC_DIR)

$(ASM_DIR):
	mkdir $(ASM_DIR)

### rules to link executables
define ld-command
$(CXX) $(LIB_OBJS) $< $(LDFLAGS) -o $@
endef

$(EXEC): $(OBJ_DIR)/main-tsp-ilp.o $(LIB_OBJS) | $(EXEC_DIR)
	$(ld-command)

$(TEST_EXEC): $(OBJ_DIR)/main-test.o $(LIB_OBJS) | $(EXEC_DIR)
	$(ld-command)

### rules to compile sources
$(OBJS): $(HEADERS) $(TEST_LIB_HEADERS) | $(OBJ_DIR)

define compile-command
$(CXX) $(CXXFLAGS) -c $< -o $@
endef

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.cpp
	$(compile-command)

$(OBJ_DIR)/%.o: $(TEST_DIR)/%.cpp
	$(compile-command)

$(OBJ_DIR)/%.o: $(TEST_DIR)/%.c
	$(compile-command)

$(OBJ_DIR)/%.o: $(MAIN_DIR)/%.cpp
	$(compile-command)

### rules to create assembly files
$(ASM): | $(ASM_DIR)

define asm-command
$(CXX) $(CXXFLAGS) $(CXXASSEMBLYFLAGS) $< -o $@
endef

$(ASM_DIR)/%.s: $(SRC_DIR)/%.cpp 
	$(asm-command)

$(ASM_DIR)/%.s: $(TEST_DIR)/%.cpp
	$(asm-command)

$(ASM_DIR)/%.s: $(TEST_DIR)/%.c
	$(asm-command)

$(ASM_DIR)/%.s: $(MAIN_DIR)/%.cpp
	$(asm-command)

### manual commands for each test
#TODO: make this more DRY...
bin/tests/benchmark-likwid-vs-manual: $(OBJ_DIR)/benchmark-likwid-vs-manual.o $(LIB_OBJS) | $(TEST_EXEC_DIR)
	$(ld-command)

run-tests/benchmark-likwid-vs-manual: bin/tests/benchmark-likwid-vs-manual 
	bin/tests/benchmark-likwid-vs-manual

bin/tests/thread_migration: $(OBJ_DIR)/thread_migration.o $(LIB_OBJS)  | $(TEST_EXEC_DIR)
	$(ld-command)

run-tests/thread_migration: bin/tests/thread_migration
	bin/tests/thread_migration 0; \
	# bin/tests/thread_migration 1; \
	bin/tests/thread_migration 2;

bin/tests/likwid_minimal: $(OBJ_DIR)/likwid_minimal.o $(LIB_OBJS) | $(TEST_EXEC_DIR)
	$(ld-command)

run-tests/likwid_minimal: bin/tests/likwid_minimal
	likwid-perfctr -C S0:0 -g L3 -g FLOPS_DP -M 1 -m bin/tests/likwid_minimal