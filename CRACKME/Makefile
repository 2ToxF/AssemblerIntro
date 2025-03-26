CC := g++
MAIN_FLAGS := -Wall -Wextra -Wpedantic -fpermissive -O2 -DDEBUG -g -fsanitize=address -D_FORTIFY_SOURCE=2
ADD_FLAGS  := $(shell pkg-config --libs --cflags gtk4 gstreamer-1.0)

MAIN_SRC_DIR := source
SRC_DIRS 	 := $(MAIN_SRC_DIR)/ $(wildcard $(MAIN_SRC_DIR)/*/)
SRC_DIRS 	 := $(SRC_DIRS:%/=%)
MAIN_OBJ_DIR := object
OBJ_DIRS 	 := $(SRC_DIRS:$(MAIN_SRC_DIR)%=$(MAIN_OBJ_DIR)%)

SOURCES  := $(foreach dir,$(SRC_DIRS),$(wildcard $(dir)/*.cpp))
INCLUDES := $(foreach dir,$(SRC_DIRS),$(wildcard $(dir)/*.h))
OBJECTS  := $(SOURCES:$(MAIN_SRC_DIR)/%.cpp=$(MAIN_OBJ_DIR)/%.o)
BIN      := crack

DOCS_NAME := docs_config

I_FLAGS    := $(SRC_DIRS:%=-I%)
COMP_FLAGS := $(MAIN_FLAGS) $(ADD_FLAGS) $(I_FLAGS)
LINK_FLAGS := $(MAIN_FLAGS) $(ADD_FLAGS)

all: $(BIN)

$(BIN): $(OBJECTS)
	@$(CC) $(LINK_FLAGS) $(OBJECTS) -o $@

$(OBJECTS): $(MAIN_OBJ_DIR)/%.o: $(MAIN_SRC_DIR)/%.cpp $(INCLUDES) | $(OBJ_DIRS)
	@$(CC) -c $(COMP_FLAGS) $< -o $@

$(OBJ_DIRS): %:
	@mkdir $@

run: $(BIN)
	@./$(BIN)

docs:
	@doxygen $(DOCS_NAME)


clean: clean_obj clean_bin

clean_obj:
	rm $(MAIN_OBJ_DIR)/*.o

clean_bin:
	rm *.out
