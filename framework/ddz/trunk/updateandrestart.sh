#!/bin/bash

#source server.env

if [ ! -d "$PROJECTROOT/$PROJECTCOMMON" ]; then
    cd $PROJECTROOT
    svn checkout $PROJECTSVNCOMMON
else
    cd $PROJECTROOT/$PROJECTCOMMON
	svn cleanup
	svn update --force
fi

if [ ! -d "$PROJECTROOT/$PROJECTGAME" ]; then
    cd $PROJECTROOT
    svn checkout $PROJECTSVN
else
    cd $PROJECTROOT/$PROJECTGAME
	svn cleanup
	svn update --force
fi

cd $PROJECTROOT/$PROJECTDIR

./server.sh restart all