#!/bin/bash

# GOAL
# - Confirm Model access at https://huggingface.co/settings/gated-repos
#   https://huggingface.co/settings/gated-repos

test_hf_token() {

    # Good timing on the question — as of this week, the dual-Spark community has largely converged on
    # - DeepSeek V4 Flash (0731) as the daily-driver coding model
    # - with GLM-5.3 Flash as the main alternative
    # - and Qwen3.8-Flash-Next as the fast option.
    cat <<EOF
Good timing on the question — as of this week, the dual-Spark community has largely converged on DeepSeek V4 Flash (0731) as the daily-driver coding model, with GLM-5.3 Flash as the main alternative and Qwen3.8-Flash-Next as the fast option.
DeepSeek V4 Flash 0731 — my pick for "fast and smart"
On 2× Sparks it gives you 1M context, 45–60 tok/s generation and ~2000 tok/s prefill, with good general intelligence. It's also proven stable: one user running dual-Spark clusters 24/7 for business automation reports ds4flash 0731 has been up almost six weeks without a single issue, and another using it for SWE work says it handles whatever they throw at it with almost no frustrating sessions. The consensus split is DeepSeek for interactive, snappy daytime work and GLM for unattended overnight runs. There's an official FP8 recipe for TP=2 across two Sparks on the NVIDIA forums (the "DeepSeek-V4-Flash (official FP8) running across 2x DGX Spark" thread). Note that DeepSeek V4.1 Flash just appeared on Hugging Face — worth watching, but let the recipes stabilize for a couple of weeks.
DeepSeek-V4-Flash, GLM-5.3-Flash, Qwen3.8-Flash-Next +4

GLM-5.3 Flash — slightly smarter, slower
Roughly 25–35 tok/s generation and ~900 tok/s prefill at 1M context, with better intelligence than DeepSeek. Someone who ran 40 enterprise SWE-bench Pro instances got 36/40 resolved — but only after fixing a checkpoint issue. If you try it, use the RedHatAI/GLM-5.3-Flash-NVFP4 checkpoint (the LibertAI ModelOpt build emits corrupted tokens that desync tool-call parsing into repetition loops) and set temperature 0.95 / top_p 1.0 server-side. Several people hit loops before learning this.
DeepSeek-V4-Flash, GLM-5.3-Flash, Qwen3.8-Flash-Next +2

Qwen3.8-Flash-Next — the speed option
~500K context, 35–40 tok/s and ~2500 tok/s prefill, strongest at front-end and visual work. There's a ready-made FP8 TP2 serving stack for two Sparks (0rand's qwen3.8-flash-next-2x-dgx-sparks repo). It also fits on a single Spark, which leads to a popular alternative layout: run DeepSeek as the planner on one box and Qwen as the coder on another.
nvidia

Practical notes: run vLLM with TP=2 over the ConnectX-7/QSFP link (not Ray-based exo-style setups), use FP8 KV cache, and pair it with an agent harness like OpenCode, Hermes, or Claude Code pointed at the OpenAI-compatible endpoint. The forum thread "Qwen3.8-Flash-Next, GLM-5.3-Flash, DeepSeek-V4-Flash on 2x DGX Spark – prefill, TTFT, SWE-bench Pro" (posted yesterday) has head-to-head numbers if you want the details.
EOF

    # installATOIN NOTES
    cat <<EOF
DeepSeek V4 Flash

Model string: deepseek-ai/DeepSeek-V4-Flash-0731 (official FP8, the one NVIDIA's own two-Spark recipe uses; a DeepSeek-V4.1-Flash repo appeared on HF two days ago but recipes aren't settled yet)
NVIDIA's official doc for two Sparks (NemoClaw, TP=2, 1M context): https://docs.nvidia.com/nemoclaw/user-guide/hermes/inference/local-inference/set-up-vllm-on-two-dgx-sparks
Community recipe + numbers: https://forums.developer.nvidia.com/t/deepseek-v4-flash-official-fp8-running-across-2x-dgx-spark-tp-2-mtp-200k-ctx-recipe-numbers/370309
Docker compose stack: https://github.com/0rand/DeepSeek-v4-DSpark-Aidendle94-GB10-ServingStack

GLM-5.3 Flash

Base model: zai-org/GLM-5.3-Flash
Quant to use: RedHatAI/GLM-5.3-Flash-NVFP4 (avoid LibertAIDAI/GLM-5.3-Flash-NVFP4, which has the corrupted-token looping bug)
Speculative drafter: incoai/GLM-5.3-Flash-DFlash2 (note: CC-BY-NC-ND license, non-commercial)
Recipe (vLLM TP2, 262K context, patched sm121 image): https://github.com/tonyd2wild/GLM-5.3-Flash-NVFP4-DFlash2-2x-DGX-Spark
Alternative EXL3-based stack with 1.3M context: https://github.com/Entrpi/glm-5.3-flash-exl3-2x-spark

Qwen3.8-Flash-Next

Base model: Qwen/Qwen3.8-Flash-Next
For two Sparks: Qwen/Qwen3.8-Flash-Next-FP8 (~186 GB, official) or RadixArk/Qwen3.8-Flash-Next-NVFP4 (~135 GB, more KV headroom)
FP8 TP2 stack (one .env, compose head/worker): https://github.com/0rand/qwen3.8-flash-next-2x-dgx-sparks
NVFP4 TP2 stack: https://github.com/MiaAI-Lab/Qwen3.8-Flash-Next-Dual-DGX-Sparks
Forum write-up of the FP8 config and the four errors that block it: https://forums.developer.nvidia.com/t/qwen3-8-flash-next-fp8-on-2x-dgx-spark-recipe-benchmarks-and-four-errors-that-stopped-the-engine/382610

Cluster setup itself (do this first)

NVIDIA's blog on multi-node clustering via NVIDIA Sync's cluster assistant, which automates the ConnectX-7 link: https://developer.nvidia.com/blog/run-local-ai-agents-with-faster-models-and-multi-node-clustering-on-nvidia-dgx-spark/
The NemoClaw doc above also walks through the two-node vLLM bring-up end to end.
EOF

    # Current
    local models=(

        "deepseek-ai/DeepSeek-V4-Flash-0731" # nvidia 2-spark recipe uses DeepSeek-V4.1-Flash

        #"zai-org/GLM-5.3-Flash"
        "RedHatAI/GLM-5.3-Flash-NVFP4" # quantized

        #"Qwen/Qwen3.8-Flash-Next" # base
        "Qwen/Qwen3.8-Flash-Next-FP8" # for 2 sparks
    )

    # Archived
    local models_unused=(
        # Gemma 4 variants (Base and Instruct)
        "google/gemma-4-31B-it"
        "google/gemma-4-31B"
        "google/gemma-4-26B-A4B-it"
        "google/gemma-4-26B-A4B"
        "google/gemma-4-12B-it"
        "google/gemma-4-12B"
        # New E4B and E2B variants
        "google/gemma-4-E4B"
        "google/gemma-4-E4B-it"
        "google/gemma-4-E2B"
        "google/gemma-4-E2B-it"
        # Previous generations
        #"google/gemma-3-270m"
        #"google/gemma-2b"

        # Laguna
        "poolside/Laguna-S-2.1"

        "deepseek-ai/DeepSeek-V4.1-Flash"  #	Official release. Native FP8 weights with FP4 routed experts.
        #"sgl-project/DeepSeek-V4-Flash-FP8" #	Repackaged FP8 version optimized for SGLang.
        "Qwen/Qwen3.5-35B-A3B" # Qwen 3.5 35B (Instruct) #	35B total parameters with 3B active during inference.
        "Qwen/Qwen3.5-35B-A3B-Base" # Qwen 3.5 35B (Base)	Pre-trained base weights for fine-tuning.

    )

    echo "🔍 Testing Hugging Face token access..."
    echo "----------------------------------------"

    for model in "${models[@]}"; do
        status=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Authorization: Bearer $HF_TOKEN" \
            "https://huggingface.co/api/models/$model")

        if [ "$status" -eq 200 ]; then
            echo "✅ Access GRANTED: $model"
        elif [ "$status" -eq 401 ]; then
            echo "❌ Access DENIED (Invalid Token): $model"
        elif [ "$status" -eq 403 ]; then
            echo "🔒 Access DENIED (Gated/Must accept terms): $model"
        elif [ "$status" -eq 404 ]; then
            echo "⚠️  Model NOT FOUND (Check typo): $model"
        else
            echo "❌ Access ERROR: $model (HTTP $status)"
        fi
    done
}



test_hf_token
