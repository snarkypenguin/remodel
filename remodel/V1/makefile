# Makefile for 
# Copyright (C) 2008 Randall Gray May
# $Header$
# $Log$

CC = gcc
CFLAGS = -ggdb -O0

FLAGS = -prelude '(load "/usr/lib/slib/gambit.init")(include "framework")' -report -warnings -debug -track-scheme

# The gambitc compiler
gsc = /usr/bin/gsc-script


#OBJS = rk4.o integrate.o maths.o models.o toy.o
OBJS = support.o  utils.o  units.o  lists.o  sort.o  maths.o  \
	integrate.o  matrix.o  postscript.o  basic-population.o  sclos.o  \
	framework-controls.o  declarations.o  log-declarations.o  framework-classes.o  \
	log-classes.o  framework-methods.o  log-methods.o  model-classes.o  landscape-classes.o  \
	animal-classes.o  model-methods.o  animal-methods.o  landscape-methods.o  kernel.o \

MOBJS =	${OBJS} model-configuration.o  model-parameters.o model.o

CS = $(OBJS:.o=.c)
SCMS = $(OBJS:.o=.scm)

MCS = ${CS} $(MOBJS:.o=.c)
MSCMS = ${SCMS} $(MOBJS:.o=.scm)

all:
	echo Try "'make clean'", "'make model'" or "'make support-lib.so'"


%.c:	%.scm
	$(gsc) $(FLAGS) -c $<

SCMSUPLIBS = support.scm maths.scm integrate.scm units.scm postscript.scm basic-population.scm sclos.scm framework-controls.scm
SCMSUPC = $(SCMSUBLIBS:.c=.scm)

support-lib.scm:	$(SCMSUPLIBS)
	cat $(SCMSUPLIBS) | fgrep -v '(load ' > support-lib.scm

support-lib.so: support-lib.scm
	$(gsc) -link -flat -o support-lib.o1.c 
	$(gsc) -cc-options "-D___DYNAMIC" -obj support-lib.o1.c
	gcc -shared support-lib.o1.o -o support-lib.so

model:	$(MCS)
	$(gsc) $(FLAGS) -link $(MCS) 
	gcc -o model -I/usr/current/include $(CS) model_.c -L/usr/lib -lgambc -lm -ldl -lutil

clean:
	rm -f *.o[0-9] $(CS) model_.c model

tgz:	framework makefile $(SCMS)
	tar czvf Model.tgz framework makefile $(SCMS) my-etc

#model:	rk4.scm integrate.scm maths.scm models.scm model.scm 
#	rm -f *.so* *.la *.a *.anl *.cls *.flt *.hod *.stt *.typ core *.c *.h 
#	hob -o model rk4.scm integrate.scm maths.scm models.scm model.scm 
#
#verbose:	rk4.scm integrate.scm maths.scm models.scm model.scm 
#	rm -f *.so* *.la *.a *.anl *.cls *.flt *.hod *.stt *.typ core *.c *.h 
#	hob -v -o model rk4.scm integrate.scm maths.scm models.scm model.scm 
#
#debug:	rk4.scm integrate.scm maths.scm models.scm model.scm 
#	rm -f *.so* *.la *.a *.anl *.cls *.flt *.hod *.stt *.typ core *.c *.h 
#	hob -d -v -o model rk4.scm integrate.scm maths.scm models.scm model.scm 
#
#models:	rk4.scm integrate.scm maths.scm models.scm test-models.scm
#	rm -f *.so* *.la *.a *.anl *.cls *.flt *.hod *.stt *.typ core *.c *.h 
#	hob -o model rk4.scm integrate.scm maths.scm models.scm test-models.scm 
#
#integrate:	rk4.scm integrate.scm maths.scm test-integrate.scm
#	rm -f *.so* *.la *.a *.anl *.cls *.flt *.hod *.stt *.typ core *.c *.h 
#	hob -o model rk4.scm integrate.scm maths.scm test-integrate.scm
#
##	hob -o model model.scm maths.scm integrate.scm rk4.scm
#
#clean:
#		rm -f core *.so* *.la *.a *.anl *.cls *.flt *.hod *.stt *.typ *.c *.h model
#
#
#

