#!/usr/bin/env bash
# Writes fixtures/note.wav: the Mac's Spanish voice reading fixtures/reference.txt, as the phone
# records (16 kHz mono 16-bit PCM). An invented note, so nothing a real person said is in the
# eval; the WAV itself is git-ignored and rebuilt here.
set -euo pipefail
cd "$(dirname "$0")/fixtures"
say -v "Eddy (Spanish (Mexico))" -o note.aiff "$(cat reference.txt)"
ffmpeg -loglevel error -y -i note.aiff -ac 1 -ar 16000 -c:a pcm_s16le note.wav
rm note.aiff
echo "fixtures/note.wav: $(python3 -c 'import wave;w=wave.open("note.wav");print(round(w.getnframes()/w.getframerate(),1))') s"
