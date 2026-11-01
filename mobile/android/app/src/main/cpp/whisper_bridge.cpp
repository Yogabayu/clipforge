#include <jni.h>
#include <whisper.h>
#include <algorithm>
#include <atomic>
#include <fstream>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

namespace {
std::atomic<bool> cancelled{false};
std::atomic<int> progress{0};
struct ProgressWindow { int before; int weight; };
std::string utf8(JNIEnv *env, jstring value) {
    const char *chars = env->GetStringUTFChars(value, nullptr);
    std::string result(chars);
    env->ReleaseStringUTFChars(value, chars);
    return result;
}
jstring java_string(JNIEnv *env, const std::string &value) {
    auto bytes = env->NewByteArray(static_cast<jsize>(value.size()));
    env->SetByteArrayRegion(bytes, 0, static_cast<jsize>(value.size()), reinterpret_cast<const jbyte *>(value.data()));
    auto klass = env->FindClass("java/lang/String");
    auto constructor = env->GetMethodID(klass, "<init>", "([BLjava/lang/String;)V");
    auto encoding = env->NewStringUTF("UTF-8");
    auto result = static_cast<jstring>(env->NewObject(klass, constructor, bytes, encoding));
    env->DeleteLocalRef(bytes); env->DeleteLocalRef(encoding); env->DeleteLocalRef(klass);
    return result;
}
void fail(JNIEnv *env, const char *message) {
    env->ThrowNew(env->FindClass("java/lang/IllegalStateException"), message);
}
}

extern "C" JNIEXPORT void JNICALL
Java_id_clipforge_clipforge_1mobile_NativeWhisper_cancel(JNIEnv *, jobject) { cancelled.store(true); }
extern "C" JNIEXPORT jint JNICALL
Java_id_clipforge_clipforge_1mobile_NativeWhisper_progress(JNIEnv *, jobject) { return progress.load(); }

extern "C" JNIEXPORT jobjectArray JNICALL
Java_id_clipforge_clipforge_1mobile_NativeWhisper_transcribe(JNIEnv *env, jobject, jstring model_path, jstring pcm_path, jstring language) {
    try {
        cancelled.store(false); progress.store(0);
        auto model = utf8(env, model_path), audio = utf8(env, pcm_path), lang = utf8(env, language);
        auto config = whisper_context_default_params();
        config.use_gpu = false;
        std::unique_ptr<whisper_context, decltype(&whisper_free)> ctx(
            whisper_init_from_file_with_params(model.c_str(), config), whisper_free);
        if (!ctx) { fail(env, "Model Whisper gagal dimuat."); return nullptr; }
        std::ifstream file(audio, std::ios::binary | std::ios::ate);
        if (!file) { fail(env, "Audio PCM tidak tersedia."); return nullptr; }
        const auto size = static_cast<int64_t>(file.tellg());
        if (size <= 0 || size % sizeof(float) != 0) { fail(env, "Audio PCM tidak valid."); return nullptr; }
        file.seekg(0);
        // Bound audio memory independently of video length: 60 s / 3.84 MB per chunk.
        constexpr int chunk_samples = WHISPER_SAMPLE_RATE * 60;
        std::vector<float> samples(chunk_samples);
        std::vector<std::string> lines;
        int64_t processed = 0;
        while (processed < size && !cancelled.load()) {
            file.read(reinterpret_cast<char *>(samples.data()), chunk_samples * sizeof(float));
            const auto count = file.gcount() / sizeof(float);
            if (count == 0) break;
            ProgressWindow window{static_cast<int>(processed * 100 / size), static_cast<int>(count * sizeof(float) * 100 / size)};
            auto params = whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH);
            params.beam_search.beam_size = 5;
            params.temperature = 0.0f;
            params.n_threads = 4; params.language = lang.c_str();
            params.translate = false; params.no_context = true;
            params.print_realtime = false; params.print_progress = false;
            params.print_timestamps = false; params.print_special = false;
            params.suppress_nst = true;
            params.abort_callback = [](void *) { return cancelled.load(); };
            params.encoder_begin_callback = [](whisper_context *, whisper_state *, void *) { return !cancelled.load(); };
            params.progress_callback_user_data = &window;
            params.progress_callback = [](whisper_context *, whisper_state *, int percent, void *data) {
                const auto *w = static_cast<ProgressWindow *>(data);
                progress.store(w->before + w->weight * percent / 100);
            };
            const int result = whisper_full(ctx.get(), params, samples.data(), static_cast<int>(count));
            if (cancelled.load()) break;
            if (result != 0) { fail(env, "Transkripsi native gagal."); return nullptr; }
            const int64_t offset_ms = processed / sizeof(float) * 1000 / WHISPER_SAMPLE_RATE;
            for (int i = 0; i < whisper_full_n_segments(ctx.get()); ++i) {
                const auto start = offset_ms + whisper_full_get_segment_t0(ctx.get(), i) * 10;
                const auto end = offset_ms + whisper_full_get_segment_t1(ctx.get(), i) * 10;
                std::ostringstream line;
                line << start << '\t' << end << '\t' << whisper_full_get_segment_text(ctx.get(), i);
                lines.push_back(line.str());
            }
            processed += static_cast<int64_t>(count * sizeof(float));
            progress.store(static_cast<int>(processed * 100 / size));
        }
        if (cancelled.load()) { fail(env, "Transkripsi dibatalkan."); return nullptr; }
        auto result = env->NewObjectArray(static_cast<jsize>(lines.size()), env->FindClass("java/lang/String"), nullptr);
        for (size_t i = 0; i < lines.size(); ++i) {
            auto value = java_string(env, lines[i]);
            env->SetObjectArrayElement(result, static_cast<jsize>(i), value); env->DeleteLocalRef(value);
        }
        return result;
    } catch (const std::exception &error) { fail(env, error.what()); return nullptr; }
}
