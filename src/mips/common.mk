PREFIX = mipsel-linux-gnu
BUILD ?= Release

ROOTDIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

CC  = $(PREFIX)-gcc
CXX = $(PREFIX)-g++

TYPE ?= cpe
LDSCRIPT ?= $(ROOTDIR)/$(TYPE).ld
ifneq ($(strip $(OVERLAYSCRIPT)),)
LDSCRIPT := $(addprefix $(OVERLAYSCRIPT) , -T$(LDSCRIPT))
else
LDSCRIPT := $(addprefix $(ROOTDIR)/default.ld , -T$(LDSCRIPT))
endif

USE_FUNCTION_SECTIONS ?= true

ARCHFLAGS = -march=mips1 -mabi=32 -EL -fno-pic -mno-shared -mno-abicalls -mfp32
ARCHFLAGS += -fno-stack-protector -nostdlib -ffreestanding
ifeq ($(USE_FUNCTION_SECTIONS),true)
CPPFLAGS += -ffunction-sections
endif
CPPFLAGS += -mno-gpopt -fomit-frame-pointer
CPPFLAGS += -fno-builtin -fno-strict-aliasing -Wno-attributes
CPPFLAGS += $(ARCHFLAGS)
CPPFLAGS += -I$(ROOTDIR)

LDFLAGS += -Wl,-Map=$(BINDIR)$(TARGET).map -nostdlib -T$(LDSCRIPT) -static -Wl,--gc-sections
LDFLAGS += $(ARCHFLAGS)

CPPFLAGS_Release += -Os
LDFLAGS_Release += -Os

CPPFLAGS_Debug += -O0

LDFLAGS += -g
CPPFLAGS += -g

CPPFLAGS += $(CPPFLAGS_$(BUILD))
LDFLAGS += $(LDFLAGS_$(BUILD))

OBJS += $(addsuffix .o, $(basename $(SRCS)))

all: dep $(BINDIR)$(TARGET).$(TYPE)

$(BINDIR)$(TARGET).$(TYPE): $(BINDIR)$(TARGET).elf
ifneq ($(strip $(BINDIR)),)
	mkdir -p $(BINDIR)
endif
	$(PREFIX)-objcopy $(addprefix -R , $(OVERLAYSECTION)) -O binary $< $@
	$(foreach ovl, $(OVERLAYSECTION), $(PREFIX)-objcopy -j $(ovl) -O binary $< $(BINDIR)Overlay$(ovl);)

$(BINDIR)$(TARGET).elf: $(OBJS)
	$(CC) -g -o $(BINDIR)$(TARGET).elf $(OBJS) $(LDFLAGS)

%.o: %.s
	$(CC) $(ARCHFLAGS) -I$(ROOTDIR) -g -c -o $@ $<

%.dep: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -M -MT $(addsuffix .o, $(basename $@)) -MF $@ $<

%.dep: %.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -M -MT $(addsuffix .o, $(basename $@)) -MF $@ $<

%.dep: %.cc
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -M -MT $(addsuffix .o, $(basename $@)) -MF $@ $<

# A bit broken, but that'll do in most cases.
%.dep: %.s
	touch $@

DEPS := $(patsubst %.cpp, %.dep,$(filter %.cpp,$(SRCS)))
DEPS := $(patsubst %.cc,  %.dep,$(filter %.cc,$(SRCS)))
DEPS +=	$(patsubst %.c,   %.dep,$(filter %.c,$(SRCS)))
DEPS += $(patsubst %.s,   %.dep,$(filter %.s,$(SRCS)))

dep: $(DEPS)	

clean:	
	rm -f $(OBJS) $(BINDIR)Overlay.* $(BINDIR)*.elf $(BINDIR)*.ps-exe $(BINDIR)*.map $(DEPS)

ifneq ($(MAKECMDGOALS), clean)
ifneq ($(MAKECMDGOALS), deepclean)
-include $(DEPS)
endif
endif

.PHONY: clean dep all
