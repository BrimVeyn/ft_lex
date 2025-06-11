# Tools
CC = gcc
AR = ar

# Files
LIBL_SRC = libl.c
LIBL_OBJ = libl.o
LIBL_STATIC = libl.a

# Default rule
all: $(LIBL_STATIC)

# Compile libl.o
$(LIBL_OBJ): $(LIBL_SRC)
	$(CC) -c $(LIBL_SRC) -o $(LIBL_OBJ)

# Create static library libl.a
$(LIBL_STATIC): $(LIBL_OBJ)
	$(AR) rcs $(LIBL_STATIC) $(LIBL_OBJ)

# Clean
clean:
	rm -f $(LIBL_OBJ) $(LIBL_STATIC)
