#!/usr/bin/env bash

if [ "$TMUX_PANE" = "%0" ]; then
./txtimc -q -s localhost -p 15401
fi
if [ "$TMUX_PANE" = "%1" ]; then
./txtimc -q -s localhost -p 15400
fi
if [ "$TMUX_PANE" = "%2" ]; then
./txtimc -q -s localhost -p 15401
fi
if [ "$TMUX_PANE" = "%3" ]; then
./txtimc -q -s localhost -p 15400
fi
