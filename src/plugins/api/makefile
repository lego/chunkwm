BUILD_FLAGS		= -O0 -g -std=c++11 -Wall -I. -Wno-unused-variable
BUILD_PATH		= ./../../../plugins
SRC				= ./plugin.mm $(shell find . -name "*.c" -o -name "*.cpp")
BINS			= $(BUILD_PATH)/api.so
LINK			= -shared -fPIC -framework Carbon -framework Cocoa -framework ApplicationServices

all: $(BINS)

install: BUILD_FLAGS=-O2 -std=c++11 -Wall
install: clean $(BINS)

.PHONY: all clean install

$(BUILD_PATH):
	mkdir -p $(BUILD_PATH)

clean:
	rm -f $(BUILD_PATH)/api.so

$(BUILD_PATH)/api.so: $(SRC) | $(BUILD_PATH)
	clang++ $^ $(BUILD_FLAGS) -o $@ $(LINK)
