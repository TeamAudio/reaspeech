docker exec -w /app/reascripts/%1 reaspeech-reaspeech-gpu-1 sh -c "fswatch -m poll_monitor source/*.lua libs/*.lua tests/*.lua | xargs -I{} make"
