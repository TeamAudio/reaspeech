docker exec -w /app/reascripts/%1 reaspeech-reaspeech-1 sh -c "fswatch -m poll_monitor source/*.lua tests/*.lua | xargs -I{} make"
