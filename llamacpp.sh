#!/bin/bash

### BEFORE FIRST RUN: `chmod +x llamacpp.sh`

### cd /c -> /d if models are stored on another drive
case "$(uname -r)" in
    *microsoft*|*Microsoft*)
        WIN_ROOT="/mnt/d"
        USE_WSL=1
        ;;
    *)
        WIN_ROOT="/d"
        USE_WSL=0
        ;;
esac

PRESETS_FILE="$(cd "$(dirname "$0")" && pwd)/models.ini"
MODELS_DIR="$WIN_ROOT/huggingface"

if [[ "$USE_WSL" -eq 1 ]]; then
    WIN_PRESETS_FILE="$(wslpath -w "$PRESETS_FILE")"
    WIN_MODELS_DIR="$(wslpath -w "$MODELS_DIR")"
else
    WIN_PRESETS_FILE="$PRESETS_FILE"
    WIN_MODELS_DIR="$MODELS_DIR"
fi

### TODO: rename llama.cpp -> llamacpp-bXXXX based on build ver
cd "$WIN_ROOT/llamacpp-bXXXXX" || exit 1

SERVER_ARGS=(
    --host 127.0.0.1
    --port 8080
    --poll 100
    --prio 2
    --models-max 2
    --models-preset "$WIN_PRESETS_FILE"
    --spec-type draft-mtp
    --spec-draft-n-max 3

)

TOOL_SYSTEM_PROMPT="You are a helpful assistant. You have access to tools — use them whenever relevant to the user's request. Always call a tool if one matches the task. Do not claim you cannot use tools. When a tool call is needed, respond ONLY with the tool call, no extra text before or after."

echo "                                             "
echo "  __________________________________________"
echo "< hello, please pick from the options below. >"
echo "  ------------------------------------------"
echo "       \   ^__^"
echo "        \  (oO)\_______"
echo "           (__)\       )\/\\"
echo "            V ||----w |"
echo "               ||     ||"
echo "                                             "
echo "1) Start llama-server (router mode)"
echo "2) llama-benchmark.exe"
echo

read -rp "Select an option (1-2): " choice

case "$choice" in
    1)
        echo "Starting llama-server in router mode..."
        echo "Presets file:    $WIN_PRESETS_FILE"
        echo "Max loaded models: 2"
        echo "Tool calling: ENABLED (reasoning-budget=0, jinja=on)"
        echo
        echo "Model management:"
        echo "  List available models:  curl http://127.0.0.1:8080/models"
        echo "  Load a model:          curl -X POST http://127.0.0.1:8080/models/load -H 'Content-Type: application/json' -d '{\"model\": \"your-model.gguf\"}'"
        echo "  Unload a model:        curl -X POST http://127.0.0.1:8080/models/unload -H 'Content-Type: application/json' -d '{\"model\": \"your-model.gguf\"}'"
        echo
        echo "Tool calling example (save to a file, e.g. tool_request.json):"
        echo '  {'
        echo '    "model": "YOUR_MODEL.gguf",'
        echo '    "messages": ['
        echo "      {\"role\": \"system\", \"content\": \"$TOOL_SYSTEM_PROMPT\"},"
        echo '      {"role": "user", "content": "What is the weather in Paris?"}'
        echo '    ],'
        echo '    "tools": ['
        echo '      {"type":"function","function":{"name":"get_weather","description":"Get current weather for a city","parameters":{"type":"object","properties":{"city":{"type":"string"}},"required":["city"]}}}'
        echo '    ],'
        echo '    "tool_choice": "auto",'
        echo '    "temperature": 1.0,'
        echo '    "max_tokens": 512'
        echo '  }'
        echo
        echo '  curl -s http://127.0.0.1:8080/v1/chat/completions -H "Content-Type: application/json" -d @tool_request.json'
        echo

        ./llama-server.exe "${SERVER_ARGS[@]}" &

        echo "Waiting for llama.cpp server..."
        sleep 10
        cmd.exe /c start http://127.0.0.1:8080
        echo "Llama server running at http://127.0.0.1:8080/v1"
        wait
        ;;

    2)
        mapfile -t GGUF_FILES < <(find "$MODELS_DIR" -name '*.gguf' 2>/dev/null | sort)
        if [[ ${#GGUF_FILES[@]} -eq 0 ]]; then
            echo "No GGUF files found in $MODELS_DIR"
            exit 1
        fi

        echo "Available GGUFs:"
        echo
        for i in "${!GGUF_FILES[@]}"; do
            size=$(du -h "${GGUF_FILES[$i]}" | cut -f1)
            printf "  %2d) %-60s %s\n" $((i + 1)) "$(basename "${GGUF_FILES[$i]}")" "$size"
        done
        echo

        read -rp "Select model (1-${#GGUF_FILES[@]}): " idx
        [[ "$idx" =~ ^[0-9]+$ && idx -ge 1 && idx -le ${#GGUF_FILES[@]} ]] || { echo "Invalid selection."; exit 1; }
        BENCH_MODEL="${GGUF_FILES[$((idx - 1))]}"

        echo
        read -rp "GPU layers (0=CPU only, 999=all): " ngl
        ngl="${ngl:-999}"
        read -rp "Prompt tokens [512]: " pp
        pp="${pp:-512}"
        read -rp "Generate tokens [128]: " tg
        tg="${tg:-128}"
        read -rp "Repetitions [5]: " reps
        reps="${reps:-5}"

        echo
        echo "Benchmarking: $(basename "$BENCH_MODEL")"
        echo "  ngl=$ngl  pp=$pp  tg=$tg  reps=$reps"
        echo
        ./llama-bench.exe \
            --model "$( [ "$USE_WSL" -eq 1 ] && wslpath -w "$BENCH_MODEL" || echo "$BENCH_MODEL" )" \
            --ngl "$ngl" \
            --threads 4 \
            --batch-size 2048 \
            --ubatch-size 512 \
            --flash-attn auto \
            --cache-type-k q8_0 \
            --cache-type-v q8_0 \
            --prompt "$pp" \
            --generate-tokens "$tg" \
            --repetitions "$reps" \
            --output md \
            --progress
        ;;

    *)
        echo "Invalid selection."
        exit 1
        ;;
esac